package t::SimpleCookieJar;

use strict;
use warnings;

sub new {
    my $class = shift;
    return bless {} => $class;
}

sub add {
    my ($self, $url, $cookies) = @_;
    
    $self->{$url} = $cookies;
}

sub cookie_header {
    my ($self, $url) = @_;

    return $self->{$url};
}

1;
