#!/usr/bin/perl

use strict;
use warnings;

use HTTP::Tiny;

my $url = shift(@ARGV) || 'http://example.com';

my ($status_code, $reason_phrase, $headers, $content) =
  HTTP::Tiny->new->get($url);

print "$status_code $reason_phrase\n";

while (my ($k, $v) = each %$headers) {
    for (ref $v eq 'ARRAY' ? @$v : $v) {
        print "$k: $_\n";
    }
}

print $content if defined $content;

