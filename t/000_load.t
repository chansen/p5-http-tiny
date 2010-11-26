#!perl

use strict;
use warnings;

use Test::More tests => 1;

BEGIN {
    use_ok('HTTP::Tiny');
}

diag("HTTP::Tiny $HTTP::Tiny::VERSION, Perl $], $^X");

