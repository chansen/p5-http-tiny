#!perl

use strict;
use warnings;

use File::Basename;
use Test::More 0.88;
use t::Util    qw[tmpfile rewind slurp monkey_patch dir_list parse_case
                  set_socket_source sort_headers $CRLF $LF];
use HTTP::Tiny;
BEGIN { monkey_patch() }

my %response_codes = (
  'index.html'        => '200',
  'chunked.html'      => '200',
  'cb.html'           => '200',
  'missing.html'      => '404',
);

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

  if ( $case->{data_cb} ) {
    $main::data = '';
    $options{data_callback} = eval join "\n", @{$case->{data_cb}};
    die unless ref( $options{data_callback} ) eq 'CODE';
  }

  # setup mocking and test
  my $res_fh = tmpfile($give_res);
  my $req_fh = tmpfile();

  my $http = HTTP::Tiny->new;
  set_socket_source($req_fh, $res_fh);

  (my $url_basename = $url) =~ s{.*/}{}; 

  my @call_args = %options ? ($url, \%options) : ($url);
  my $response  = $http->get(@call_args);

  my $got_req = slurp($req_fh);

  my $label = basename($file);

  is( sort_headers($got_req), sort_headers($expect_req), "$label request" );

  my $rc = $response_codes{$url_basename};
  is( $response->{status}, $rc, "$label response code $rc" )
    or diag $response->{content};

  if ( $rc eq '200' ) {
    ok( $response->{success}, "$label success flag true" );
  }
  else {
    ok( ! $response->{success}, "$label success flag false" );
  }

  if ( $options{data_callback} ) {
    my ($expected) = reverse split "$CRLF", $give_res;
    is ( $main::data, $expected, "$label cb got content" );
    is ( $response->{content}, '', "$label resp content empty" );
  }

}

done_testing;
