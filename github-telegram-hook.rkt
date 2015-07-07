#lang racket

(define telegram/chat_id "-19779793")

(define telegram/token "109788497:AAGmidxOsCdbMpza1H67ywKljRqQQUXGB6w")

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

(define (telegram/send-message text)
  (let ((uri (compose-url telegram/send-message-url
                          (query (key-value "chat_id" telegram/chat_id)
                                 (key-value "text" text)))))
    (close-input-port (get-pure-port uri))))

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

;; web api

(define (github-hook request)
  (let ((payload (bytes->jsexpr (request-post-data/raw request))))
    (telegram/send-message
     (string-join (github/notification payload) "\n"))
    (response 200 #"OK" (current-seconds) #f empty void)))

(serve/servlet github-hook
               #:port 8080
               #:servlet-path "/github"
               #:listen-ip #f
               #:command-line? #t)
