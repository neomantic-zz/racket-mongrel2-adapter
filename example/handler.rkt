#lang racket

(require "../mongrel2.rkt")

(require (planet zitterbewegung/uuid-v4:2:0/uuid-v4))
(require (prefix-in tnstr: (planet gerard/tnetstrings:1:0)))

(run-mongrel2-handler
 #:recv-spec "tcp://127.0.0.1:9997"
 #:send-spec "tcp://127.0.0.1:9996"
 #:send-uuid (symbol->string (make-uuid))
 #:handler (lambda (mongrel2-msg)
             (bytes-append
              (mongrel2-msg-sender-uuid mongrel2-msg)
              #" "
              (tnstr:value->bytes/tnetstring (mongrel2-msg-source-id mongrel2-msg))
              #" HTTP/1.1 200 OK\r\nContent-Type: text/html;charset=utf-8\r\nContent-Length: 5\r\n\r\nHello\n"))
 #:verbose #t)
