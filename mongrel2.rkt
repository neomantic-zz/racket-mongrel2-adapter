(module mongrel2 racket/base
 
  (require ffi/unsafe)
  (require (prefix-in zmq: (planet jaymccarthy/zeromq:2:1/zmq)))

  (provide start-handler)

  (struct handler-connection
          (response-uuid
           request-uuid
           incoming-socket
           outgoing-socket))

  (define (start-handler response-uuid response-endpoint request-uuid request-endpoint)
    (let ([connection (connect-handler response-uuid response-endpoint request-uuid request-endpoint)])
      (mainloop connection)))

  (define (mainloop handler-connection)
    (let ([request-msg (zmq:socket-recv! (handler-connection-incoming-socket handler-connection))])
      (display "Received Message:")
      (newline)
      (display request-msg))
    (mainloop handler-connection))
  
  ;; returns a handler-connection
   (define (connect-handler response-uuid response-endpoint request-uuid request-endpoint)
    (let* ([context (zmq:context 1)]
           [in (zmq:socket context 'PULL)]
           [out (zmq:socket context 'PUB)])
      (when request-uuid;;this may be optional
        (zmq:set-socket-option! in 'IDENTITY request-uuid))
	  (display "Listening for Mongrel2: ")
      (zmq:socket-connect! in request-endpoint)
      (zmq:set-socket-option! out 'IDENTITY response-uuid)
      (zmq:socket-connect! out response-endpoint)
      (handler-connection response-uuid request-uuid in out)))
)



