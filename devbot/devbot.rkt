#lang racket

(define telegram/chat_id "-19779793")

(define telegram/token "109788497:AAGmidxOsCdbMpza1H67ywKljRqQQUXGB6w")

(define telegram/webhook "hooks.corvusalba.ru/telegram")

(require net/url
         net/url-structs
         net/uri-codec
         net/head
         web-server/servlet
         web-server/servlet-env
         json)

;; helpers

(define (query . args)
  args)

(define (key-value key value)
  (cons key value))

(define (format-key-value item)
  (~a (car item) "=" (cdr item)))

(define (query->string query)
  (string-join (map format-key-value query) "&"))

(define (compose-url base query)
  (string->url (~a base "?" (query->string query))))

;; buildbot api client

(define buildbot/base-url "http://buildbot.corvusalba.ru")

(define buildbot/builders-uri
  (~a buildbot/base-url "/json/builders/?as_text=1"))

(define buildbot/login-uri
  (~a buildbot/base-url "/login"))

(define (buildbot/builder-uri builder)
  (~a buildbot/base-url "/builders/" builder "/force"))

(define (buildbot/request-builders)
  (read-json (get-pure-port
           (string->url buildbot/builders-uri))))

(define (buildbot/get-builders)
  (let ((payload (buildbot/request-builders)))
    (sort (map symbol->string (hash-keys payload))
          string<?)))

(define (buildbot/get-force-scheduler builder)
  (let* ((builder-data (hash-ref (buildbot/request-builders) (string->symbol builder)))
         (schedulers (hash-ref builder-data 'schedulers)))
    (first (filter (lambda (scheduler) (regexp-match #rx"force" scheduler)) schedulers))))

(define (buildbot/login login password)
  (car
   (cdr
    (regexp-match #rx"BuildBotSession=(.+); Exp"
                  (purify-port
                   (post-impure-port (string->url buildbot/login-uri)
                                     (string->bytes/utf-8 (query->string (query (key-value "username" login)
                                                                                (key-value "passwd" password))))
                                     (list "Content-Type: application/x-www-form-urlencoded")))))))

(define (buildbot/start-build builder authtoken)
  (close-input-port
   (post-pure-port (string->url (buildbot/builder-uri builder))
                   (string->bytes/utf-8
                    (query->string
                     (query (key-value "reason" "forced from telegram")
                            (key-value "forcescheduler" (buildbot/get-force-scheduler builder)))))
                   (list "Content-Type: application/x-www-form-urlencoded"
                         (~a "Cookie: BuildBotSession=" authtoken)))))
  
(define (buildbot/select-builder-keyboard)
  (let ((builders (buildbot/get-builders)))
    (jsexpr->string (hash
                     'keyboard (map (lambda (b) (list b)) builders)
                     'selective #t
                     'resize_keyboard #t
                     'one_time_keyboard #t))))

;; telegram api client

(define telegram/base-url
  (~a "https://api.telegram.org/bot" telegram/token))

(define telegram/send-message-url
  (~a telegram/base-url "/sendMessage"))

(define telegram/set-webhook-url
  (~a telegram/base-url "/setWebhook"))

(define (telegram/set-webhook url)
  (let ((uri (compose-url telegram/set-webhook-url
                          (query (key-value "url" url)))))
    (close-input-port (get-pure-port uri))))

(define (telegram/send-message text)
  (let ((uri (compose-url telegram/send-message-url
                          (query (key-value "chat_id" telegram/chat_id)
                                 (key-value "text" text)
                                 (key-value "disable_web_page_preview" #t)))))
    (close-input-port (get-pure-port uri))))

(define (telegram/send-select-builder-keyboard message-id)
  (let* ((markup (buildbot/select-builder-keyboard))
         (uri (compose-url telegram/send-message-url
                           (query (key-value "chat_id" telegram/chat_id)
                                  (key-value "reply_to_message_id" message-id)
                                  (key-value "text" "Select builder:")
                                  (key-value "reply_markup" (uri-encode markup))))))
    (close-input-port (get-pure-port uri))))

(define (telegram/handle message)
  (if (hash-has-key? message 'text)
      (let ((text (hash-ref message 'text))
            (message-id (hash-ref message 'message_id)))
        (cond
          [(regexp-match #rx"пони" text)
           (telegram/send-message "Дружба - это чудо!")]
          [(regexp-match #rx"/build" text)
           (telegram/send-select-builder-keyboard message-id)]))
      #f))

;; github payload parsing

(define (github/repository data)
  (~a (hash-ref data 'full_name) " (" (hash-ref data 'url) ")"))

(define (github/commit data)
  (let ((message (hash-ref data 'message))
        (author (hash-ref (hash-ref data 'author) 'name))
        (url (hash-ref data 'url)))
  (~a "➕ " message " (" author ") " url)))

(define (github/notification data)
  (let ((commits (hash-ref data 'commits))
        (pusher (hash-ref (hash-ref data 'pusher) 'name))
        (repository (hash-ref data 'repository))
        (compare-url (hash-ref data 'compare)))
    `(,(~a "📥 " pusher " pushed to " (github/repository repository) ":")
      ,@(map github/commit commits)
      ,(~a "🔎 diff: " compare-url)))) 

;; buildbot notifications

(define (buildbot/notification event)
  (let ((message (jsexpr->string (hash-ref event 'payload))))
    (telegram/send-message message)))

(define (buildbot/process-payload payload)
  (let ((events (hash-ref
                (string->jsexpr
                 (~a "{\"packets\":" (substring payload 8) "}"))
                'packets)))
    (for-each buildbot/notification events)))

;; hooks

(define (github-hook request)
  (let ((payload (bytes->jsexpr (request-post-data/raw request))))
    (telegram/send-message
     (string-join (github/notification payload) "\n"))
    (response 200 #"OK" (current-seconds) #f empty void)))

(define (builds-hook request)
  (let ((payload (bytes->string/utf-8 (request-post-data/raw request))))
    (build-bot/process-payload payload)
  (response 200 #"OK" (current-seconds) #f empty void)))

(define (telegram-hook request)
  (let ((payload (bytes->jsexpr (request-post-data/raw request)))) 
    (telegram/handle (hash-ref payload 'message))
    (response 200 #"OK" (current-seconds) #f empty void)))

;; endpoint configuration

(define-values (hook-dispatch hook-url)
  (dispatch-rules
   [("github") #:method "post" github-hook]
   [("telegram") #:method "post" telegram-hook]
   [("builds") #:method "post" builds-hook]))

(telegram/set-webhook telegram/webhook)
(telegram/send-message "Всем пони!")

(serve/servlet hook-dispatch
               #:port 8080 
               #:servlet-path ""
               #:servlet-regexp #rx""
               #:listen-ip #f
               #:command-line? #t)
