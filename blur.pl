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
use constant FPS => 30;
use constant LOGLEVEL => "quiet"; # "quiet" or "warning" or "debug"

use strict;
use warnings;
use autodie;
use utf8;
use feature qw(switch signatures say);

no warnings "experimental::signatures";
no warnings "experimental::smartmatch";

use File::Temp qw/tempdir cleanup tempfile/;
use Cwd qw/cwd/;
use List::Util qw/zip/;
use File::Spec::Functions;
use MCE::Map;
use Filesys::Df


my %Algo = (
	linear_in => 1,
	linear_out =>1,
);

# Utility funcs
sub is_correct ($Infile) { 1; }
sub pnglist($Dir) {
	opendir(my $DH, $Dir);
	my @Files = sort grep(/png/, readdir($DH));
	closedir $DH;
	return @Files;
}
sub round2 { my $Num = shift; return (int($Num*100)/100); }

sub is_space_enough(my $File) {
	my $Frames =
		qx(ffprobe -v error -select_streams v:0 -count_packets -show_entries stream=nb_read_packets -of csv=p=0 $File);
	my ($Fh, $Temp) = tempfile();
	close $Fh;
	my $Out = $Temp . ".ppm";
	qx(ffmpeg -v 0 -ss 00:01 -i $File -vframes 1 -q:v 2 $Out);
	my $Size = -s $Out;
	my $Required = $Size * $Frames;
	my $Tmp_free_space = df($Out , 1)->{"bavail"};
	my $CWD_free_space = df($File, 1)->{"bavail"};
	unlink $Out;
	my $Is_ok = ($Required < $Tmp_free_space)
					 or ($Required < $CWD_free_space);
	return $Is_ok
}

sub help_msg_algo {
	say "USAGE: blur.pl input_video_file blur_algorithm outputvideo.mkv";
	say "Implemented blur algorithms: linear_in, linear_out"
	say "See perldoc blur.pl for details"
}

sub cli () {
	my ($In, $Command, $Out) = @_;

	if not ( (scalar @_) == 3) {
		help_msg();
		die "Wrong args\n";
	}
	if not (-e -r $In) {
		help_msg();
		die "Input file don't exist or unreadable\n"
	}

	help_msg() if not $Algo{$Command};

	die "Destination directory unwritable\n" unless (-w cwd());
	warn "Output file exist\n" if (-e $Out);
	die "No free space\n" unless is_space_enough($In);
	return ($In, $Command, $Out);
}

# PREPARE STAGE -> prepare (my $Infile, my $Workdir)
sub v2i ($In, $Wdir) { # V_ideo TO I_mage
	my $Command = join(
		"", # соединитель
		"ffmpeg", " -loglevel ", LOGLEVEL,
		" -i ", $In,
		" -vf fps=", FPS,
		" \"", $Wdir, "/", "%7d.png\"");
	system($Command);
};

sub prepare ($Infile, $Workdir)	{
	v2i($Infile, $Workdir) if is_correct($Infile);
}
####################################################

# BLUR -> blur($Workdir, $Algo)
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

sub blur_in_linear($Workdir_with__pictures) {
	my @PNGs = pnglist($Workdir_with__pictures);
	my @Files = map { catfile($Workdir_with__pictures, $_) } @PNGs;

	# y = kx + b, b=0
	my	$len		= scalar(@Files);
	my	@a			= (1 .. $len);
	my	@Radius	= map { int		( BLUR_RADIUS * ( $_ / $len ))	} @a;
	my	@Power	= map { round2(	BLUR_POWER	* ( $_ / $len ))	} @a;

	# список списков параметров для blur
	my @Blur_options = zip(\@Radius, \@Power, \@Files);
	mce_map { blur_image $_ } @Blur_options;
}

sub blur_linear_out($Workdir_with__pictures) {
	my @PNGs = pnglist($Workdir_with__pictures);
	my @Files = map { catfile($Workdir_with__pictures, $_) } @PNGs;

	# y = - kx + b, b=0
	my	$len		= scalar(@Files);
	my	@a			= (1 .. $len);
	my	@Radius	= map { int		( BLUR_RADIUS	* ( 1 - $_ / $len )) } @a;
	my	@Power	= map { round2	( BLUR_POWER	* ( 1 - $_ / $len )) } @a;

	# список списков параметров для blur
	my @Blur_options = zip(\@Radius, \@Power, \@Files);
	mce_map { blur_image $_ } @Blur_options;
}

sub blur{ # $Workdir, $Algo
	my ($Workdir, $Algo) = @_;
	given ($Algo) {
		blur_in_linear($Workdir) when ("linear_in");
		default { return 0 }
	}
}
####################################################

# END STAGE -> end($Outfile, $Workdir)
sub i2v($Out, $Wdir) { # I_mages TO V_ideo
	my $Command = join(
		"", # соединитель
		"ffmpeg", " -loglevel ", LOGLEVEL,
		" -y -i \"", $Wdir, "/", "%7d.png\"",
		" -vf fps=", FPS,
		" -c:v ffv1 -pix_fmt yuva444p ",
		$Out);
	system($Command);
}

sub end($Outfile, $Workdir) { i2v($Outfile, $Workdir); }
#####################################################

{
	my $Infile = shift;
	my $Algo = shift;
	my $Outfile = shift;
	my $Workdir	= tempdir(DIR => cwd(), CLEANUP => 1);

	prepare($Infile, $Workdir);
	blur($Workdir, $Algo);
	end($Outfile, $Workdir);
}

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
