#lang racket

(require "../mongrel2.rkt")

(require (planet zitterbewegung/uuid-v4:2:0/uuid-v4))

(mongrel2-automata
 "tcp://127.0.0.1:9997"
 "tcp://127.0.0.1:9996"
 (string->bytes/utf-8 (symbol->string (make-uuid))))
