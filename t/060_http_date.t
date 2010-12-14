#!perl

use strict;
use warnings;

use Test::More tests => 1;
use HTTP::Tiny;

# Conversion taken from HTTP::Date
my @DoW = qw(Sun Mon Tue Wed Thu Fri Sat);
my @MoY = qw(Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec);
my %MoY;
@MoY{@MoY} = (1..12);

my %GMT_ZONE = (GMT => 1, UTC => 1, UT => 1, Z => 1);


sub time2str (;$)
{
    my $time = shift;
    $time = time unless defined $time;
    my ($sec, $min, $hour, $mday, $mon, $year, $wday) = gmtime($time);
    sprintf("%s, %02d %s %04d %02d:%02d:%02d GMT",
	    $DoW[$wday],
	    $mday, $MoY[$mon], $year+1900,
	    $hour, $min, $sec);
}

my $now = time;

is(HTTP::Tiny->_http_date($now), time2str($now), "Convert time to HTTP date");


