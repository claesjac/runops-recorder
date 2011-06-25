#!/usr/bin/perl

package RecordingHandler;

use strict;
use warnings;

use Test::More qw(no_plan);
BEGIN { use_ok("Runops::Recorder::Reader"); }

# Generate some data
qx{$^X -Mblib -MRunops::Recorder=test-recording t/data/example.pl};
fail "Failed to generate test data" if $? or !-e "test-recording/main.data";

my $keyframes;
sub on_keyframe {
    $keyframes++;
}

my $switched_files;
my %seen_file;
sub on_switch_file {
    my (undef, $id, $path) = @_;
    $seen_file{$id} = $path;
    $switched_files++;
}

my $next_lines;
sub on_next_line {
    $next_lines++;
}

my $reader = Runops::Recorder::Reader->new("test-recording", { handler => __PACKAGE__ });
$reader->read;

is($keyframes, 1);
is($switched_files, 5);
is($seen_file{1}, 't/data/example.pl');
is(scalar keys %seen_file, 3),
is($next_lines, 11);