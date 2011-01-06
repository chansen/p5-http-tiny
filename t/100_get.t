#!perl

use strict;
use warnings;

use Test::More 0.88;
use t::Util    qw[tmpfile rewind slurp monkey_patch dir_list
                  set_socket_source sort_headers $CRLF $LF];
use HTTP::Tiny;
BEGIN { monkey_patch() }

for my $case ( dir_list("t/cases", qr/^get/ ) ) {
  my $data = do { local (@ARGV,$/) = $case; <> };
  my ($url, $expect_req, $give_res) = split /--+\n/, $data;
  chomp $url;
  my $version = HTTP::Tiny->VERSION || 0;
  $expect_req =~ s{VERSION}{$version};

  s{\n}{$CRLF}g for ($expect_req, $give_res);

  my $res_fh = tmpfile($give_res);
  my $req_fh = tmpfile();

  my $http = HTTP::Tiny->new;
  set_socket_source($req_fh, $res_fh);

  my $response = $http->get($url);
  my $got_req = slurp($req_fh);

  is( sort_headers($got_req), sort_headers($expect_req), "get('$url') request" );
  is( $response->{status}, '200', "get('$url') response" )
    or diag $response->{content};
}

done_testing;
