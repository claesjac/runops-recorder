package Runops::Recorder;

use 5.010000;
use strict;
use warnings;
use Carp;

require Exporter;
use AutoLoader;

our @ISA = qw(Exporter);

our %EXPORT_TAGS = ( 'all' => [ qw(
	
) ] );

our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );

our @EXPORT = qw(
	
);

our $VERSION = '0.01';

sub AUTOLOAD {
    # This AUTOLOAD is used to 'autoload' constants from the constant()
    # XS function.

    my $constname;
    our $AUTOLOAD;
    ($constname = $AUTOLOAD) =~ s/.*:://;
    croak "&Runops::Recorder::constant not defined" if $constname eq 'constant';
    my ($error, $val) = constant($constname);
    if ($error) { croak $error; }
    {
	no strict 'refs';
	# Fixed between 5.005_53 and 5.005_61
#XXX	if ($] >= 5.00561) {
#XXX	    *$AUTOLOAD = sub () { $val };
#XXX	}
#XXX	else {
	    *$AUTOLOAD = sub { $val };
#XXX	}
    }
    goto &$AUTOLOAD;
}

require XSLoader;
XSLoader::load('Runops::Recorder', $VERSION);

1;
__END__
=head1 NAME

Runops::Recorder - Runops replacement which saves what is being performed

=head1 SYNOPSIS

  # will save to a runops-recorder.data file in the current directory
  perl -MRunops::Recorder <program>

  # and then to view the recording
  rr-viewer runops-recorder.data
  
=head1 DESCRIPTION

Runops::Recorder is an alternative runops which saves what it does into a file 
that can later be viewed using the rr-viewer tool.

=head1 VIEWING THE RECORDING

Use the 'rr-viewer' tool. It just takes the path with the recording as an argument. 
Press 'q' to quit or any other key to step to the next event.

=head1 TODO

Record more things such as changes to variables, opened file descriptors etc.

=head1 AUTHOR

Claes Jakobsson, E<lt>claesjac@cpan.orgE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2011 by Claes Jakobsson

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.10.0 or,
at your option, any later version of Perl 5 you may have available.


=cut
