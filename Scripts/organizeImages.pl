#! /usr/bin/perl -w

use File::Spec;
use File::Find;
use File::Basename;
use File::Path;

my ( $prefix ) = @ARGV;

my $basedir = '/Users/ntustison/Data/Public/BRATS-2/';
my $truthdir = "${basedir}/TruthLabels/";
my $imagedir = "${basedir}/Images/";

my @suffixList = ( ".mha", ".nii.gz" );

@hgdirs = <${basedir}/Image_Data/HG/*>;
@lgdirs = <${basedir}/Image_Data/LG/*>;
@simhgdirs = <${basedir}/Synthetic_Data/HG/*>;
@simlgdirs = <${basedir}/Synthetic_Data/LG/*>;

my @subjectdirs = ( @hgdirs, @lgdirs, @simhgdirs, @simlgdirs );

for( my $i = 0; $i < @subjectdirs; $i++ )
  {

  my @images = <${subjectdirs[$i]}/VSD*//*.mha>;

  if( @images < 5 )
    {
    next;
    }

  print "****************************\n";
  print "$subjectdirs[$i]            \n";
  print "****************************\n";

  my @comps = split( '/', $subjectdirs[$i] );

  my $type = '';
  my $grade = $comps[-2];

  if( @images > 5 )
    {
    $type = "Sim";
    }

  my @imageTypes = ( 'FLAIR', 'T1', 'T1C', 'T2' );

  my $outputImageDir = "${imagedir}/${type}BRATS_${grade}${comps[-1]}/";
  my $outputPrefix = "${outputImageDir}/${type}BRATS_${grade}${comps[-1]}";

  if( ! -e $outputImageDir )
    {
    mkpath( $outputImageDir );
    }

  for( my $j = 0; $j < @imageTypes; $j++ )
    {
    `ConvertImage 3 $images[$j] ${outputPrefix}_${imageTypes[$j]}.nii.gz 0`;
    }

  `ConvertImage 3 $images[4] ${truthdir}/${type}BRATS_${grade}${comps[-1]}_truth.nii.gz 1`;
  if( @images > 5 )
    {
    `ConvertImage 3 $images[5] ${truthdir}/${type}BRATS_${grade}${comps[-1]}_complete_truth.nii.gz 1`;
    }
  }

