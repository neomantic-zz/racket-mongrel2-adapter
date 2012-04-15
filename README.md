# Racket mongrel2 Adapter

A [mongrel2](http://mongrel2.org) adapter written in [Racket Scheme](http://racket-lang.org/).

# Design Goals
This mongrel2 Racket adapter attempts to do one thing, and do one thing well:
facilate communication between mongrel2 and a mongrel2 handler passed as
lambda expression to the adapter.  It does not attempt to craft or manipulate
either the http request/response headers or the http request/response body between
the handler and the adapter.  Processing a http request and creating a valid
http response is delegated to and the sole responsibility of the handler.

# Implementation Design
Compared to other examples of the mongrel2 adapter, this implementation appears
verbose.  It could have been written with one procedure in about 50 lines of
code using a simple named-let loop(and indeed, a commit exists in the source code repository
that shows this implementation).  However, for the sake of clarity, maintainablity, and
testing, the current implementation was designed to make the process of connecting
to and handling mongrel2 requests and responses more explicit.

# Dependencies
* 0mq library
* (require (planet jaymccarthy/zeromq:2:1/zmq)))
* (require (planet gerard/tnetstrings:1:0)))

# Limitations
At present, the adapter internally only handles incoming and outgoing
requests to mongrel2 using the tagged netstring protocol. It does not
handle the original and default mongrel2 JSON protocol.  As a consequence,
mongrel2 handlers settings must specify 'tnetstring' as its protocol.

Here is a example of a handler setting up a mongrel2 conf file:

`
racket_handler = Handler(send_spec='tcp://127.0.0.1:9997',
 	                 send_ident='5f84aea8-8291-11e1-a0a7-00261824db2f',
               		 recv_spec='tcp://127.0.0.1:9996',
			 recv_ident=''
			 protocol='tnetstring')
`

JSON support may be added in the future. tnetstring support is currently supported
because expanding tnetstrings into Racket datatypes is much simpler, less error prone,
and much faster than using JSON.

# Example
An example is supplied in the example directory.  It simply setups
a mongrel2 handler and receives the headers and body, and sends a valid http byte string.

# Handler Requirements
A Racket mongrel2 handler MUST do the following per the API:
* Accept 2 parameters.  
  - The first - a Racket list datatype of headers. 
  - The second - a string containing the body of the request if it is present
* Return a response as single Racket byte-string containing the response headers and the response.
  - For the browser, to correctly process this response, the headers and response in the byte string must be valid

# Source code
The source code is located at http://www.github.com/neomantic/mongrel2-racket-adapter

# Issues and feature requests
Please use the issue tracker supplied by github for this repository.

# License
This source code is licensed under the GPL v3. See the LICENSE document included
with source code for the full terms of use.
