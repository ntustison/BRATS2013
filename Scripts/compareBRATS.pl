#! /usr/bin/perl -w

use File::Spec;
use File::Find;
use File::Basename;
use File::Path;

my ( $type ) = @ARGV;

my $brats1dir = '/Users/ntustison/Data/Public/BRATS-1/';
my $brats2dir = '/Users/ntustison/Data/Public/BRATS-2/';

my @brats1 = <${brats1dir}/Images/*//*${type}.nii.gz>;
my @brats2 = <${brats2dir}/Images/*//*${type}.nii.gz>;

for( my $j = 0; $j < @brats1; $j++ )
  {
  print "/Applications/ITK-SNAP.app/Contents/MacOS/InsightSNAP -g $brats1[$j] -o $brats2[$j]\n";
  }



