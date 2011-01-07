#!perl

use strict;
use warnings;

use File::Basename;
use Test::More 0.88;
use t::Util qw[tmpfile rewind slurp monkey_patch dir_list parse_case
  hashify connect_args set_socket_source sort_headers $CRLF $LF];

use HTTP::Tiny;
BEGIN { monkey_patch() }

for my $file ( dir_list("t/cases", qr/^get/ ) ) {
  my $data = do { local (@ARGV,$/) = $file; <> };
  my ($params, $expect_req, $give_res) = split /--+\n/, $data;

  # figure out what request to make
  my $case = parse_case($params);
  my $url = $case->{url}->[0];
  my %options;

  my %headers = hashify( $case->{headers} );
  my %new_args = hashify( $case->{new_args} );

  $options{headers} = \%headers if %headers;

  if ( $case->{data_cb} ) {
    $main::data = '';
    $options{data_callback} = eval join "\n", @{$case->{data_cb}};
    die unless ref( $options{data_callback} ) eq 'CODE';
  }

  # cleanup source data
  my $version = HTTP::Tiny->VERSION || 0;
  my $agent = $new_args{agent} || "HTTP-Tiny/$version";
  $expect_req =~ s{HTTP-Tiny/VERSION}{$agent};
  s{\n}{$CRLF}g for ($expect_req, $give_res);

  # setup mocking and test
  my $res_fh = tmpfile($give_res);
  my $req_fh = tmpfile();

  my $http = HTTP::Tiny->new(%new_args);
  set_socket_source($req_fh, $res_fh);

  (my $url_basename = $url) =~ s{.*/}{};

  my @call_args = %options ? ($url, \%options) : ($url);
  my $response  = $http->get(@call_args);

  my ($got_host, $got_port) = connect_args();
  my ($exp_host, $exp_port) = ( 
    ($new_args{proxy} || $url ) =~ m{^http://([^:/]+?):?(\d*)/}g
  );
  $exp_port ||= 80;

  my $got_req = slurp($req_fh);

  my $label = basename($file);

  is ($got_host, $exp_host, "$label host $exp_host");
  is ($got_port, $exp_port, "$label port $exp_port");
  is( sort_headers($got_req), sort_headers($expect_req), "$label request data");

  my ($rc) = $give_res =~ m{\S+\s+(\d+)}g;
  is( $response->{status}, $rc, "$label response code $rc" )
    or diag $response->{content};

  if ( substr($rc,0,1) eq '2' ) {
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
