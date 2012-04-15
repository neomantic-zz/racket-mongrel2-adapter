;;;;;
;; A Mongrel2 Adapter written in Racket Scheme
;; Copyright (C) 2012 Chad Albers <calbers@neomantic.com>
;;
;; This program is free software: you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.
;;
;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.
;;
;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <http://www.gnu.org/licenses/>.
;;;;;

;;;;;
;; Below is an example of how to use this library, if 
;; this handler is in the same directory as the mongrel2.rkt
;; source code.  Currently, the mongrel2 handler must be setup
;; to deliver messages using the tnetstring protocol
;;
;; #lang racket
;; (require "mongrel2.rkt")
;; (require (planet zitterbewegung/uuid-v4:2:0/uuid-v4))
;; (run-mongrel2-handler
;;  #:recv-spec "tcp://127.0.0.1:9997"
;;  #:send-spec "tcp://127.0.0.1:9996"
;;  #:send-uuid (symbol->string (make-uuid))
;;  #:handler (lambda (headers request-body)
;;             (display headers)
;;             (display request-body)
;;             #" HTTP/1.1 200 OK\r\nContent-Type: text/html;charset=utf-8\r\nContent-Length: 5\r\n\r\nHello\n")
;;  #:verbose #t)
;;
;;;;;

(module mongrel2 racket/base
 
  (require ffi/unsafe)
  (require racket/port)
  (require (prefix-in zmq: (planet jaymccarthy/zeromq:2:1/zmq)))
  (require (prefix-in tnstr: (planet gerard/tnetstrings:1:0)))
  (require (prefix-in tnparser: "tnetstring-parser.rkt"))

  (provide run-mongrel2-handler)

  (define (run-mongrel2-handler #:recv-spec request-endpoint
                                #:send-spec response-endpoint
                                #:send-uuid response-uuid
                                #:handler handler
                                #:verbose [verbose #f]
                                #:recv-uuid [request-uuid #""])
    
    (call-with-m2-sockets request-endpoint
                          response-endpoint
                          (string->bytes/utf-8 response-uuid)
                          (string->bytes/utf-8 request-uuid)
                          (lambda (request-socket response-socket)
                            (m2-automata
                             request-socket
                             response-socket
                             handler
                             verbose))))

  (define (call-with-zmq-context proc [number-of-threads 1])
    (proc (zmq:context number-of-threads)))
  
  (define (call-with-m2-sockets request-endpoint response-endpoint response-uuid request-uuid proc) 
    (call-with-zmq-context (lambda (context)
                             (call-with-values
                                 (lambda ()
                                   (values
                                    (m2-zmq-socket-connect! context 'PULL request-endpoint request-uuid)
                                    (m2-zmq-socket-connect! context 'PUB response-endpoint response-uuid)))
                               proc))))
  
  (define (m2-automata request-socket response-socket handler verbose)
    (let ([print-state (log-state verbose)])
      (letrec ([listening (lambda (listen)
                            (print-state "Listening")
                            (let listener ([listening listen])
                              (if (eqv? listening #f)
                                  (stop)
                                  (listener (received)))))]
               [received (lambda ()
                           (let ([request-msg-bytes (zmq:socket-recv! request-socket)])
                             (print-state "Recieved message")
                             (respond request-msg-bytes)
                             #t))]
               [respond (lambda (request-msg-bytes)
                          (print-state "Sending message")
                          (send-response response-socket request-msg-bytes handler)
                          (sent #t))]
               [sent (lambda (responded)
                       (if (eqv? responded #t)
                           (print-state "Message Sent")
                           (error 'mongrel2 "message failed to be sent")))]
               [stop (lambda ()
                       (print-state "Stopping")
                       (zmq:socket-close! request-socket)
                       (zmq:socket-close! response-socket)
                       (stopped))]
               [stopped (lambda ()
                          (print-state "Mongrel2 Handler has stopped"))])
        (listening #t))))

  (define (m2-zmq-socket-connect! context type endpoint uuid)
    (let ([socket (zmq:socket context type)]
          [uuid-is-empty (eqv? (bytes-length uuid) 0)])
      (zmq:socket-connect! socket endpoint)
      (cond
       [(and (eqv? type 'PUB) uuid-is-empty)
        (error 'm2 "A response uuid is required")]
       [(eq? uuid-is-empty #f)
        (zmq:set-socket-option! socket 'IDENTITY uuid)])
      socket))

  (define (log-state enable)
    (lambda (message)
      (if (eq? enable #t)
          (begin (display message) (newline))
          #f)))
  
  (define (send-response socket request-msg-bytes handler)
    (call-with-input-bytes
     request-msg-bytes
     (lambda (port)
       (let* ([headers-list (read-m2-header-msg port)]
	      [headers (read-http-headers port)]
	      [request-body (read-http-body port)]
	      [response-list (handler headers request-body)])
	 (zmq:socket-send! socket (make-m2-msg headers-list response-list))))))

  (define (make-m2-msg m2-header-list response)
    (bytes-append
     (car m2-header-list)
     #" "
     (tnstr:value->bytes/tnetstring (car (cdr m2-header-list)))
     response))
  
  (define (parse-m2-msg-part port)
    (let loop ([msg-fragment #""])
      (let ([peek (peek-bytes 1 0 port)])
        (if (eof-object? peek)
            (error 'read-mongrel2-msg "aborting: hit eof")
            (if (equal? peek #" ")
                (begin
                  (read-bytes 1 port);;increment past the next space
                  msg-fragment)
                (loop (bytes-append msg-fragment (read-bytes 1 port))))))))

  ;; make sure mongrel2 sent the correct information
  (define (read-m2-header-msg port)
    (let* ([m2-uuid-bytes (parse-m2-msg-part port)]
           [source-id-bytes (parse-m2-msg-part port)]
           [request-path-bytes (parse-m2-msg-part port)])
      (cond
       [(not (> (bytes-length m2-uuid-bytes) 0)) (error 'read-mongrel2-request "missing mongrel2 server uuid")]
       [(not (> (bytes-length source-id-bytes) 0)) (error 'read-mongrel2-request "missing source id")]
       [(not (> (bytes-length request-path-bytes) 0)) (error 'read-mongrel2-request "missing path")]
       (else
        (list m2-uuid-bytes
              source-id-bytes
              request-path-bytes)))))

  (define (read-http-headers port)
    (tnstr:value->bytes/tnetstring (tnparser:read-tnetstring-bytes port)))
  
  (define (read-http-body port)
    (tnstr:value->bytes/tnetstring (tnparser:read-tnetstring-bytes port)))
  )
