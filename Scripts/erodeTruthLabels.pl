#/usr/bin/perl -w

use strict;

use Cwd 'realpath';
use File::Find;
use File::Basename;
use File::Path;
use File::Spec;
use FindBin qw($Bin);

my $usage = qq{
  Usage: erodeTruthLabels.pl <which>

 };

my ( $which ) = @ARGV;

my $basedir = '/Users/ntustison/Data/Public/BRATS-2/';
my $maskdir = "${basedir}/Masks/";
my $imagesdir = "${basedir}/Images/";
my $posteriorsdir = "${basedir}/Posteriors2/MAP_MRF_RF_POSTERIORS/";
my $truthdir = "${basedir}/TruthLabels2/";
my $refinedir1 = "${basedir}/Refinement/";               # -w 0, -n 1 -m 5
my $refinedir2 = "${basedir}/RefinementB/";


my $ANTSPATH = $ENV{ 'ANTSPATH' };
my $UTILPATH = $ENV{ 'UTILPATH' };

my @truthLabels = <${truthdir}/${which}*atropos_truth.nii.gz>;

for( my $i = 0; $i < @truthLabels; $i++ )
  {
  print "****************************\n";
  print "$truthLabels[$i]            \n";
  print "****************************\n";

  my $trueLabels = $truthLabels[$i];

  my ( $filename, $directories, $suffix ) = fileparse( $trueLabels, ".nii.gz" );
  my $prefix = $filename;
  $prefix =~ s/_atropos_truth//;

  my $trueLabelsEroded = "${directories}/${prefix}_atropos_truth_eroded.nii.gz";

  `BinaryMorphology 3 $trueLabels $trueLabelsEroded 1 1 1 1`;
  `BinaryMorphology 3 $trueLabelsEroded $trueLabelsEroded 1 1 1 2`;
  `BinaryMorphology 3 $trueLabelsEroded $trueLabelsEroded 1 1 1 3`;
  `BinaryMorphology 3 $trueLabelsEroded $trueLabelsEroded 1 1 1 4`;
  `BinaryMorphology 3 $trueLabelsEroded $trueLabelsEroded 1 1 1 5`;
  `BinaryMorphology 3 $trueLabelsEroded $trueLabelsEroded 1 1 1 7`;
  }
