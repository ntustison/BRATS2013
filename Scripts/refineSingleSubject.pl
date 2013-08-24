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
my $posteriorsdir = "${basedir}/Posteriors/";
my $truthdir = "${basedir}/TruthLabels2/";
my $refinedir1 = "${basedir}/";
my $refinedir2 = "${basedir}/Refinement/";


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

  my $mask = "${maskdir}/${prefix}_CEREBRUM_MASK.nii.gz";

  if( ! -e $mask )
    {
    print "The following file is missing:\n";
    print "  mask         -> $mask\n";
    next;
    }

  my $flair = $images[0];
  my $t1 = $images[1];
  my $t1c = $images[2];
  my $t2 = $images[3];

  my $mrfLabels = "${posteriorsdir}/${prefix}_RF_LABELS.nii.gz";
  my @rfPosteriors = <${posteriorsdir}/${prefix}_RF_POSTERIORS*.nii.gz>;
  my $mrfCompleteTumor = "${posteriorsdir}/${prefix}_RF_LABELS_COMPLETE_TUMOR.nii.gz";
  my $mrfTumorCore = "${posteriorsdir}/${prefix}_RF_LABELS_TUMOR_CORE.nii.gz";
  my $mrfEnhancingTumor = "${posteriorsdir}/${prefix}_RF_LABELS_ENHANCING_TUMOR.nii.gz";

  my $trueLabels = "${truthdir}/${prefix}_atropos_truth.nii.gz";
  my $trueCompleteTumor = "${truthdir}/${prefix}_COMPLETE_TUMOR.nii.gz";
  my $trueTumorCore = "${truthdir}/${prefix}_TUMOR_CORE.nii.gz";
  my $trueEnhancingTumor = "${truthdir}/${prefix}_ENHANCING_TUMOR.nii.gz";

  `ThresholdImage 3 $trueLabels $trueCompleteTumor 4 7 1 0`;
  `ThresholdImage 3 $trueLabels $trueEnhancingTumor 7 7 1 0`;
  `UnaryOperateImage 3 $trueLabels t 0 $trueTumorCore 1 3 0`;
  `UnaryOperateImage 3 $trueTumorCore r 0 $trueTumorCore 5 0`;
  `ThresholdImage 3 $trueTumorCore $trueTumorCore 0 0 0 1`;

  my $necrosisLabel = 1 + 3;
  my $edemaLabel = 2 + 3;
  my $nonEnhancingLabel = 3 + 3;
  my $enhancingLabel = 4 + 3;

  if( $prefix =~ m/Sim/ )
    {
    $necrosisLabel = 2 + 3;
    $edemaLabel = 1 + 3;
    }


  my $refinedCompleteTumor = "${refinedir1}/${prefix}_REFINE_COMPLETE_TUMOR.nii.gz";
  my $refinedTumorCore = "${refinedir1}/${prefix}_REFINE_TUMOR_CORE.nii.gz";
  my $refinedEnhancingTumor = "${refinedir1}/${prefix}_REFINE_ENHANCING_TUMOR.nii.gz";
  my $refinedLabels = "${refinedir1}/${prefix}_REFINE_RF_LABELS.nii.gz";

  my $outputPrefix = "${refinedir1}/${prefix}";

  my $dilatedTumor = "${outputPrefix}_REFINE_DILATED_COMPLETE_TUMOR.nii.gz";

#   `MultipleOperateImages 3 seg $mrfLabels none @rfPosteriors`;
  `ThresholdImage 3 $mrfLabels $refinedCompleteTumor 4 7 1 0`;
  `BinaryMorphology 3 $refinedCompleteTumor $dilatedTumor 1 3 1 1`;
  `GetConnectedComponents 3 $dilatedTumor $dilatedTumor 0 0.1`;
  `ThresholdImage 3 $dilatedTumor $dilatedTumor 0 0 0 1`;
  `FastMarching 3 $refinedCompleteTumor $refinedCompleteTumor $dilatedTumor 10000000 0`;
  `ThresholdImage 3 $refinedCompleteTumor $refinedCompleteTumor -1000 10000000 1 0`;
  `BinaryMorphology 3 $refinedCompleteTumor $refinedCompleteTumor 5`;
  `BinaryOperateImages 3 $refinedCompleteTumor x $mrfLabels $refinedLabels`;

  unlink( $dilatedTumor );

  ## We replace edema inside the tumor core with $necrosisLabel

  my $tmp1 = "${outputPrefix}_REFINE_TMP1.nii.gz";
  my $tmp2 = "${outputPrefix}_REFINE_TMP2.nii.gz";
  my $refinedTumorCoreFilled = "${outputPrefix}_REFINE_TUMOR_CORE_FILLED.nii.gz";
  my $refinedTumorCoreFilled = "${outputPrefix}_REFINE_TUMOR_CORE_FILLED.nii.gz";

  `UnaryOperateImage 3 $refinedLabels r 0 $refinedTumorCore $edemaLabel 0`;
  `UnaryOperateImage 3 $refinedTumorCore t 0 $refinedTumorCore 1 3 0`;
  `ThresholdImage 3 $refinedTumorCore $refinedTumorCore 0 0 0 1`;

  # need to take care of connected components for tumor core (should only have one component)

  `GetConnectedComponents 3 $refinedTumorCore $tmp1 0 0.1`;
  `ThresholdImage 3 $refinedTumorCore $refinedTumorCore 0 0 0 1`;
  `ThresholdImage 3 $tmp1 $tmp1 0 0 0 1`;
  `BinaryOperateImages 3 $refinedTumorCore - $tmp1 $tmp2`;
  `cp $tmp1 $refinedTumorCore`;
  `ThresholdImage 3 $tmp2 $tmp1 0 0 1 0`;
  `BinaryOperateImages 3 $tmp1 x $refinedLabels $refinedLabels`;
  `UnaryOperateImage 3 $tmp2 x $edemaLabel $tmp2`;
  `BinaryOperateImages 3 $refinedLabels max $tmp2 $refinedLabels`;

   ##
  `BinaryMorphology 3 $refinedTumorCore $refinedTumorCoreFilled 6 2`;
  `BinaryMorphology 3 $refinedTumorCoreFilled $refinedTumorCoreFilled 5`;

  `BinaryOperateImages 3 $refinedTumorCoreFilled - $refinedTumorCore $tmp1`;
  `cp $refinedTumorCoreFilled $refinedTumorCore`;

  `UnaryOperateImage 3 $tmp1 x $necrosisLabel $tmp1`;
  `BinaryOperateImages 3 $refinedLabels replace $tmp1 $refinedLabels`;

  unlink( $tmp1 );
  unlink( $tmp2 );
  unlink( $refinedTumorCoreFilled );

  ## Create different regions

  `ThresholdImage 3 $refinedLabels $refinedCompleteTumor $necrosisLabel $enhancingLabel 1 0`;
  if( $prefix !~ m/Sim/ )
    {
    `ThresholdImage 3 $refinedLabels $refinedEnhancingTumor $enhancingLabel $enhancingLabel 1 0`;
    }

  ## compare

  $mrfCompleteTumor = "${refinedir2}/${prefix}_REFINE_COMPLETE_TUMOR.nii.gz";
  $mrfTumorCore = "${refinedir2}/${prefix}_REFINE_TUMOR_CORE.nii.gz";
  $mrfEnhancingTumor = "${refinedir2}/${prefix}_REFINE_ENHANCING_TUMOR.nii.gz";
  $mrfLabels = "${refinedir2}/${prefix}_REFINE_RF_LABELS.nii.gz";

  my @mrfMeasuresLabels = `LabelOverlapMeasures 3 $mrfLabels $trueLabels`;
  my @mrfMeasuresCompleteTumor = `LabelOverlapMeasures 3 $mrfCompleteTumor $trueCompleteTumor`;
  my @mrfMeasuresTumorCore = `LabelOverlapMeasures 3 $mrfTumorCore $trueTumorCore`;
  my @mrfStatsLabels = split( ' ', $mrfMeasuresLabels[2] );
  my @mrfStatsCompleteTumor = split( ' ', $mrfMeasuresCompleteTumor[2] );
  my @mrfStatsTumorCore = split( ' ', $mrfMeasuresTumorCore[2] );

  my $mrfDiceEnhancingTumor = 'NA';
  if( $prefix !~ m/Sim/ )
    {
    my @mrfMeasuresEnhancingTumor = `LabelOverlapMeasures 3 $mrfEnhancingTumor $trueEnhancingTumor`;
    my @mrfStatsEnhancingTumor = split( ' ', $mrfMeasuresEnhancingTumor[2] );
    $mrfDiceEnhancingTumor = $mrfStatsEnhancingTumor[2];
    }
  print FILE "${prefix},1,${mrfStatsCompleteTumor[2]},${mrfStatsTumorCore[2]},${mrfDiceEnhancingTumor}\n";

  my @refinedMeasuresLabels = `LabelOverlapMeasures 3 $refinedLabels $trueLabels`;
  my @refinedMeasuresCompleteTumor = `LabelOverlapMeasures 3 $refinedCompleteTumor $trueCompleteTumor`;
  my @refinedMeasuresTumorCore = `LabelOverlapMeasures 3 $refinedTumorCore $trueTumorCore`;
  my @refinedStatsLabels = split( ' ', $refinedMeasuresLabels[2] );
  my @refinedStatsCompleteTumor = split( ' ', $refinedMeasuresCompleteTumor[2] );
  my @refinedStatsTumorCore = split( ' ', $refinedMeasuresTumorCore[2] );

  my $refinedDiceEnhancingTumor = 'NA';
  if( $prefix !~ m/Sim/ )
    {
    my @refinedMeasuresEnhancingTumor = `LabelOverlapMeasures 3 $refinedEnhancingTumor $trueEnhancingTumor`;
    my @refinedStatsEnhancingTumor = split( ' ', $refinedMeasuresEnhancingTumor[2] );
    $refinedDiceEnhancingTumor = $refinedStatsEnhancingTumor[2];
    }
  print FILE "${prefix},A,${refinedStatsCompleteTumor[2]},${refinedStatsTumorCore[2]},${refinedDiceEnhancingTumor}\n";
  }
close( FILE );
