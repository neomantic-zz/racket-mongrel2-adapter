(module mongrel2 racket/base
 
  (require ffi/unsafe)
  (require racket/port)
  (require (prefix-in zmq: (planet jaymccarthy/zeromq:2:1/zmq)))
  (require (prefix-in tnstr: (planet gerard/tnetstrings:1:0)))
  (require (prefix-in tnparser: "tnetstring-parser.rkt"))

  (provide run-mongrel2-handler)

  (define (run-mongrel2-handler request-endpoint response-endpoint response-uuid handler [verbose #f] [request-uuid #""])
    (call-with-mongrel2-sockets request-endpoint
                                response-endpoint
                                response-uuid
                                request-uuid
                                (lambda (request-socket response-socket)
                                  (mongrel2-automata
                                   request-socket
                                   response-socket
                                   handler
                                   verbose))))

  (define (call-with-zmq-context proc [number-of-threads 1])
    (proc (zmq:context number-of-threads)))
  
  (define (call-with-mongrel2-sockets request-endpoint response-endpoint response-uuid request-uuid proc) 
    (call-with-zmq-context (lambda (context)
                             (call-with-values
                                 (lambda ()
                                   (values
                                    (mongrel2-zmq-socket-connect! context 'PULL request-endpoint request-uuid)
                                    (mongrel2-zmq-socket-connect! context 'PUB response-endpoint response-uuid)))
                               proc))))
  
  (define (mongrel2-automata request-socket response-socket handler verbose)
    (let ([print-state (log-state v)])
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

  (define (mongrel2-zmq-socket-connect! context type endpoint uuid)
    (let ([socket (zmq:socket context type)]
          [uuid-is-empty (eqv? (bytes-length uuid) 0)])
      (zmq:socket-connect! socket endpoint)
      (cond
       [(and (eqv? type 'PUB) uuid-is-empty)
        (error 'mongrel2 "A response uuid is required")]
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
       (let* ([headers-list (read-mongrel2-header-msg port)]
	      [headers (read-http-headers port)]
	      [request-body (read-http-body port)]
	      [response-list (handler headers request-body)])
	 (zmq:socket-send! socket (make-mongrel2-msg headers-list response-list))))))

  (define (make-mongrel2-msg mongrel2-header-list response)
    (bytes-append
     (car mongrel2-header-list)
     #" "
     (tnstr:value->bytes/tnetstring (car (cdr mongrel2-header-list)))
     response))
  
  (define (parse-mongrel2-msg-part port)
    (let loop ([msg-fragment #""])
      (let ([peek (peek-bytes 1 0 port)])
        (if (eof-object? peek)
            (error 'read-mongrel2-msg "aborting: hit eof")
            (if (equal? peek #" ")
                (begin
                  (read-bytes 1 port);;increment past the next space
                  msg-fragment)
                (loop (bytes-append msg-fragment (read-bytes 1 port))))))))
  
  (define (read-mongrel2-header-msg port)
    (let* ([mongrel2-uuid-bytes (parse-mongrel2-msg-part port)]
           [source-id-bytes (parse-mongrel2-msg-part port)]
           [request-path-bytes (parse-mongrel2-msg-part port)])
      (cond
       [(not (> (bytes-length mongrel2-uuid-bytes) 0)) (error 'read-mongrel2-request "missing mongrel2 server uuid")]
       [(not (> (bytes-length source-id-bytes) 0)) (error 'read-mongrel2-request "missing source id")]
       [(not (> (bytes-length request-path-bytes) 0)) (error 'read-mongrel2-request "missing path")]
       (else
        (list mongrel2-uuid-bytes
              source-id-bytes
              request-path-bytes)))))

  (define (read-http-headers port)
    (tnstr:value->bytes/tnetstring (tnparser:read-tnetstring-bytes port)))
  
  (define (read-http-body port)
    (tnstr:value->bytes/tnetstring (tnparser:read-tnetstring-bytes port)))
  )
