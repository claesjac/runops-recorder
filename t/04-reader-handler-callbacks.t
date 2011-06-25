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
my $switched_files;
my $next_lines;

my %handlers = (
    on_keyframe => sub { $keyframes++ },
    on_switch_file => sub { $switched_files++ },
    on_next_line => sub { $next_lines++ },
);

my $reader = Runops::Recorder::Reader->new("test-recording", { handlers => \%handlers });
$reader->read_all;

is($keyframes, 1);
is($switched_files, 5);
is($next_lines, 11);