#!perl

use strict;
use warnings;

use Test::More 0.96;
use IO::Socket::INET;
BEGIN {
    eval { require IO::Socket::SSL; IO::Socket::SSL->VERSION(1.56); 1 };
    plan skip_all => 'IO::Socket::SSL 1.56 required for SSL tests' if $@;
    # $IO::Socket::SSL::DEBUG = 3;

    eval { require Net::SSLeay; Net::SSLeay->VERSION(1.49); 1};
    plan skip_all => 'Net::SSLeay 1.49 required for SSL tests' if $@;

    eval { require Mozilla::CA; 1 };
    plan skip_all => 'Mozilla::CA required for SSL tests' if $@;
}
use HTTP::Tiny;

plan skip_all => 'Only run for $ENV{AUTOMATED_TESTING}'
  unless $ENV{AUTOMATED_TESTING};

use IPC::Cmd qw/can_run/;

if ( can_run('openssl') ) {
  diag "\nNote: running test with ", qx/openssl version/;
}

my $data = {
    'https://www.google.ca/' => {
        host => 'www.google.ca',
        pass => { SSL_verifycn_scheme => 'http', SSL_verifycn_name => 'www.google.ca', SSL_verify_mode => 0x01, SSL_ca_file => Mozilla::CA::SSL_ca_file() },
        fail => { SSL_verify_callback => sub { 0 }, SSL_verify_mode => 0x01 },
        default_should_yield => '1',
    },
    'https://twitter.com/' => {
        host => 'twitter.com',
        pass => { SSL_verifycn_scheme => 'http', SSL_verifycn_name => 'twitter.com', SSL_verify_mode => 0x01, SSL_ca_file => Mozilla::CA::SSL_ca_file() },
        fail => { SSL_verify_callback => sub { 0 }, SSL_verify_mode => 0x01 },
        default_should_yield => '1',
    },
    'https://github.com/' => {
        host => 'github.com',
        pass => { SSL_verifycn_scheme => 'http', SSL_verifycn_name => 'github.com', SSL_verify_mode => 0x01, SSL_ca_file => Mozilla::CA::SSL_ca_file() },
        fail => { SSL_verify_callback => sub { 0 }, SSL_verify_mode => 0x01 },
        default_should_yield => '1',
    },
    'https://spinrite.com/' => {
        host => 'spinrite.com',
        pass => { SSL_verifycn_scheme => 'none', SSL_verifycn_name => 'spinrite.com', SSL_verify_mode => 0x00 },
        fail => { SSL_verifycn_scheme => 'http', SSL_verifycn_name => 'spinrite.com', SSL_verify_mode => 0x01, SSL_ca_file => Mozilla::CA::SSL_ca_file() },
        default_should_yield => '',
    }
};
plan tests => scalar keys %$data;


while (my ($url, $data) = each %$data) {
    subtest $url => sub {
        plan 'skip_all' => 'Internet connection timed out'
            unless IO::Socket::INET->new(
                PeerHost  => $data->{host},
                PeerPort  => 443,
                Proto     => 'tcp',
                Timeout   => 10,
        );

        # the default verification
        my $response = HTTP::Tiny->new(verify_ssl => 1)->get($url);
        is $response->{success}, $data->{default_should_yield}, "Request to $url passed/failed using default as expected"
            or do {
                # $response->{content} = substr $response->{content}, 0, 50;
                $response->{content} =~ s{\n.*}{}s;
                diag explain [IO::Socket::SSL::errstr(), $response]
            };

        # force validation to succeed
        my $pass = HTTP::Tiny->new( SSL_options => $data->{pass} )->get($url);
        isnt $pass->{status}, '599', "Request to $url completed (forced pass)"
            or do {
                $pass->{content} =~ s{\n.*}{}s;
                diag explain $pass
            };
        ok $pass->{content}, 'Got some content';

        # force validation to fail
        my $fail = HTTP::Tiny->new( SSL_options => $data->{fail} )->get($url);
        is $fail->{status}, '599', "Request to $url failed (forced fail)"
            or do {
                $fail->{content} =~ s{\n.*}{}s;
                diag explain [IO::Socket::SSL::errstr(), $fail]
            };
        ok $fail->{content}, 'Got some content';
    };
}
