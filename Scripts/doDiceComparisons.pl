#/usr/bin/perl -w

use strict;

use Cwd 'realpath';
use File::Find;
use File::Basename;
use File::Path;
use File::Spec;
use FindBin qw($Bin);

my $usage = qq{
  Usage: refineSingleSubject.pl <which>

 };

my ( $which ) = @ARGV;

my $basedir = '/Users/ntustison/Data/Public/BRATS-2/';
my $maskdir = "${basedir}/Masks/";
my $imagesdir = "${basedir}/Images/";
my $posteriorsdir = "${basedir}/Posteriors2/MAP_MRF_RF_POSTERIORS/";
my $truthdir = "${basedir}/TruthLabels2/";
my $refinedir1 = "${basedir}/Refinement/";               # -w 0, -n 1 -m 5


my $ANTSPATH = $ENV{ 'ANTSPATH' };
my $UTILPATH = $ENV{ 'UTILPATH' };

my @subjectdirs = <${imagesdir}/${which}*>;

my $outputFile = "${basedir}/refined_results.csv";
open( FILE, ">${outputFile}" );

print FILE "SubjectID,WHICH,CompleteTumor,TumorCore,EnhancingTumor\n";

for( my $i = 0; $i < @subjectdirs; $i++ )
  {
  print "****************************\n";
  print "$subjectdirs[$i]            \n";
  print "****************************\n";

  my @images = <${subjectdirs[$i]}/*.nii.gz>;

  my ( $filename, $directories, $suffix ) = fileparse( $images[0], ".nii.gz" );
  my $prefix = $filename;
  $prefix =~ s/_FLAIR//;

  my $flair = $images[0];
  my $t1 = $images[1];
  my $t1c = $images[2];
  my $t2 = $images[3];

  my $trueLabels = "${truthdir}/${prefix}_atropos_truth.nii.gz";
  my $trueCompleteTumor = "${truthdir}/${prefix}_COMPLETE_TUMOR.nii.gz";
  my $trueTumorCore = "${truthdir}/${prefix}_TUMOR_CORE.nii.gz";
  my $trueEnhancingTumor = "${truthdir}/${prefix}_ENHANCING_TUMOR.nii.gz";

  if( $prefix !~ m/Sim/ )
    {
#     `ThresholdImage 3 $trueLabels $trueCompleteTumor 4 7 1 0`;
#     `ThresholdImage 3 $trueLabels $trueEnhancingTumor 7 7 1 0`;
#     `UnaryOperateImage 3 $trueLabels t 0 $trueTumorCore 1 3 0`;
#     `UnaryOperateImage 3 $trueTumorCore r 0 $trueTumorCore 5 0`;
#     `ThresholdImage 3 $trueTumorCore $trueTumorCore 0 0 0 1`;
    }
  else
    {
    `ThresholdImage 3 $trueLabels $trueCompleteTumor 4 5 1 0`;
    `UnaryOperateImage 3 $trueLabels t 0 $trueTumorCore 1 3 0`;
    `UnaryOperateImage 3 $trueTumorCore r 0 $trueTumorCore 4 0`;
    `ThresholdImage 3 $trueTumorCore $trueTumorCore 0 0 0 1`;
    }

  my $refinedCompleteTumor1 = "${refinedir1}/${prefix}_REFINE_COMPLETE_TUMOR.nii.gz";
  my $refinedTumorCore1 = "${refinedir1}/${prefix}_REFINE_TUMOR_CORE.nii.gz";
  my $refinedEnhancingTumor1 = "${refinedir1}/${prefix}_REFINE_ENHANCING_TUMOR.nii.gz";
  my $refinedLabels1 = "${refinedir1}/${prefix}_REFINE_RF_LABELS.nii.gz";

#   my $refinedCompleteTumor2 = "${refinedir2}/${prefix}_REFINE_COMPLETE_TUMOR.nii.gz";
#   my $refinedTumorCore2 = "${refinedir2}/${prefix}_REFINE_TUMOR_CORE.nii.gz";
#   my $refinedEnhancingTumor2 = "${refinedir2}/${prefix}_REFINE_ENHANCING_TUMOR.nii.gz";
#   my $refinedLabels2 = "${refinedir2}/${prefix}_REFINE_RF_LABELS.nii.gz";

  ## compare
  my @refinedMeasuresCompleteTumor1 = `LabelOverlapMeasures 3 $refinedCompleteTumor1 $trueCompleteTumor`;
  my @refinedMeasuresTumorCore1 = `LabelOverlapMeasures 3 $refinedTumorCore1 $trueTumorCore`;
  my @refinedStatsCompleteTumor1 = split( ' ', $refinedMeasuresCompleteTumor1[2] );
  my @refinedStatsTumorCore1 = split( ' ', $refinedMeasuresTumorCore1[2] );

  my $refinedDiceEnhancingTumor1 = 'NA';
  if( $prefix !~ m/Sim/ )
    {
    my @refinedMeasuresEnhancingTumor1 = `LabelOverlapMeasures 3 $refinedEnhancingTumor1 $trueEnhancingTumor`;
    my @refinedStatsEnhancingTumor1 = split( ' ', $refinedMeasuresEnhancingTumor1[2] );
    $refinedDiceEnhancingTumor1 = $refinedStatsEnhancingTumor1[2];
    }
  print FILE "${prefix},1,${refinedStatsCompleteTumor1[2]},${refinedStatsTumorCore1[2]},${refinedDiceEnhancingTumor1}\n";

#   my @refinedMeasuresCompleteTumor2 = `LabelOverlapMeasures 3 $refinedCompleteTumor2 $trueCompleteTumor`;
#   my @refinedMeasuresTumorCore2 = `LabelOverlapMeasures 3 $refinedTumorCore2 $trueTumorCore`;
#   my @refinedStatsCompleteTumor2 = split( ' ', $refinedMeasuresCompleteTumor2[2] );
#   my @refinedStatsTumorCore2 = split( ' ', $refinedMeasuresTumorCore2[2] );
#
#   my $refinedDiceEnhancingTumor2 = 'NA';
#   if( $prefix !~ m/Sim/ )
#     {
#     my @refinedMeasuresEnhancingTumor2 = `LabelOverlapMeasures 3 $refinedEnhancingTumor2 $trueEnhancingTumor`;
#     my @refinedStatsEnhancingTumor2 = split( ' ', $refinedMeasuresEnhancingTumor2[2] );
#     $refinedDiceEnhancingTumor2 = $refinedStatsEnhancingTumor2[2];
#     }
#   print FILE "${prefix},2,${refinedStatsCompleteTumor2[2]},${refinedStatsTumorCore2[2]},${refinedDiceEnhancingTumor2}\n";
  }
close( FILE );
