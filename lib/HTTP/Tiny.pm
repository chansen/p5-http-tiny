package HTTP::Tiny;
use strict;
use warnings;

our $VERSION = '0.1';

use Carp qw[croak];

sub new {
    my($class, %args) = @_;
    return bless {
        timeout => 60,
        agent   => "HTTP-Tiny/$VERSION",
        %args
    }, $class;
}

sub proxy {
    @_ == 1 || @_ == 2 || croak(q/Usage: $http->proxy([url])/);
    my $self = shift;
    return @_ ? $self->{proxy} = $_[1] : $self->{proxy};
}

sub has_proxy {
    @_ == 1 || croak(q/Usage: $http->has_proxy()/);
    my ($self) = @_;
    return defined $self->{proxy};
}

sub get {
    my ($self, $url, %args) = @_;

    my ($status, $reason, $headers, $content) = eval {
        $self->_get($url, \%args);
    };

    if (my $e = $@) {
        $status  = 599;
        $reason  = 'Internal Exception';
        $content = "$e";
        $headers = {
            'content-type'   => 'text/plain',
            'content-length' => length $content,
        };
    }
    return ($status, $reason, $headers, $content);
}

sub _get {
    my ($self, $url, $args) = @_;

    my ($scheme, $host, $port, $path_query)
      = HTTP::Tiny::Handle->split_url($url);

    $scheme eq 'http'
      or croak(qq/Unsupported URL scheme '$scheme'/);

    my $handle = HTTP::Tiny::Handle->new(timeout => $self->{timeout});
    my $request_uri;
    if ($self->has_proxy) {
        $handle->connect($self->proxy);
        $request_uri = "$scheme://$host:$port$path_query";
    }
    else {
        $handle->connect($url);
        $request_uri = $path_query;
    }

    my $req_headers = {};
    if ($args->{headers}) {
        while (my ($k, $v) = each %{ $args->{headers} }) {
            $req_headers->{lc $k} = $v;
        }
    }
    $req_headers->{'host'}       = "$host:$port";
    $req_headers->{'connection'} = "close";
    $req_headers->{'user-agent'} = $self->{agent}
      unless $req_headers->{'user-agent'};

    $handle->write_request_header('GET', $request_uri, $req_headers);

    my ($version, $status, $reason, $res_headers)
      = $handle->read_response_header;

    my $content;
    my $on_content = $args->{on_content};

    if (!$on_content || $status !~ /^2/) {
        $on_content = sub { $content .= $_[0] };
    }

    if ($res_headers->{'content-length'}) {
        $handle->read_content($on_content, $res_headers->{'content-length'});
    }
    elsif ($res_headers->{'transfer-encoding'}) {
        $handle->read_chunked_body($on_content);
    }

    $handle->close;

    return ($status, $reason, $res_headers, $content);
}

package HTTP::Tiny::Handle;
use strict;
use warnings;

use Carp       qw[croak];
use Errno      qw[EINTR];
use IO::Socket qw[SOCK_STREAM];

sub BUFSIZE () { 32768 }

my $Printable = sub {
    local $_ = shift;
    s/\r/\\r/g;
    s/\n/\\n/g;
    s/\t/\\t/g;
    s/([^\x20-\x7E])/sprintf('\\x%.2X', ord($1))/ge;
    $_;
};

sub new {
    my ($class, %args) = @_;
    return bless {
        rbuf             => '',
        timeout          => 60,
        max_line_size    => 16384,
        max_header_lines => 64,
        %args
    }, $class;
}

sub host {
    @_ == 1 || croak(q/Usage: $handle->host()/);
    return $_[0]->{host};
}

sub port {
    @_ == 1 || croak(q/Usage: $handle->port()/);
    return $_[0]->{port};
}

sub split_url {
    @_ == 2 || croak(q/Usage: / . __PACKAGE__ . q/->split_url(url)/);
    my ($proto, $url) = @_;

    my ($scheme, $authority, $path_query) = $url =~ m<\A([^:/?#]+)://([^/?#]+)([^#]*)>
      or croak(q/Cannot parse URL: / . $Printable->($url));

    $scheme     = lc $scheme;
    $path_query = "/$path_query" unless $path_query =~ m<\A/>;

    $authority =~ s/\A[^@]*@//;     # userinfo

    my $port = do {
        if ($authority =~ s/:([0-9]*)\z// && length $1) {
            $1;
        }
        else {
            ($scheme eq 'http' ? 80 : $scheme eq 'https' ? 443 : undef);
        }
    };

    my $host = lc $authority;

    return ($scheme, $host, $port, $path_query);
}

sub connect {
    @_ == 2 || croak(q/Usage: $handle->connect(url)/);
    my ($self, $url) = @_;

    my ($scheme, $host, $port) = $self->split_url($url);

    $scheme eq 'http'
      or croak(qq/Unsupported URL scheme '$scheme'/);

    $host !~ /\A\[.*\]\z/
      or croak(qq/Unsupported URL host '$host'/);

    $self->{fh} = IO::Socket::INET->new(
        PeerHost  => $host,
        PeerPort  => $port,
        Proto     => 'tcp',
        Type      => SOCK_STREAM,
        Timeout   => $self->{timeout}
    ) or croak(qq/Could not connect to '$host:$port': $@/);

    binmode($self->{fh})
      or croak(qq/Could not binmode() socket: '$!'/);

    $self->{host} = $host;
    $self->{port} = $port;

    return $self;
}

sub close {
    @_ == 1 || croak(q/Usage: $handle->close()/);
    my ($self) = @_;
    CORE::close($self->{fh})
      or croak(qq/Could not close socket: '$!'/);
}

sub write {
    @_ == 2 || croak(q/Usage: $handle->write(buf)/);
    my ($self, $buf) = @_;

    utf8::downgrade($buf, 1)
      or croak(q/Wide character in write()/);

    my $len = length $buf;
    my $off = 0;

    while () {
        $self->can_write
          or croak(q/Timed out while waiting for socket to become ready for writing/);
        my $r = syswrite($self->{fh}, $buf, $len, $off);
        if (defined $r) {
            $len -= $r;
            $off += $r;
            last unless $len;
        }
        elsif ($! != EINTR) {
            croak(qq/Could not write to socket: '$!'/);
        }
    }
    return $off;
}

sub read {
    @_ == 2 || @_ == 3 || croak(q/Usage: $handle->read(len [, partial])/);
    my ($self, $len, $partial) = @_;

    my $off  = 0;
    my $buf  = '';
    my $got = length $self->{rbuf};

    if ($got) {
        my $take = ($got < $len) ? $got : $len;
        $buf  = substr($self->{rbuf}, 0, $take, '');
        $len -= $take;
        $off += $take;
    }

    while ($len) {
        $self->can_read
          or croak(q/Timed out while waiting for socket to become ready for reading/);
        my $r = sysread($self->{fh}, $buf, $len, $off);
        if (defined $r) {
            last unless $r;
            $len -= $r;
            $off += $r;
        }
        elsif ($! != EINTR) {
            croak(qq/Could not read from socket: '$!'/);
        }
    }
    if ($len && !$partial) {
        croak(q/Unexpected end of stream/);
    }
    return $buf;
}

sub readline {
    @_ == 1 || croak(q/Usage: $handle->readline()/);
    my ($self) = @_;

    my $off = length $self->{rbuf};

    while () {
        if ($self->{rbuf} =~ s/\A ([^\x0D\x0A]* \x0D?\x0A)//x) {
            return $1;
        }
        if ($off >= $self->{max_line_size}) {
            croak(qq/Line size exceeds the maximum allowed size of $self->{max_line_size}/);
        }
        $self->can_read
          or croak(q/Timed out while waiting for socket to become ready for reading/);
        my $r = sysread($self->{fh}, $self->{rbuf}, BUFSIZE, $off);
        if (defined $r) {
            last unless $r;
            $off += $r;
        }
        elsif ($! != EINTR) {
            croak(qq/Could not read from socket: '$!'/);
        }
    }
    croak(q/Unexpected end of stream while looking for line/);
}

sub read_header_lines {
    @_ == 1 || croak(q/Usage: $handle->read_header_lines()/);
    my ($self) = @_;

    my %headers = ();
    my $lines   = 0;
    my $val;

    while () {
         my $line = $self->readline;

         if (++$lines >= $self->{max_header_lines}) {
             croak(qq/Header lines exceeds maximum number allowed of $self->{max_header_lines}/);
         }
         elsif ($line =~ /\A ([^\x00-\x1F\x7F:]+) : [\x09\x20]* ([^\x0D\x0A]*)/x) {
             my ($field_name) = lc $1;
             if (exists $headers{$field_name}) {
                 for ($headers{$field_name}) {
                     $_ = [$_] unless ref $_ eq "ARRAY";
                     push @$_, $2;
                     $val = \$_->[-1];
                 }
             }
             else {
                 $val = \($headers{$field_name} = $2);
             }
         }
         elsif ($line =~ /\A [\x09\x20]+ ([^\x0D\x0A]*)/x) {
             $val
               or croak(q/Unexpected header continuation line/);
             next unless length $1;
             $$val .= ' ' if length $$val;
             $$val .= $1;
         }
         elsif ($line =~ /\A \x0D?\x0A \z/x) {
            last;
         }
         else {
            croak(q/Malformed header line: / . $Printable->($line));
         }
    }
    return \%headers;
}

my %HeaderCase = (
    'content-md5'      => 'Content-MD5',
    'etag'             => 'ETag',
    'te'               => 'TE',
    'www-authenticate' => 'WWW-Authenticate',
    'x-xss-protection' => 'X-XSS-Protection',
);

sub write_header_lines {
    @_ == 2 || croak(q/Usage: $handle->write_header_lines(headers)/);
    my($self, $headers) = @_;

    my $buf = '';
    while (my ($k, $v) = each %$headers) {
        my $field_name = lc $k;
        if (exists $HeaderCase{$field_name}) {
            $field_name = $HeaderCase{$field_name};
        }
        else {
            $field_name =~ s/\b(\w)/\u$1/g;
        }
        for (ref $v eq 'ARRAY' ? @$v : $v) {
            $buf .= $field_name;
            $buf .= ': ';
            $buf .= $_;
            $buf .= "\x0D\x0A";
        }
    }
    $buf .= "\x0D\x0A";
    return $self->write($buf);
}

sub read_content {
    @_ == 3 || croak(q/Usage: $handle->read_content(callback, content_length)/);
    my ($self, $cb, $content_length) = @_;

    my $len = $content_length;
    while ($len) {
        my $read = ($len > BUFSIZE) ? BUFSIZE : $len;
        $cb->($self->read($read));
        $len -= $read;
    }

    return $content_length;
}

sub write_content {
    @_ == 2 || @_ == 3 || croak(q/Usage: $handle->write_content(callback [, content_length])/);
    my ($self, $cb, $content_length) = @_;

    my $len = 0;
    while () {
        my $data = $cb->();

        utf8::downgrade($data, 1)
          or croak(q/Wide character in write_content()/);

        defined $data && length $data
          or last;

        $len += $self->write($data);
    }

    @_ < 3 || $len == $content_length
      or croak(qq/Content-Length missmatch (got: $len expected: $content_length)/);

    return $len;
}

sub read_chunked_body {
    @_ == 2 || croak(q/Usage: $handle->read_chunked_body(callback)/);
    my ($self, $cb) = @_;

    while () {
        my $head = $self->readline;

        $head =~ /\A ([A-Fa-f0-9]+)/x
          or croak(q/Malformed chunk head: / . $Printable->($head));

        my $len = hex($1)
          or last;

        while ($len) {
            my $read = ($len > BUFSIZE) ? BUFSIZE : $len;
            $cb->($self->read($read));
            $len -= $read;
        }

        $self->read(2) eq "\x0D\x0A"
          or croak(q/Malformed chunk: missing CRLF after chunk data/);
    }
    return $self->read_header_lines;
}

sub write_chunked_body {
    @_ == 2 || @_ == 3 || croak(q/Usage: $handle->write_chunked_body(callback [, trailers])/);
    my ($self, $cb, $trailers) = @_;

    $trailers ||= {};

    my $len = 0;
    while () {
        my $data = $cb->();

        utf8::downgrade($data, 1)
          or croak(q/Wide character in write_chunked_body()/);

        defined $data && length $data
          or last;

        $len += length $data;

        my $chunk  = sprintf '%X', length $data;
           $chunk .= "\x0D\x0A";
           $chunk .= $data;
           $chunk .= "\x0D\x0A";

        $self->write($chunk);
    }
    $self->write("0\x0D\x0A");
    $self->write_header_lines($trailers);
    return $len;
}

sub read_response_header {
    @_ == 1 || croak(q/Usage: $handle->read_response_header()/);
    my ($self) = @_;

    my $line = $self->readline;

    $line =~ /\A (HTTP\/1.[0-1]) [\x09\x20]+ ([0-9]{3}) [\x09\x20]+ ([^\x0D\x0A]*) \x0D?\x0A/x
      or croak(q/Malformed Status-Line: / . $Printable->($line));

    my ($version, $status, $reason) = ($1, $2, $3);

    return ($version, $status, $reason, $self->read_header_lines);
}

sub write_request_header {
    @_ == 4 || @_ == 5 || croak(q/Usage: $handle->write_request_header(method, request_uri, headers [, protocol])/);
    my ($self, $method, $request_uri, $headers, $protocol) = @_;

    $protocol ||= 'HTTP/1.1';

    return $self->write("$method $request_uri $protocol\x0D\x0A")
         + $self->write_header_lines($headers);
}

sub can_read {
    @_ == 1 || @_ == 2 || croak(q/Usage: $handle->can_read([timeout])/);
    my ($self, $timeout) = @_;

    $timeout = $self->{timeout}
      if @_ == 1;

    my $fd = fileno $self->{fh};
    defined $fd && $fd >= 0
      or croak(q/select(2): 'Bad file descriptor'/);

    my $initial = time;
    my $pending = $timeout;
    my $nfound;

    vec(my $fdset = '', $fd, 1) = 1;

    while () {
        $nfound = select($fdset, undef, undef, $pending);
        if ($nfound == -1) {
            $! == EINTR
              or croak(qq/select(2): '$!'/);
            redo if !$timeout || ($pending = $timeout - (time - $initial)) > 0;
            $nfound = 0;
        }
        last;
    }
    $! = 0;
    return $nfound;
}

sub can_write {
    @_ == 1 || @_ == 2 || croak(q/Usage: $handle->can_write([timeout])/);
    my ($self, $timeout) = @_;

    $timeout = $self->{timeout}
      if @_ == 1;

    my $fd = fileno $self->{fh};
    defined $fd && $fd >= 0
      or croak(q/select(2): 'Bad file descriptor'/);

    my $initial = time;
    my $pending = $timeout;
    my $nfound;

    vec(my $fdset = '', $fd, 1) = 1;

    while () {
        $nfound = select(undef, $fdset, undef, $pending);
        if ($nfound == -1) {
            $! == EINTR
              or croak(qq/select(2): '$!'/);
            redo if !$timeout || ($pending = $timeout - (time - $initial)) > 0;
            $nfound = 0;
        }
        last;
    }
    $! = 0;
    return $nfound;
}

1;

__END__

