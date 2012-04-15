#lang racket

(require "../mongrel2.rkt")

(require (planet zitterbewegung/uuid-v4:2:0/uuid-v4))

(run-mongrel2-handler
 "tcp://127.0.0.1:9997"
 "tcp://127.0.0.1:9996"
 (string->bytes/utf-8 (symbol->string (make-uuid)))
 (lambda (headers request-body)
   (display headers)
   (display request-body)
   #" HTTP/1.1 200 OK\r\nContent-Type: text/html;charset=utf-8\r\nContent-Length: 5\r\n\r\nHello\n")
 #t)
