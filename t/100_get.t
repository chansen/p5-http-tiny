#!perl

use strict;
use warnings;

use Test::More qw[no_plan];
use t::Util    qw[tmpfile rewind slurp monkey_patch
                  set_socket_source sort_headers $CRLF $LF];
use HTTP::Tiny;
BEGIN { monkey_patch() }

my $data = do { local $/; <DATA> };
my ($expect_req, $give_res) = split /--+\n/, $data;
my $version = HTTP::Tiny->VERSION || 0;
$expect_req =~ s{VERSION}{$version};

s{\n}{$CRLF}g for ($expect_req, $give_res);

my $res_fh = tmpfile($give_res);
my $req_fh = tmpfile();

my $http = HTTP::Tiny->new;
set_socket_source($req_fh, $res_fh);

my $response = $http->get("http://example.com/index.html");
my $got_req = slurp($req_fh);

is( sort_headers($got_req), sort_headers($expect_req), "Request is correct" );
is( $response->{status}, '200', "Response status is correct" )
  or diag $response->{content};

__DATA__
GET /index.html HTTP/1.1
Host: example.com
Connection: close
User-Agent: HTTP-Tiny/VERSION

----------
HTTP/1.1 200 OK
Date: Thu, 03 Feb 1994 00:00:00 GMT
Content-Type: text/plain
Content-Length: 42 

abcdefghijklmnopqrstuvwxyz1234567890abcdef
