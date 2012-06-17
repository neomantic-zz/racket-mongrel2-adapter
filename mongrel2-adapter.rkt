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
;; (require "mongrel2-adapter.rkt")
;; (require (planet zitterbewegung/uuid-v4:2:0/uuid-v4))
;;   
;;  (run-mongrel2-handler
;;  #:recv-spec "tcp://127.0.0.1:9997"
;;  #:send-spec "tcp://127.0.0.1:9996"
;;  #:send-uuid (symbol->string (make-uuid))
;;  #:handler (lambda (mongrel2-request)
;;              (mongrel2-response
;;               (mongrel2-request-sender-uuid mongrel2-request)
;;               (list (mongrel2-request-source-id mongrel2-request))
;;               "HTTP/1.1 200 OK\r\nContent-Type: text/html;charset=utf-8\r\nContent-Length: 5\r\n\r\nHello\n"))
;;  #:verbose #t)
;;;;;

(module mongrel2 racket/base
 
  (require ffi/unsafe)
  (require racket/port)
  (require (prefix-in zmq: (planet jaymccarthy/zeromq:2:1/zmq)))

  (provide run-mongrel2-handler
           (struct-out mongrel2-request)
           (struct-out mongrel2-response))

  (struct mongrel2-request
          (sender-uuid
          source-id
          request-path
          http-request))

  (struct mongrel2-response
          (sender-uuid
           source-ids
           response))

  (define (run-mongrel2-handler #:recv-spec request-endpoint
                                #:send-spec response-endpoint
                                #:send-uuid response-uuid
                                #:handler handler
                                #:verbose [verbose #f]
                                #:recv-uuid [request-uuid ""])
    (call-with-zmq-sockets request-endpoint
                           response-endpoint
                           response-uuid
                           request-uuid
                           (λ (request-socket response-socket)
                              (m2-automata
                               request-socket
                               response-socket
                               handler
                               verbose))))
  
  (define (call-with-zmq-sockets request-endpoint response-endpoint response-uuid request-uuid proc)
    (let ([context (zmq:context 1)])
      (call-with-values (λ ()
                           (if (= (string-length response-uuid) 0)
                               (error 'mongrel2-adapter "aborting: Failed to supplied the require mongrel2 response uuid")
                               (let ([make-connect-socket (λ (type endpoint uuid)
                                                             (let ([socket (zmq:socket context type)])
                                                               (zmq:socket-connect! socket endpoint)
                                                               (when (> (string-length uuid) 0)
                                                                 (zmq:set-socket-option! socket 'IDENTITY (string->bytes/latin-1 uuid)))
                                                               socket))])
                                 (values
                                  (make-connect-socket 'PULL request-endpoint request-uuid)
                                  (make-connect-socket 'PUB response-endpoint response-uuid)))))
        proc)))
  
  (define (m2-automata request-socket response-socket handler verbose)
    (let ([print-state (log-state verbose)])
      (letrec ([listening (λ (listen)
                             (print-state "Listening")
                             (let listener ([listening listen])
                               (if (eqv? listening #f)
                                   (stop)
                                   (listener (received)))))]
               [received (λ ()
                            (let ([request-msg-bytes (zmq:socket-recv! request-socket)])
                              (print-state "Recieved message")
                              (respond request-msg-bytes)
                              #t))]
               [respond (λ (request-msg-bytes)
                           (let ([port (open-input-bytes request-msg-bytes)])
                             (zmq:socket-send!
                                 response-socket
                                 (format-mongrel2-response (handler (read-m2-request port))))
                             (close-input-port port))
                           (sent #t))]
               [sent (λ ()
                        (print-state "Message Sent"))]
               [stop (λ ()
                        (print-state "Stopping")
                        (zmq:socket-close! request-socket)
                        (zmq:socket-close! response-socket)
                        (stopped))]
               [stopped (λ ()
                           (print-state "Mongrel2 Handler has stopped"))])
        (listening #t))))

    
  (define (format-mongrel2-response m2-response)
    (when (= (string-length (mongrel2-response-sender-uuid m2-response)) 0)
      (error 'mongrel2-adapter "aborting: response message is missing a server identifier"))
    (when (= (length (mongrel2-response-source-ids m2-response)) 0)
      (error 'mongrel2-adapter "aborting: response message is missing a source id"))
    (bytes-append
     (string->bytes/latin-1 (mongrel2-response-sender-uuid m2-response))
     #" "
     (format-response-source-ids (mongrel2-response-source-ids m2-response))
     #" "
     (string->bytes/utf-8 (mongrel2-response-response m2-response))))

  (define (format-response-source-ids list-of-ids)
    ;; returns a netstring byte string containing a comma delimited list of source ids
    (let ([source-bytes (foldl (λ (source-id results)
                                  (when (not (valid-source-id? source-id))
                                    (error 'mongrel2-adapter "a source id must be an integer between 1 and 128"))
                                  (bytes-append results #", " (string->bytes/latin-1 (number->string source-id))))
                               (string->bytes/latin-1 (number->string (car list-of-ids)))
                               (cdr list-of-ids))]) ;; foldl creates the comma delimited bytstring
      (bytes-append
       (string->bytes/latin-1 (number->string (bytes-length source-bytes)))
       #":"
       source-bytes
       #",")))
  
  (define (valid-source-id? id)
    (cond
     [(not (integer? id)) #f]
     [(not (and (> id 0) (<= id 128))) #f]
     [else #t]))
  
  (define (log-state enable)
    (λ (message)
       (when (eq? enable #t)
         (begin (display message) (newline)))))
  
  (define (parse-m2-request-header port)
    (let loop ([msg-fragment #""])
      (let ([peek (peek-bytes 1 0 port)])
        (if (eof-object? peek)
            (error 'read-mongrel2-msg "aborting: hit eof")
            (if (equal? peek #" ")
                (begin
                  (read-bytes 1 port);;increment past the next space, since we don't need it 
                  msg-fragment)
                (loop (bytes-append msg-fragment (read-bytes 1 port))))))))

  (define (read-m2-request port)
    (let* ([m2-uuid-bytes (parse-m2-request-header port)]
           [source-id-bytes (parse-m2-request-header port)]
           [request-path-bytes (parse-m2-request-header port)])
      ;; make sure mongrel2 sent the correct information
      (cond
       [(not (> (bytes-length m2-uuid-bytes) 0)) (error 'read-mongrel2-request "missing mongrel2 server uuid")]
       [(not (> (bytes-length source-id-bytes) 0)) (error 'read-mongrel2-request "missing source id")]
       [(not (> (bytes-length request-path-bytes) 0)) (error 'read-mongrel2-request "missing path")]
       (else
        (mongrel2-request
         (string->immutable-string (bytes->string/latin-1 m2-uuid-bytes))
         (string->number (bytes->string/latin-1 source-id-bytes))
         request-path-bytes
         (port->bytes port))))))
  )
