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
  (~a (hash-ref data 'name) " <" (hash-ref data 'email) ">"))

(define (get-repo data)
  (~a (hash-ref (hash-ref data 'owner) 'name) "/" (hash-ref data 'name)
      " <" (hash-ref data 'url) ">")
  )  

(define (create-push-notification data)
  (list 
   (~a "Commits pushed by " (get-author (hash-ref data 'pusher)) " in " (get-repo (hash-ref data 'repository)) ":")))

(define (hook req)
  (let ((body (bytes->jsexpr (request-post-data/raw req))))
    (sendMessage (car (create-push-notification body)))
    (response 200 #"OK" (current-seconds) #f empty void)))

(serve/servlet hook
               #:port 8080
               #:servlet-path "/webhook")