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
my $next_statements;
my $enter_subs;

my %handlers = (
    on_keyframe => sub { $keyframes++ },
    on_switch_file => sub { $switched_files++ },
    on_next_statement => sub { $next_statements++ },
    on_enter_sub => sub { $enter_subs++ },
);

my $reader = Runops::Recorder::Reader->new("test-recording", { handlers => \%handlers, skip_keyframes => 0 });
$reader->read_all;

is($keyframes, 1);
is($switched_files, 5);
is($enter_subs, 3);
is($next_statements, 13);