#lang racket

(define telegram/chat_id "-19779793")

(define telegram/token "109788497:AAGmidxOsCdbMpza1H67ywKljRqQQUXGB6w")

(define telegram/webhook "hooks.corvusalba.ru/telegram")

(require net/url
         net/url-structs
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
                                 (key-value "text" text)))))
    (close-input-port (get-pure-port uri))))

(define (telegram/handle message)
  (if (hash-has-key? message 'text)
      (let ((text (hash-ref message 'text)))
        (if (regexp-match #rx"пони" text)
            (telegram/send-message "Дружба - это чудо!")
            #f))
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

;; hooks

(define (github-hook request)
  (let ((payload (bytes->jsexpr (request-post-data/raw request))))
    (telegram/send-message
     (string-join (github/notification payload) "\n"))
    (response 200 #"OK" (current-seconds) #f empty void)))

(define (builds-hook request)
  (let ((payload (bytes->string/utf-8 (request-post-data/raw request))))
    (telegram/send-message payload)
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

(define (start request)
  (displayln request)
  (hook-dispatch request))

(telegram/set-webhook telegram/webhook)
(telegram/send-message "Всем пони!")

(serve/servlet hook-dispatch
               #:port 8080 
               #:servlet-path ""
               #:servlet-regexp #rx""
               #:listen-ip #f
               #:command-line? #t)
