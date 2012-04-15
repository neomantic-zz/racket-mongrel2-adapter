# Racket mongrel2 Adapter

A [mongrel2](http://mongrel2.org) adapter written in [Racket Scheme](http://racket-lang.org/).

# Design Goals
This mongrel2 Racket adapter attempts to do one thing, and do one thing well:
facilate communication between mongrel2 and a mongrel2 handler passed as
lambda expression to the adapter.  It does not attempt to craft or manipulate
either the http request/response headers or the http request/response body between
the handler and the adapter.  Processing a http request and creating a valid
http response is delegated to and the sole responsibility a mongrel2 handler.

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

# Example
An example is supplied in the example directory.  It simply setups
a mongrel2 handler and receives the headers and body, and sends a valid http byte string.

# Handler Requirements
A Racket mongrel2 handler MUST do the following per the API:
* Accept 1 parameters - a bytestring containing either the JSON representation of the request
  or the tnetstring respresention, depending upon how the mongrel2 server has been setup.
* Return a response as single Racket byte-string containing the response headers and the response.
  - For the browser, to correctly process this response, the headers and response in the byte string must be valid

# Source code
The source code is located at http://www.github.com/neomantic/mongrel2-racket-adapter

# Issues and feature requests
Please use the issue tracker supplied by github for this repository.

# License
This source code is licensed under the GPL v3. See the LICENSE document included
with source code for the full terms of use.
