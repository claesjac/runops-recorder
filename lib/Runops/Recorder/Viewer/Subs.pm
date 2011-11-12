package Runops::Recorder::Viewer::Subs;

use strict;
use warnings;

sub new {
    my $pkg = shift;    
    my $self = bless { stack => [] }, $pkg;
    return $self;
}

sub on_enter_sub {
    my ($self, $id, $identifier) = @_;
    printf "% 4d: %s\n", scalar @{$self->stack}, $identifier;
}

1;