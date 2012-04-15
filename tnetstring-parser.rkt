;;;;;
;; A helper library to assist spliting up a byte string of
;; tnetstrings into individual tnetstring
;;
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









