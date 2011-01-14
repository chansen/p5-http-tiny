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

ok( $response->{status} ne '599', "Request to $test_url completed" )
  or dump_hash($response);
ok( $response->{content}, "Got content" );

sub dump_hash {
  my $hash = shift;
  $hash->{content} = substr($hash->{content},0,160) . "...";
  require Data::Dumper;
  my $dumped = Data::Dumper::Dumper($hash);
  $dumped =~ s{^}{# };
  print $dumped;
}

done_testing;
