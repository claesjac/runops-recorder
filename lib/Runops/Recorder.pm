package Runops::Recorder;

use 5.010000;
use strict;
use warnings;
use Carp;

require Exporter;

our @ISA = qw(Exporter);

our %EXPORT_TAGS = ( 'all' => [ qw(
	
) ] );

our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );

our @EXPORT = qw(
	
);

our $VERSION = '0.03';

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
Press 'q' to quit or any other key to step to the next event. Press 's' to skip any 
events in the current file until end of recording. Press 'a' to toggle wether we should 
skip whatever is in @INC when the recorder what loaded. Press 'h' for help.

The environment variable RR_AUTORUN tells the viewer to run automaticly. The value 
should be the sleep time until stepping. And yes, it uses Time::HiRes so you can 
give it fracitonal seconds.

If you set RR_SKIP_INC the autorun will not show @INC files as the 'a' option does.

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
