#!/usr/bin/env perl
#===============================================================================
#
#         FILE: blur.pl
#
#        USAGE: blur.pl source-video.mp4 algorithm outvideo.mkv
#
#  DESCRIPTION: blur a video according math law
#
#      OPTIONS: none
# REQUIREMENTS: ffmpeg, imagemagick, MCE::Map, ffprobe, Filesys::Df
#         BUGS: ---
#        NOTES: ---
#       AUTHOR: EA1A87, 163140@autistici.org
#      VERSION: 0.0
#      CREATED: 06.01.2022 15:24:07
#     REVISION: 0
#===============================================================================

# ВОЛШЕБНЫЕ ЧИСЛА
use constant BLUR_RADIUS=> 60; # МАКСИМАЛЬНЫЙ РАДИУС РАЗМЫТИЯ / man imagemagick
use constant BLUR_POWER	=> 17; # МАКСИМАЛЬНЫЙ СИЛА РАЗМЫТИЯ / man imagemagick
use constant FPS				=> 30;
use constant LOGLEVEL		=> "quiet"; # "quiet" or "warning" or "debug"
use constant IMGFMT			=> "ppm"; # Формат промежуточных картинок

use strict;
use warnings;
use autodie;
use utf8;
use feature								qw(signatures say);

no warnings								"experimental::signatures";

use File::Temp						qw/tempdir cleanup tempfile/;
use Cwd										qw/cwd/;
use List::Util						qw/zip/;
use File::Spec::Functions	qw/catfile/;
use MCE::Map;
use Filesys::Df;

my %Algo = (
	linear_in	=> sub ($Value, $Frame, $Frames) {
			$Value * ( $Frame / $Frames );				 },
	linear_out=> sub ($Value, $Frame, $Frames) {
			$Value * ( 1 - $Frame / $Frames );		 },
);

####################### MAIN SECTION ###########################
{
	my ($Infile, $Algo, $Outfile) = cli(@ARGV);
	my $Workdir = prepare($Infile);
	blur($Workdir, $Algo);
	end($Outfile, $Workdir);
}

###################### Utility funcs ###########################
sub is_correct ($Infile) { 1; }

sub imglist($Dir) {
	opendir(my $DH, $Dir);
	my @Files = sort grep(/${\IMGFMT}/, readdir($DH));
	closedir $DH;
	return @Files;
}

sub round2 { my $Num = shift; return (int($Num*100)/100); }

sub is_space_enough($File) {
	my $Frames =
		qx(ffprobe -v error -select_streams v:0 -count_packets -show_entries stream=nb_read_packets -of csv=p=0 $File);
	my ($Fh, $Temp) = tempfile();
	my $Out = $Temp . "." . IMGFMT;
	qx(ffmpeg -v 0 -ss 00:00 -i $File -vframes 1 -q:v 2 $Out);
	my $Size = -s $Out;
	my $Required = $Size * $Frames;
	my $Tmp_free_space = df($Temp, 1)->{"bavail"};
	my $CWD_free_space = df($File, 1)->{"bavail"};
	unlink $Out;
	close $Fh;
	my $Is_ok = (($Required < $Tmp_free_space) or ($Required < $CWD_free_space));
	return $Is_ok;
}


############################ CLI SECTION ###################################
sub help_msg {
	say "USAGE: blur.pl input_video_file blur_algorithm outputvideo.mkv";
	say "Implemented blur algorithms: linear_in, linear_out";
	say "See perldoc blur.pl for details\n";
}

sub cli {
	my ($In, $Command, $Out) = @_;

	if (not ( (scalar @_) == 3)) { help_msg() and die "Wrong args\n"; }

	if (not (-e -r $In)) {
		help_msg() and die "Input file don't exist or unreadable\n"; }

	if (not $Algo{$Command}) { help_msg() and die "$Command not implemented"; }

	die "Destination directory unwritable\n" unless (-w cwd());
	warn "Output file exist\n" if (-e $Out);
	die "No free space\n" unless is_space_enough($In);
	return ($In, $Command, $Out);
}

##################### PREPARE SECTION ###############################
sub to_images ($In, $Wdir) {
	qx | ffmpeg -loglevel ${\LOGLEVEL} -i $In -vf ${\FPS} "$Wdir/%7d.${\IMGFMT}" |;
};

sub prepare ($Infile)	{
	my $Workdir	= tempdir(DIR => cwd(), CLEANUP => 1);
	to_images($Infile, $Workdir) if is_correct($Infile);
	return $Workdir;
}

##################### BLUR SECTION ###############################
sub blur_image { #($Blur_Radius, $Blur_Power,$Filename)
	my ($Blur_Radius, $Blur_Power,$Filename) = @$_;
	my $Command = join(
		"", # без сепарации
		"convert \"", $Filename, "\"",
		" -blur ", $Blur_Radius, "x", $Blur_Power,
		" \"", $Filename, "\""
	);
	system($Command);
}

sub blur($Workdir_with__pictures, $Selected) {
	my @IMGs = imglist($Workdir_with__pictures);
	my @Files = map { catfile($Workdir_with__pictures, $_) } @IMGs;

	my	$len		= scalar(@Files);
	my	@a			= (1 .. $len);
	my	@Radius	= map {
		int	( $Algo{$Selected}-> (BLUR_RADIUS, $_, $len ))
	} @a;
	my	@Power	= map {
		round2( $Algo{$Selected}-> (BLUR_POWER	, $_, $len ))
	} @a;

	# список списков параметров для blur
	my @Blur_options = zip(\@Radius, \@Power, \@Files);
	mce_map { blur_image $_ } @Blur_options;
}

##################### END SECTION ###########################
sub to_video($Out, $Wdir) {
	qx | ffmpeg -loglevel ${\LOGLEVEL} -y -i "$Wdir/%d.${\IMGFMT}" -vf fps=${\FPS} -c:v ffv1 -pix_fmt yuva444p $Out |;
}

sub end($Outfile, $Workdir) { to_video($Outfile, $Workdir); }


__END__

=pod

=head1 NAME


blur.pl - make a progressing (according several hardcoded laws) video blurring.
B<Only linear blur in ready now.>

=head1 USAGE

blur.pl F<infile> blur_law F<outfile>

=head1 OPTIONS

=over 2

=item F<infile>

Any B<valid> and acceptable by your ffmpeg video file

=item blur_law

Blur algorithm. Only C<linear_in> and C<linear_out> implemented

=item F<ourfile>

Video stream encoded in ffv1 by your ffmpeg and packed to mkv

=back

=head1 CONGIGURATION

All configuration can be done in source file. Read C<man convert> for undestanding of blur raduis and power

=cut
