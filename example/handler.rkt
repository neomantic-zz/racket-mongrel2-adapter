#lang racket

(require racket/date)
(require "../mongrel2-adapter.rkt")

(require (planet zitterbewegung/uuid-v4:2:0/uuid-v4))

(run-mongrel2-handler
 #:recv-spec "tcp://127.0.0.1:9997"
 #:send-spec "tcp://127.0.0.1:9996"
 #:send-uuid (symbol->string (make-uuid))
 #:handler (lambda (mongrel2-request)
             (let ([date-string (date->string (current-date) #t)])
               (mongrel2-response
                (mongrel2-request-sender-uuid mongrel2-request)
                (list (mongrel2-request-source-id mongrel2-request))
                (string-append
                 "HTTP/1.1 200 OK\r\nContent-Type: text/html;charset=utf-8\r\n"
                 "Content-Length: " (number->string (string-length date-string)) "\r\n\r\n"
                 date-string "\n"))))
 #:verbose #t)
