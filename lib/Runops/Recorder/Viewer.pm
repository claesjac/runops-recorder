package Runops::Recorder::Viewer;

use strict;
use warnings;

use Term::Screen;

use constant EVENT_SAW_FILE => "\x01";
use constant EVENT_ENTER_FILE => "\x02";
use constant EVENT_ENTER_LINE => "\x03";

my %EVENT = (
    EVENT_SAW_FILE()    => \&_saw_file,
    EVENT_ENTER_FILE()  => \&_enter_file,
    EVENT_ENTER_LINE()  => \&_enter_line,
);

my $screen = Term::Screen->new();
$screen->clrscr();

for my $accessor (qw(io files current_file_path current_file all_lines num_lines)) { 
    no strict 'refs'; 
    *{$accessor} = sub { $_[0]->{$accessor}; };
}

sub new {
    my ($pkg, $path) = @_;
    
    open my $in, "<", $path or die $!;
    my $self = bless { io => $in, files => [] }, $pkg;

    return $self;
}

sub _saw_file {
    my $self = shift;
    my ($buff, $file_id, $len, $path);
    $self->io->read($buff, 6);
    ($file_id, $len) = unpack("LS", $buff);
    $self->io->read($path, $len);
    $self->files->[$file_id] = $path;
}

sub _enter_file {
    my $self = shift;
    my ($buff);
    $self->io->read($buff, 4);
    my ($file_id) = unpack("L", $buff);
    
    close $self->current_file if $self->current_file;
    $self->{current_file_path} = $self->files->[$file_id];
    open my $file, "<", $self->current_file_path or die $!;
    $self->{current_file} = $file;
    my @lines = <$file>;
    $self->{all_lines} = \@lines;
    $self->{num_lines} = @lines;

    $screen->clrscr();
    $screen->at(0, 0);
    $screen->bold->puts($self->current_file_path)->normal();
    
    1;
}

sub _enter_line {
    my $self = shift;
    my ($buff);
    $self->io->read($buff, 4);
    my ($line_no) = unpack("L", $buff);
    
    $line_no--;
    
    my $screen_cols = $screen->cols;
    
    my $from = $line_no > 10 ? $line_no - 10 : 0;
    my $to = $line_no + 10 < $self->num_lines - 1 ? $line_no + 10 : $self->num_lines - 1;
    
    $screen->at(2, 0);
    $screen->clreos();
    my $p = length $self->num_lines;
    
    my $i = 0;
    for my $l ($from..$to) {    
        $screen->at(2 + $i++, 0);
        $screen->reverse if $l == $line_no;
        my $src = sprintf("% ${p}d: %s", $l, substr($self->all_lines->[$l], 0, $screen_cols - ($p + 2)));
        $screen->puts($src);
        $screen->normal if $l == $line_no;
    }

    my $chr = $screen->getch();
    if ($chr eq 'q') { $self->done; }
}

sub playback {
    my $self = shift;

    while (defined(my $event = $self->io->getc)) {
        $EVENT{$event}->($self);
    }
}

sub done {
    $screen->clrscr();
    exit 0;
}

sub view {
    my ($pkg, $path) = @_;

    my $viewer = $pkg->new($path);
    
    $viewer->playback();
}

1;