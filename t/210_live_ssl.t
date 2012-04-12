#!perl

use strict;
use warnings;

use Test::More 0.88;
use IO::Socket::INET;
BEGIN {
    eval 'use IO::Socket::SSL; 1';
    plan skip_all => "IO::Socket::SSL required for SSL tests" if $@;
    # $IO::Socket::SSL::DEBUG = 3;
}
use HTTP::Tiny;

plan skip_all => "Only run for \$ENV{AUTOMATED_TESTING}"
  unless $ENV{AUTOMATED_TESTING};

my $data = {
    'https://www.google.ca/' => {
        host => 'www.google.ca',
        pass => { SSL_verifycn_scheme => 'http' },
        fail => { SSL_verify_callback => sub { 0 }, SSL_verify_mode => 0x01 },
        default_should_yield => '1',
    },
    'https://twitter.com/' => {
        host => 'twitter.com',
        pass => { SSL_verifycn_scheme => 'http' },
        fail => { SSL_verify_callback => sub { 0 }, SSL_verify_mode => 0x01 },
        default_should_yield => '1',
    },
    'https://github.com/' => {
        host => 'github.com',
        pass => { SSL_verifycn_scheme => 'http' },
        fail => { SSL_verify_callback => sub { 0 }, SSL_verify_mode => 0x01 },
        default_should_yield => '1',
    },
    # 'https://spinrite.com/' => {
        # host => 'spinrite.com',
        # pass => { SSL_verifycn_scheme => 'none' },
        # fail => { SSL_verifycn_scheme => 'http' }, # why/how does this pass?
        # default_should_yield => '',
    # }
};
plan tests => scalar keys %$data;


while (my ($url, $data) = each %$data) {
    subtest $url => sub {
        plan 'skip_all' => "Internet connection timed out"
            unless IO::Socket::INET->new(
                PeerHost  => $data->{host},
                PeerPort  => 443,
                Proto     => 'tcp',
                Timeout   => 10,
        );

        # the default verification
        my $response = HTTP::Tiny->new->get($url);
        is $response->{success}, $data->{default_should_yield}, "Request to $url passed/failed using default as expected"
            or do { delete $response->{content}; diag explain [IO::Socket::SSL::errstr(), $response] };

        # force validation to succeed
        my $pass = HTTP::Tiny->new( SSL_opts => $data->{pass} )->get($url);
        isnt $pass->{status}, '599', "Request to $url completed (forced pass)"
            or do { delete $pass->{content}; diag explain $pass };
        ok $pass->{content}, 'Got some content';

        # force validation to fail
        my $fail = HTTP::Tiny->new( SSL_opts => $data->{fail} )->get($url);
        is $fail->{status}, '599', "Request to $url failed (forced fail)"
            or do { delete $fail->{content}; diag explain [IO::Socket::SSL::errstr(), $fail] };
        ok $fail->{content}, 'Got some content';
    };
}
