package Runops::Recorder::Reader;

use strict;
use warnings;

use Fcntl qw(SEEK_CUR SEEK_END SEEK_SET);
use File::Spec;

use accessors::ro qw(files_fh data_fh files handler);

sub new {
    my ($pkg, $dir, $opts) = @_;
    
    $opts //= {};
    
    open my $data_fh, "<", File::Spec->catfile($dir, "main.data") or die $!;
    open my $files_fh, "<", File::Spec->catfile($dir, "main.files") or die $!;
    
    my $handler;
    if ($opts->{handler}) {
        $handler = _make_class_handler($opts->{handler});
    }
    elsif ($opts->{handlers}) {
        $handler = _make_callback_handler($opts->{handlers});
    }
    
    my $self = bless { 
        data_fh => $data_fh, 
        files_fh => $files_fh,
        files => {},
        handler => $handler,
    }, $pkg;

    $self->find_next_keyframe;
    $self->read_files;
    
    return $self;
}

{
    my %CMD_TO_NAME = (
        0 => 'on_keyframe',
        1 => 'on_switch_file',
        2 => 'on_next_line',
    );
    
    my %CMD_DATA_TRANSFORMER = (
        0 => sub { return (0) },
        1 => sub { my ($file_no) = unpack("L", $_[0]); return ($file_no, $_[1]->get_file($file_no)) },
        2 => sub { my ($line_no) = unpack("L", $_[0]); return ($line_no) },
    );
    
    sub _make_class_handler {
        my ($target) = @_;
    
        my $handler = sub {
            my ($cmd, $data, $reader) = @_;
            my $cb = $target->can($CMD_TO_NAME{$cmd});
            $cb->($target, $CMD_DATA_TRANSFORMER{$cmd}->($data, $reader), $reader) if $cb;
            1;
        };
    
        return $handler;
    }
    
    sub _make_callback_handler {
        my ($target) = @_;
        
        my %callbacks = map { 
            my $name = $CMD_TO_NAME{$_};
            ($_, exists $target->{$name} ? $target->{$name} : sub {})
        } keys %CMD_TO_NAME;
        
        my $handler = sub {
            my ($cmd, $data, $reader) = @_;
            $callbacks{$cmd}->($CMD_DATA_TRANSFORMER{$cmd}->($data, $reader), $reader);
        };
    }
}

sub read_files {
    my $self = shift;
    
    my $files_fh = $self->files_fh;
    
    # Reset that we're not at EOF
    $files_fh->seek(0, SEEK_CUR);
    while (<$files_fh>) {
        chomp;
        my ($id, $name) = split /:/, $_, 2;
        $self->{files}->{$id} = $name;
    }
}

sub get_file {
    my ($self, $id) = @_;
    $self->read_files();
    return $self->files->{$id};
}

sub read_next {
    my $self = shift;
    
    # Assume the file is synced
    my $buff;
    my $read = $self->data_fh->read($buff, 5);
    if ($read == 5) {
        # decode
        my ($cmd, $data) = unpack("Ca*", $buff);
        $self->handler->($cmd, $data, $self) if $self->handler;
        return ($cmd, $data);
    }
    elsif ($read) {
        $self->data_fh->seek(-$read, SEEK_CUR);
    }
    
    return;
}

sub read {
    my $self = shift;
    while ($self->read_next()) {
        # nop
    }
}

sub skip_until {
    my ($self, $target_cmd) = @_;
    
    my ($cmd, $data);
    do {
        ($cmd, $data) = $self->read_next();
    }
    until ($cmd == $target_cmd);

    $self->data_fh->seek(-5, SEEK_CUR);
}

sub find_next_keyframe {
    my $self = shift;
    
    my $data_fh = $self->data_fh;
    
    my $read_keyframe = 0;

    # TODO: also handle tail mode
    while ($read_keyframe < 5) {
        my $next = $data_fh->getc;
        last unless defined $next;
        $read_keyframe = 0, next if ord($next) != 0;
        $read_keyframe++;        
    }
    
    $data_fh->seek(-5, SEEK_CUR);

    1;
}

1;
__END__
=pod

=head1 NAME

Runops::Recorder::Reader - A class which can read the recording files

=head1 DESCRIPTION

Instances of this class reads a recording. It can work both as a stream-based 
reader where you ask for the next entry or as a event generator that calls 
your handlers for each type of item it reads.

=head1 SYNOPSIS

  # main script
  use Runops::Recorder::Reader;
  
  my $reader = Runops::Recorder::Reader->read("my-recording", { 
    handler => "MyRecordingHandler",
  });
  
  $reader->read();
  
  # MyRecordingHandler.pm
  package MyRecordingHandler;
  
  sub on_switch_file {
    my ($self, $id, $path) = @_;
    print "Now in file: $path\n";
  }
  
  sub on_next_line {
    my ($self, $line_no) = @_;
    print "Executing line: $line_no\n";
  }
  
  1;
  
=head1 INTERFACE

=cut


