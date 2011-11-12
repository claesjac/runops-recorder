package Runops::Recorder::Viewer::Exceptions;

use 5.010;
use strict;
use warnings;

sub new { bless {}, shift; }

sub on_next_statement {
    my ($self, $line_no) = @_;
    $self->{last_line} = $line_no;
}

sub on_switch_file {
    my ($self, undef, $path) = @_;
    $self->{current_file} = $path;
}

sub on_die {
    my $self = shift;    
    say  "Died at ", $self->{last_line}, " in ", $self->{current_file};
}

1;