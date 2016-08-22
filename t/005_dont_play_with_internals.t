#!perl

use strict;
use warnings;

use Test::More tests => 4;
use HTTP::Tiny;
use Data::Dumper;

my $ua = HTTP::Tiny->new;
$ua->{handle} = undef;

$ua->{handle}->{do}{not}{do}{this} = 42;

# the URL does not matter as the code whould just error out
my $res = $ua->request(GET => "http://localhost");

is( $res->{status},  599,                 "It died with 599" );
is( $res->{reason}, 'Internal Exception', "Successful failure" );
is( $res->{success}, '',                  "No success" );
like( $res->{content}, qr/\QPlaying with the internals of HTTP::Tiny? I've received an unexpected bogus handle:\E/, "You mess with the internals, you die" );
