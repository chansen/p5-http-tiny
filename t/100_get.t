#!perl

use strict;
use warnings;

use Test::More 0.88;
use t::Util    qw[tmpfile rewind slurp monkey_patch dir_list parse_case
                  set_socket_source sort_headers $CRLF $LF];
use HTTP::Tiny;
BEGIN { monkey_patch() }

for my $file ( dir_list("t/cases", qr/^get/ ) ) {
  my $data = do { local (@ARGV,$/) = $file; <> };
  my ($params, $expect_req, $give_res) = split /--+\n/, $data;
  # cleanup source data
  my $version = HTTP::Tiny->VERSION || 0;
  $expect_req =~ s{VERSION}{$version};
  s{\n}{$CRLF}g for ($expect_req, $give_res);
  
  # figure out what request to make
  my $case = parse_case($params);
  my $url = $case->{url}->[0];
  my %options;

  my %headers;
  for my $line ( @{ $case->{headers} } ) {
    my ($k,$v) = ($line =~ m{^([^:]+): (.*)$}g);
    $headers{$k} = $v;
  }
  $options{headers} = \%headers if %headers;

  # setup mocking and test
  my $res_fh = tmpfile($give_res);
  my $req_fh = tmpfile();

  my $http = HTTP::Tiny->new;
  set_socket_source($req_fh, $res_fh);

  my @call_args = %options ? ($url, \%options) : ($url);
  my $response  = $http->get(@call_args);

  my $got_req = slurp($req_fh);

  my $label = "get on $url";
  $label .= " (@{[keys %options]})" if %options;
  is( sort_headers($got_req), sort_headers($expect_req), "$label request" );
  is( $response->{status}, '200', "$label response" )
    or diag $response->{content};
}

done_testing;
