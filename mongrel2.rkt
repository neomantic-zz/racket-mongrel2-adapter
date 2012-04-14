(module mongrel2 racket/base
 
  (require ffi/unsafe)
  (require racket/port)
  (require (prefix-in zmq: (planet jaymccarthy/zeromq:2:1/zmq)))
  (require (prefix-in tnstr: (planet gerard/tnetstrings:1:0)))

  (provide mongrel2-automata)
  (provide parse-mongrel2-msg-part)
  (provide read-mongrel2-header-msg)

  (define (mongrel2-automata request-endpoint response-endpoint response-uuid [request-uuid #""])
    (let* ([context (zmq:context 1)]
           [request-socket (mongler2-zmq-socket-connect! context 'PULL request-endpoint request-uuid)]
           [response-socket (mongler2-zmq-socket-connect! context 'PUB response-endpoint response-uuid)])
      (letrec ([listening (lambda (listen)
                            (display "Listening\n")
                            (let listener ([listening listen])
                              (if (eqv? listening #f)
                                  (stop)
                                  (listener (received)))))]
               [received (lambda ()
                           (let ([request-msg-bytes (zmq:socket-recv! request-socket)])
                             (display "Recieved message\n")
                             (respond request-msg-bytes)
                             #t))] ;;if kill, kill, else respod
               [respond (lambda (request-msg-bytes)
                          (let ([response #"blah"])
                            (display "Sending message\n")
                            (send-response response-socket request-msg-bytes)
                            (sent #t)))]
               [sent (lambda (responded)
                       (display "Message Sent ")
                       (if (eqv? responded #t)
                           (display "Successfully\n")
                           (display "Failed\n")))]
               [stop (lambda ()
                       (display "Stopping\n")
                       (zmq:socket-close! request-socket)
                       (zmq:socket-close! response-socket)
                       (stopped))]
               [stopped (lambda ()
                          (display "Mongrel has stopped"))])
        (listening #t))))

  (define (mongler2-zmq-socket-connect! context type endpoint uuid)
    (let ([socket (zmq:socket context type)]
          [uuid-is-empty (eqv? (bytes-length uuid) 0)])
      (zmq:socket-connect! socket endpoint)
      (cond
       [(and (eqv? type 'PUB) uuid-is-empty)
        (error 'mongrel2 "A response uuid is require")]
       [(eq? uuid-is-empty #f)
        (zmq:set-socket-option! socket 'IDENTITY uuid)])
      socket))

  
  ;;TODO Handle kill message
  ;;Not doing anything with the body
  ;;Not doing anything with the header
  
  (define (send-response socket request-msg-bytes)
    (let ([mongrel2-header-list (read-mongrel2-header-msg
                                 (open-input-bytes request-msg-bytes))])
      (zmq:socket-send! socket (make-mongrel2-msg mongrel2-header-list))))

  (define (make-mongrel2-msg mongrel2-header-list)
    (bytes-append
     (car mongrel2-header-list)
     #" "
     (tnstr:value->bytes/tnetstring (car (cdr mongrel2-header-list)))
     #" HTTP/1.1 200 OK\r\nContent-Type: text/html;charset=utf-8\r\nContent-Length: 5\r\n\r\nHello\n"))

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
              (bytes->string/utf-8 request-path-bytes))))))

)

   
  



