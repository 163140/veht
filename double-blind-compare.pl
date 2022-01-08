#!/usr/bin/env perl
#===============================================================================
#
#         FILE: double-blind-compare.pl
#
#        USAGE: ./double-blind-compare.pl
#
#  DESCRIPTION:
#
#      OPTIONS: ---
# REQUIREMENTS: ---
#         BUGS: ---
#        NOTES: ---
#       AUTHOR: YOUR NAME (),
# ORGANIZATION:
#      VERSION: 1.0
#      CREATED: 06.02.2021 09:04:18
#     REVISION: ---
#===============================================================================

use strict;
use warnings;
use utf8;
use 5.030;

my @A = ('s29.mkv', 's31.mkv', 's33.mkv', 's35.mkv');

my $end = scalar @A;

for my $first (@A) {
	for my $second (@A) {
		my $out = int(rand(100));
		my $cmd = "ffmpeg -hide_banner -i " . $first . " -i " . $second . " -filter_complex \'hstack=inputs=2[a];[a]scale=1920:-1\' -c:v ffv1 " . " dbc" . $out . ".mkv 2> /dev/null";
		system $cmd;
		say ($first . " + " . $second . " -> " . $out . ".mkv");
	}
}




