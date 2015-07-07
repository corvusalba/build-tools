#lang racket

(require net/url
         net/url-structs
         web-server/servlet
         web-server/servlet-env
         json)

(define telegram/chat_id "-19779793")

(define telegram/token "109788497:AAGmidxOsCdbMpza1H67ywKljRqQQUXGB6w")

(define telegram/base-url
  (~a "https://api.telegram.org/bot" telegram/token))

(define telegram/send-message-url
  (~a telegram/base-url "/sendMessage"))

(define (query->string query)
  (string-join
   (map (lambda (pair) (~a (car pair) "=" (cdr pair))) query)
   "&"))

(define (compose-url base query)
  (string->url (~a base "?" (query->string query))))

(define (telegram/send-message text)
  (let ((uri (compose-url telegram/send-message-url
                          (list (cons "chat_id" telegram/chat_id)
                                (cons "text" text)))))
    (close-input-port (get-pure-port uri))))

(define (get-author data)
  (~a (hash-ref data 'name)))

(define (get-repo data)
  (~a (hash-ref data 'full_name) " (" (hash-ref data 'url) ")"))

(define (get-commit data)
  (~a "➕ "(hash-ref data 'message) " (" (get-author (hash-ref data 'author)) ") " (hash-ref data 'url)))

(define (create-push-notification data)
  `(,(~a "📥 " (get-author (hash-ref data 'pusher)) " pushed to " (get-repo (hash-ref data 'repository)) ":")
    ,@(map get-commit (hash-ref data 'commits))
    ,(~a "🔎 Diff: " (hash-ref data 'compare))))

(define (github-hook req)
  (let ((body (bytes->jsexpr (request-post-data/raw req))))
    (telegram/send-message (string-join (create-push-notification body) "\n"))
    (response 200 #"OK" (current-seconds) #f empty void)))

(serve/servlet github-hook
               #:port 8080
               #:servlet-path "/github"
               #:listen-ip #f
               #:command-line? #t)
