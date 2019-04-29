#!/usr/bin/env perl

use strict;
use warnings;
use autodie;

use Test::More;

use Errno;
use IO::Socket::SSL;
use IO::Socket::SSL::Utils;
use HTTP::Tiny;

pipe my $srv_addr_r, my $srv_addr_w;

my $addr = '127.0.0.1';

local $SIG{'CHLD'} = 'IGNORE';

fork or do {
    eval {
        close $srv_addr_r;

        my $srv = IO::Socket::SSL->new(
            LocalAddr => $addr,
            Listen => 1,
            ReuseAddr => 1,

            SSL_key => scalar IO::Socket::SSL::Utils::PEM_string2key( _KEY_PEM() ),
            SSL_cert => scalar IO::Socket::SSL::Utils::PEM_string2cert( _CERT_PEM() ),
        );

        die "$!/$@" if !$srv;

        syswrite( $srv_addr_w, $srv->sockname() );
        close $srv_addr_w;

        my $cn = $srv->accept();
        close $srv;

        do { local $/ = "\r\n\r\n", readline($cn) };

        syswrite( $cn, "HTTP/1.1 499 Bad\r\n\r\n" );

        close $cn;

        1;
    };

    warn if $@;

    exit int(!!$@);
};

close $srv_addr_w;

sysread( $srv_addr_r, my $sockaddr, 64 );
close $srv_addr_r;

my ($port) = Socket::unpack_sockaddr_in($sockaddr);

my $http = HTTP::Tiny->new( verify_SSL => 0 );

my $response = $http->post(
    "https://$addr:$port",
    {
        content => ('x' x 32768),
    },
);

SKIP: {
    if ($response->{'status'} == 599) {
        my $epipe_str = do { $! = Errno::EPIPE(); "$!" };
        if ($response->{'content'} =~ m<\Q$epipe_str\E>) {
            skip 'Got EPIPE/SIGPIPE rather than ECONNRESET', 2;
        }
    }

    is( $response->{'status'}, 499, 'Peer-reported status is reported' ) or diag explain $response;
    is( $response->{'reason'}, 'Bad', 'Peer-reported reason is reported' );
}

done_testing();

#----------------------------------------------------------------------

sub _KEY_PEM {
<<END;
-----BEGIN RSA PRIVATE KEY-----
MIIEpAIBAAKCAQEAui5yJ6XWK069cxBXFFAgeqYPl+WfFI9FRqJoMS3NvG7X9fSv
9khhPRTUfoi1PdOURRfsjEt1mVREbu1RlO6TL7+SawXJX+wwLVSZA28rfK+yX24G
bz+oXy6Bo0sTwp1Tojtu0c0Zxp3qbkRazRmVY340+tdlu+dDiI8MoLmS7k/jdtxr
mk0pbxZv7mtQohefwb0//5wUjb8//wqYgnxpKU9nQ22Myk72NEhoGOVusAcr3a1J
6UemQHDqPy5ifi34kABPMRCL3QdSM+TYjjlEV4zn/2j6pZyFInDCCQmVUdfm3UmC
3OkNCv5lXFS9DEBX+FxdwVmAzON95TzVV3zghwIDAQABAoIBAHJj2wt1HtNY+5lY
rsfyOyJgKTCAim8NX9j4K+Abbk6aI+IgRoShD+2BgNWFlSW5e13ARzwjmMtuNOWa
tgc1VgV+RK2wzns7GJahZanwgd2H7aYoaZesmvxwDIKRvEBUfXAt5/bLd0zK9aBu
KwPc9iY9Arwj34PFoX6jtXSC0D3OlW7EGLf4ZpxItuSYwdZS6fxY7lr+XHErtcsw
ttAXGv7YKrN4Py9kGIdzyoFrWw92wv3jLOo4U22qI1j95AdB56T6k6i00ZqgDMRY
Bmb9fZ/WaEMg0O+D4c64hyTTLnmDmG7hxgkKkfbMr1SpwmwxOOFQhF9/vA5rtEcf
QeQe/3ECgYEA9z9u7dnzuzLQXQA8o/0crXaTNMMIGUjnImzDK1srwJeWy5Va77Tx
1zMgWrGSLkn1zyCj0lxzRnta5xNd3EUFZDAbsv6/Grz/pdzfrQH6GiTkTH96Bhy+
LEIRgTyidTj9UiKkgP1xRFbx6emcKTSTXTpfwf8l2lwbQxK1IdamvoMCgYEAwMWg
otEDHU9dKF996g2cYTcRaNxk1hRIcAZ7cfr20ST/KAKJDcUfBPdWjZFMvPq5pfMn
IIRKJZJD3tyDX4xeaTm4R7G8jgfl9Kmw4y2EcocQQ1i2Trkhk/lX1AJdd1ISqApy
AzcwGcStKpuElwJJk3bCOJp9oaVWKvYCVc6ftq0CgYBY5RKyK9nI5YUq2unyoA+O
goJ8xt6DkMWhh+9ICFibvyT1f3aZlroZAIXSdeO0Bt19IiQkfx7nKXTOfhUSHDLL
Ccz7t0HokClubhJxtrNAcSEwK+koh28MpJh8mdtjQCE8Rb5VrknqI0SJMHf4DLIr
I9DIBD+M2e7nV7OOPgnnlwKBgQCX6ydtKMsLjkAcUSUqDw/ujTdrLEVLcTClGHaw
nNdme4GaRmU8NNz9TO8pIhkX1X/5CGcNeTP16A8U0zO1WSoOQy63UZsHU7Il3pVI
c9ata0Olz4PdBokv1JEiw7plDoklZRX08sk1hYnyyhzz5RmW3UCy2w2nFmWR9c5h
UTUNAQKBgQCo+pItT/P3iOxZgF5a83xehHgeCg4qDvRZOq1y+y62cQ7fC5BP2vv/
ZjV+zSYeDNE8V0E1IaQ7HJKwOfrSjaRX7xDHFlKhJjo0hnqdZ8HogWSK4K2r6Vwj
q8c4SyzSjch7tmdslgvwYcU6CSxuQEbz5e863GY8rT2UFhdJNU1etQ==
-----END RSA PRIVATE KEY-----
END
}

sub _CERT_PEM {
<<END;
-----BEGIN CERTIFICATE-----
MIIDFDCCAfygAwIBAgIJALCX/6sKAxONMA0GCSqGSIb3DQEBCwUAMBYxFDASBgNV
BAMMC2V4YW1wbGUuY29tMB4XDTE5MDQyOTIwMzEzN1oXDTE5MDUyOTIwMzEzN1ow
FjEUMBIGA1UEAwwLZXhhbXBsZS5jb20wggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAw
ggEKAoIBAQC6LnInpdYrTr1zEFcUUCB6pg+X5Z8Uj0VGomgxLc28btf19K/2SGE9
FNR+iLU905RFF+yMS3WZVERu7VGU7pMvv5JrBclf7DAtVJkDbyt8r7JfbgZvP6hf
LoGjSxPCnVOiO27RzRnGnepuRFrNGZVjfjT612W750OIjwyguZLuT+N23GuaTSlv
Fm/ua1CiF5/BvT//nBSNvz//CpiCfGkpT2dDbYzKTvY0SGgY5W6wByvdrUnpR6ZA
cOo/LmJ+LfiQAE8xEIvdB1Iz5NiOOURXjOf/aPqlnIUicMIJCZVR1+bdSYLc6Q0K
/mVcVL0MQFf4XF3BWYDM433lPNVXfOCHAgMBAAGjZTBjMB0GA1UdDgQWBBRY95YI
lp1Jhm7GYoBn68lnGNdTyDAfBgNVHSMEGDAWgBRY95YIlp1Jhm7GYoBn68lnGNdT
yDAJBgNVHRMEAjAAMBYGA1UdEQQPMA2CC2V4YW1wbGUuY29tMA0GCSqGSIb3DQEB
CwUAA4IBAQBoWwvS6xHrfBcoVqdReH+j9bhxKypYn2q165BOlMkOqax8qkWK3/Oy
rvChBcus3btzxMoICZWFIwD9hVRXpFw45vuIVaAu6fqXeUBbHfhtyd9MynTHMt3x
H2CLndmCQD2atuT+E0OUDNv4sCxEFyiUSqkpLzQzdaLCIuDVg7Jep+JUqKjASKVs
1QPGbMbCE7CQaCbv3UHM3N1SCkZDv1TNPH62MJHppsyEoTKEpkEtC5bHRgxHx2HF
700bJ1pUsqRcjIDS07Z61+bTGvN1h4HKiVj/ToD6NT2sTnzIkhUbgYYiLN/Vow/H
b94i3jwV2b9NVFMQgs17B/dp22fwV2NC
-----END CERTIFICATE-----
END
}
