package t::Util;

use strict;
use warnings;

use IO::File q[SEEK_SET];

BEGIN {
    our @EXPORT_OK = qw(
        rewind
        tmpfile
        slurp
        $CRLF
        $LF
    );

    require Exporter;
    *import = \&Exporter::import;
}

*CRLF = \"\x0D\x0A";
*LF   = \"\x0A";

sub rewind(*) {
    seek($_[0], 0, SEEK_SET)
      || die(qq/Couldn't rewind file handle: '$!'/);
}

sub tmpfile {
    my $fh = IO::File->new_tmpfile
      || die(qq/Couldn't create a new temporary file: '$!'/);

    binmode($fh)
      || die(qq/Couldn't binmode temporary file handle: '$!'/);

    if (@_) {
        print({$fh} @_)
          || die(qq/Couldn't write to temporary file handle: '$!'/);

        seek($fh, 0, SEEK_SET)
          || die(qq/Couldn't rewind temporary file handle: '$!'/);
    }

    return $fh;
}

sub slurp (*) {
    my ($fh) = @_;

    rewind($fh);

    binmode($fh)
      || die(qq/Couldn't binmode file handle: '$!'/);

    my $exp = -s $fh;
    my $buf = do { local $/; <$fh> };
    my $got = length $buf;

    ($exp == $got)
      || die(qq[I/O read mismatch (expexted: $exp got: $got)]);

    return $buf;
}

1;

