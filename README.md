# Racket mongrel2 Adapter

A [mongrel2](http://mongrel2.org) adapter written in [Racket Scheme](http://racket-lang.org/).

## Design Goals
This mongrel2 Racket adapter facilates the communication between a mongrel2 webserver
and a mongrel2 handler which follows an API describe below. It does not attempt to craft or
manipulate either the http request/response headers or the http request/response body between
the handler and the adapter.  Processing a http request and creating a valid
http response is delegated to and the sole responsibility the handler.

## Dependencies
* mongrel2 (tested using mongrel2 1.7.5)
* the [0mq library](http://www.zeromq.org)
* (require (planet jaymccarthy/zeromq:2:1/zmq)))
* (require (planet gerard/tnetstrings:1:0)))

## Example
An example is supplied in the example directory.  It simply shows a primitive mongrel2 handler
following the API requirements below.

## Handler Requirements
A Racket mongrel2 handler must meet 3 API requirements.
  1. It must be a lambda expression / procedure
  2. The lambda expression must accept one paramater - a mongrel2-request struct
  3. It must return a mongrel2-response struct that contains...
     - the server-uuid (available in the mongrel2-request struct)
     - a source id (also available in mongrel2-request struct) contained in a list
     - an an option string body

## Source code
The source code is located at http://github.com/neomantic/racket-mongrel2-adapter

## Release status
As of commit 8cafec8c, this is a beta release. Code reviews and comments are greatly appreciated,
and would bring this release out of beta.  Between beta and a full release, the API will 
most likely change and be polished. Additionally, unit-tests and more documentation will be added.

## Issues and feature requests
Please use the issue tracker supplied by github for this repository.

## License
This source code is licensed under the GPL v3. See the LICENSE document included
with source code for the full terms of use.
