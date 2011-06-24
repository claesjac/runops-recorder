package Runops::Recorder::Reader;

use strict;
use warnings;

use accessors::ro qw(tail);

sub new {
    my ($pkg, $dir, $opts) = @_;
    
    $opts //= { follow => 0, tail => 0 };
    
    my $self = bless {}, $pkg;
        
    $self->wait_for_keyframe if $self->tail;
}

sub wait_for_keyframe {
    
}

1;
