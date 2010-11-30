#!perl

use strict;
use warnings;

use Test::More tests => 1;
use HTTP::Tiny;

my @accessors = qw(agent default_headers max_redirect max_size proxy timeout);
my @methods   = qw(new get);

can_ok('HTTP::Tiny', @methods, @accessors);

