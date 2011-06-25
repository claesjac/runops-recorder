#!/usr/bin/perl

use strict;
use warnings;

use Test::More qw(no_plan);
BEGIN { use_ok("Runops::Recorder::Reader"); }

# Generate some data
qx{$^X -Mblib -MRunops::Recorder=test-recording t/data/example.pl};
fail "Failed to generate test data" if $? or !-e "test-recording/main.data";

my $reader = Runops::Recorder::Reader->new("test-recording");

my ($cmd, $data) = $reader->read_next();
is($cmd, 1);
is($data, "\1\0\0\0");
is ($reader->get_file(1), "t/data/example.pl");

($cmd, $data) = $reader->read_next();
is($cmd, 2);
is($data, "\3\0\0\0");

# Skip until next enter file
$reader->skip_until(1);

($cmd, $data) = $reader->read_next();
is($cmd, 1);
is($data, "\2\0\0\0");
like ($reader->get_file(2), qr/strict\.pm$/);
