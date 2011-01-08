#!perl

use strict;
use warnings;

use IO::Socket::INET;
use Test::More 0.88;
use HTTP::Tiny;

my $test_host = "google.com";
my $test_url  = "http://www.google.com/";
my $test_re   = qr/google/;

plan 'skip_all' => "Only run for \$ENV{AUTOMATED_TESTING}"
  unless $ENV{AUTOMATED_TESTING};

plan 'skip_all' => "Internet connection timed out"
  unless IO::Socket::INET->new(
    PeerHost  => $test_host,
    PeerPort  => 80,
    Proto     => 'tcp',
    Timeout   => 10,
  );

my $response = HTTP::Tiny->new->get($test_url);

ok( $response->{success}, "Successful request to $test_url" );
like( $response->{content}, $test_re, "Saw expected content" )
  or dump_headers($response->{headers});

sub dump_headers {
  my $hash = shift;
  for my $k ( sort keys %$hash ) {
    print "# $k\: $hash->{$k}\n";
  }
}

done_testing;
