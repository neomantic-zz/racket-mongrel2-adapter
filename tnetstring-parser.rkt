(module tnetstring-parser racket/base
  
  (provide read-tnetstring-bytes)
  (provide read-payload-size-bytes)
  (provide read-payload-data-bytes)
  (provide read-payload-type-bytes)
  
  (require racket/port)

  (define (read-payload-size-bytes port)
	(let loop ([numeric-bytes #""])
	  (let ([char (peek-char port)])
		(if (eof-object? char)
			(error 'collect-size-digits "aborting at eof")
			(if (and (char=? #\: char) (not (char-numeric? char)))
                            (begin
                              (display (bytes? numeric-bytes))
                              numeric-bytes)
                            (loop (bytes-append numeric-bytes (read-bytes 1 port))))))))

  (define (read-payload-data-bytes port size)
    (read-bytes size port))

  (define (read-payload-type-bytes port)
    (let ([type-char #\,]
          [legal-types (list #\, #\^ #\! #\} #\] #\~)])
      (cond [(eof-object? type-char)
             (error 'read-tnetstring "aborting at eof")]
            [(not (member type-char legal-types))
             (error 'read-tnetstring "not a legal type")]
            [else (read-bytes 1 port)])))

  ;;this doesn't handle the case where bytes-size is 0
  (define (read-tnetstring-bytes port)
    (let* ([size-bytes (read-payload-size-bytes port)]
           [size-delimiter-bytes (read-bytes 1 port)] ;; this is #":"
           [data-bytes (read-payload-data-bytes port (string->number (bytes->string/utf-8 size-bytes)))]
           [type-bytes (read-payload-type-bytes port)])
      (bytes-append size-bytes size-delimiter-bytes data-bytes type-bytes)))
)









