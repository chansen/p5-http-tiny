#!perl
use strict;
use warnings;

use File::Basename;
use Test::More 0.88;

use HTTP::Tiny;

for my $proxy ([], ["localhost"]){
    local $ENV{no_proxy} = $proxy;
    my $c = HTTP::Tiny->new();
    ok(defined $c->no_proxy);
}

{
    local $ENV{no_proxy} = "localhost,example.com";
    my $c = HTTP::Tiny->new();
    is_deeply($c->no_proxy, ["localhost", "example.com"]);
}

{
    local $ENV{no_proxy} = "localhost,example.com";
    my $c = HTTP::Tiny->new();
    ok($c->_match_no_proxy('localhost'));
    ok($c->_match_no_proxy('example.com'));
    ok(!$c->_match_no_proxy('perl.org'));
}

{
    eval {
        my $c = HTTP::Tiny->new(no_proxy => 'localhost');
    };
    like($@, qr{should be ArrayRef});
}

done_testing();
