package Runops::Recorder::Viewer;

use strict;
use warnings;

use Term::Screen;
use Time::HiRes qw(sleep);

use constant EVENT_SAW_FILE => "\x01";
use constant EVENT_ENTER_FILE => "\x02";
use constant EVENT_ENTER_LINE => "\x03";
use constant EVENT_DIE => "\x04";

my %EVENT = (
    EVENT_SAW_FILE()    => \&_saw_file,
    EVENT_ENTER_FILE()  => \&_enter_file,
    EVENT_ENTER_LINE()  => \&_enter_line,
    EVENT_DIE()  => \&_throw_exception,
);

my $screen = Term::Screen->new();
$screen->clrscr();

for my $accessor (qw(
    io files current_file_path current_file all_lines
    num_lines skip_files last_line skip_installed)) { 
    no strict 'refs'; 
    *{$accessor} = sub { $_[0]->{$accessor}; };
}

sub new {
    my ($pkg, $path) = @_;
    
    open my $in, "<", $path or die $!;
    my $self = bless { 
        io => $in, 
        files => [], 
        skip_files => {},
        last_line => 0,
        skip_installed => $ENV{RR_SKIP_INC} // 0,
    }, $pkg;

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

sub _show_current_file {
    my $self = shift;
    
    $screen->clrscr();
    $screen->at(0, 0);

    if ($self->current_file) {
        $screen->bold->puts($self->current_file_path)->normal();
    }
    else {
        $screen->bold->puts("Can't find file\n")->normal();                
    }
}

sub _enter_file {
    my $self = shift;
    my ($buff);
    $self->io->read($buff, 4);
    my ($file_id) = unpack("L", $buff);
    
    close $self->current_file if $self->current_file;
    $self->{current_file_path} = $self->files->[$file_id];


    if (-e $self->current_file_path) {
        open my $file, "<", $self->current_file_path or die $!;
        $self->{current_file} = $file;
        my @lines = <$file>;
        $self->{all_lines} = \@lines;
        $self->{num_lines} = @lines;

    }
    else {
        $self->{current_file} = undef;
    }
    
    $self->_show_current_file();
    
    1;
}

{
    my $site_libs = join "|", grep { /^\// } @INC;
    my $site_qr = qr{$site_libs};

    sub _show_current_line {
        my $self = shift;
    
        return unless $self->current_file;
        return if $self->skip_files->{$self->current_file_path};
        return if $self->skip_installed && $self->current_file_path =~ $site_qr;

        my $line_no = $self->last_line;
        
        my $screen_cols = $screen->cols;
        my $screen_rows = int(($screen->rows - 4) / 2);
    
        my $from = $line_no > $screen_rows ? $line_no - $screen_rows : 0;
        my $to = $line_no + $screen_rows < $self->num_lines - 1 ? $line_no + $screen_rows : $self->num_lines - 1;
    
        # Adjust to fill screen
        $to += ($screen->rows - 4 - ($to - $from)) if ($to - $from) < $screen->rows - 4;
    
        $screen->at(2, 0);
        $screen->clreos();
        my $p = length $self->num_lines;
    
        my $i = 0;
        for my $l ($from..$to) {    
            last if $l > $self->num_lines;
            $screen->at(2 + $i++, 0);
            $screen->reverse if $l == $line_no;
            my $src = sprintf("% ${p}d: %s", $l, substr($self->all_lines->[$l], 0, $screen_cols - ($p + 2)));
            $screen->puts($src);
            $screen->normal if $l == $line_no;
        }    

        $self->_process_key();
    }
}

sub _enter_line {
    my $self = shift;

    my ($buff);
    $self->io->read($buff, 4);
    my ($line_no) = unpack("L", $buff);    
    $line_no--;

    $self->{last_line} = $line_no;
    
    $self->_show_current_line();
}

sub _throw_exception {
    my $self = shift;

    $screen->at(1, 0);
    $screen->puts("Threw exception at " . $self->last_line . " in " . $self->current_file_path);
}

my %KEY_HANDLER = (
    q => sub { shift->done },
    s => sub { 
        my $self = shift; 
        $self->skip_files->{$self->current_file_path} = 1; 
    },
    a => sub { 
        $_[0]->{skip_installed} ^= 1;
        $screen->at(1, 0)->puts("Skip installed is: " . ((qw(OFF ON)[$_[0]->skip_installed])));
        $screen->getch();
    },
    h => \&_show_help,
);

sub _process_key {
    my $self = shift;
    
    if ($ENV{RR_AUTORUN}) {
        sleep $ENV{RR_AUTORUN};
        return;
    }
    
    my $k = lc $screen->getch();
    $screen->at(1, 0);

    my $handler = $KEY_HANDLER{$k} // sub {};
    $handler->($self);
    
    1;
}

sub _show_help {
    my $self = shift;
    
    $screen->clrscr();
    $screen->at(0, 0)->puts("Help for 'rr-viewer'");
    $screen->at(2, 0)->puts("'a' - Toggle skip files in \@INC at start");
    $screen->at(3, 0)->puts("'s' - Skip the current file");
    $screen->at(5, 0)->puts("'h' - Show this help");
    $screen->at(6, 0)->puts("'q' - Quit prematurely");
    $screen->at(8, 0)->puts("... press the ANY key to continue ...");
    $screen->getch();
    
    $self->_show_current_file();
    $self->_show_current_line();
    
}
sub playback {
    my $self = shift;

    while (defined(my $event = $self->io->getc)) {
        $EVENT{$event}->($self);
    }
    
    $self->done;
}

sub done {
    $screen->at(0, 0)->clreol();
    $screen->at(0, 0)->puts("Playback completed, press the ANY key to quit...");
  
    $screen->getch();
    
    exit 0;
}

sub view {
    my ($pkg, $path) = @_;

    my $viewer = $pkg->new($path);
    
    $viewer->playback();
}

1;