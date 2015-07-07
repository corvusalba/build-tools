#lang racket

(require net/url
         net/url-structs
         web-server/servlet
         web-server/servlet-env
         json)

(define (getSendMessageUri text)
    (~a "https://api.telegram.org/bot109788497:AAGmidxOsCdbMpza1H67ywKljRqQQUXGB6w/sendMessage?chat_id=-19779793&text=" text))

(define (sendMessage text)
  (let ((uri (string->url (getSendMessageUri text))))
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

(define (hook req)
  (let ((body (bytes->jsexpr (request-post-data/raw req))))
    (sendMessage (string-join (create-push-notification body) "\n"))
    (response 200 #"OK" (current-seconds) #f empty void)))

(serve/servlet hook
               #:port 8080
               #:servlet-path "/github")
