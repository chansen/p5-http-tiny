#!/usr/bin/perl

use strict;
use warnings;

use HTTP::Tiny;

my $url = shift(@ARGV) || 'http://example.com';

my $response = HTTP::Tiny->new->get($url);

print "$response->{status} $response->{reason}\n";

while (my ($k, $v) = each %{$response->{headers}}) {
    for (ref $v eq 'ARRAY' ? @$v : $v) {
        print "$k: $_\n";
    }
}

print $response->{content} if length $response->{content};

