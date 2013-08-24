#/usr/bin/perl -w

use strict;

use Cwd 'realpath';
use File::Find;
use File::Basename;
use File::Path;
use File::Spec;
use FindBin qw($Bin);

my $usage = qq{
  Usage: refineTumorSegmentationResultsForCohort.pl <outputDirectory> <cohort>

 };

my ( $outputBaseDirectory, $cohort ) = @ARGV;

my $ANTSPATH = $ENV{ 'ANTSPATH' };
my $UTILPATH = $ENV{ 'UTILPATH' };

my $basedir = '/home/njt4n/share/Data/Tumor/BRATS/';
my $maskdir = "${basedir}/Masks/";

my @suffixList = ( ".mha", ".nii.gz" );

my @subjectdirs = <${outputBaseDirectory}/${cohort}*>;

for( my $i = 0; $i < @subjectdirs; $i++ )
  {
  print "****************************\n";
  print "$subjectdirs[$i]            \n";
  print "****************************\n";

  my @images = <${subjectdirs[$i]}/*NORMALIZED.nii.gz>;

  my ( $filename, $directories, $suffix ) = fileparse( $images[0], @suffixList );
  my $prefix = $filename;
  $prefix =~ s/_FLAIR_NORMALIZED//;

  my $outputSubjectDirectory = "${outputBaseDirectory}/${prefix}/";
  my $outputPrefix = "${outputSubjectDirectory}/${prefix}";
  if( ! -d $outputSubjectDirectory )
    {
    mkpath( $outputSubjectDirectory, {verbose => 0, mode => 0755} ) or
      die "Can't create output directory $outputSubjectDirectory\n\t";
    }

  my $mask = "${maskdir}/${prefix}_CEREBRUM_MASK.nii.gz";

  if( ! -e $mask )
    {
    print "The following file is missing:\n";
    print "  mask         -> $mask\n";
    next;
    }

  my $rfPosteriorsPrefix = "${outputPrefix}_RF_POSTERIORS";
  my @rfPosteriors = <${rfPosteriorsPrefix}*.nii.gz>;
  if( @rfPosteriors == 0 )
    {
    print "There are no RF posterior files.\n";
    next;
    }

  my $numberOfLabels = scalar( @rfPosteriors );

  my $necrosisLabel = 1 + 3;
  my $edemaLabel = 2 + 3;
  my $nonEnhancingLabel = 3 + 3;
  my $enhancingLabel = 4 + 3;

  if( $prefix =~ m/Sim/ )
    {
    $necrosisLabel = 2 + 3;
    $edemaLabel = 1 + 3;
    }

  my $commandFile = "${outputPrefix}RefineLabels.sh";

  open( FILE, ">${commandFile}" );
  print FILE "#!/bin/sh\n";
  print FILE "export ITK_GLOBAL_DEFAULT_NUMBER_OF_THREADS=1\n";

  my $flair = $images[0];
  my $t1 = $images[1];
  my $t1c = $images[2];
  my $t2 = $images[3];

  my @rfPosteriors = <${outputPrefix}_RF_POSTERIORS*.nii.gz>;


  my $mrfLabels = "${outputPrefix}_RF_LABELS.nii.gz";
  my $mrfCompleteTumor = "${outputPrefix}_RF_LABELS_COMPLETE_TUMOR.nii.gz";
  my $mrfTumorCore = "${outputPrefix}_RF_LABELS_TUMOR_CORE.nii.gz";
  my $mrfEnhancingTumor = "${outputPrefix}_RF_LABELS_ENHANCING_TUMOR.nii.gz";

  my $refinedCompleteTumor = "${outputPrefix}_REFINE_COMPLETE_TUMOR.nii.gz";
  my $refinedTumorCore = "${outputPrefix}_REFINE_TUMOR_CORE.nii.gz";
  my $refinedEnhancingTumor = "${outputPrefix}_REFINE_ENHANCING_TUMOR.nii.gz";
  my $refinedLabels = "${outputPrefix}_REFINE_RF_LABELS.nii.gz";

  ## Remove false positives using erosion and connected components.
  ## Also fill holes

  my $dilatedTumor = "${outputPrefix}_REFINE_DILATED_COMPLETE_TUMOR.nii.gz";

  my $maskEroded = $mask;
  $maskEroded =~ s/\.nii\.gz$/Eroded\.nii\.gz/;

  print FILE "${UTILPATH}BinaryMorphology 3 $mask $maskEroded 1  1 1 1\n\n";
  print FILE "${UTILPATH}MultipleOperateImages 3 seg $mrfLabels none @rfPosteriors\n\n";
  print FILE "${ANTSPATH}ThresholdImage 3 $mrfLabels $refinedCompleteTumor 4 7 1 0\n\n";
  print FILE "${UTILPATH}BinaryMorphology 3 $refinedCompleteTumor $dilatedTumor 1 3 1 1\n\n";
  print FILE "${UTILPATH}GetConnectedComponents 3 $dilatedTumor $dilatedTumor 0 0.1\n\n";
  print FILE "${ANTSPATH}ThresholdImage 3 $dilatedTumor $dilatedTumor 0 0 0 1\n\n";
  print FILE "${UTILPATH}FastMarching 3 $refinedCompleteTumor $refinedCompleteTumor $dilatedTumor 10000000 0\n\n";
  print FILE "${ANTSPATH}ThresholdImage 3 $refinedCompleteTumor $refinedCompleteTumor -1000 10000000 1 0\n\n";
  print FILE "${UTILPATH}BinaryMorphology 3 $refinedCompleteTumor $refinedCompleteTumor 5\n\n";
  print FILE "${UTILPATH}BinaryOperateImages 3 $refinedCompleteTumor x $mrfLabels $refinedLabels\n\n";

  print FILE "rm $dilatedTumor\n\n\n\n";

  ## We replace edema inside the tumor core with $necrosisLabel

  my $tmp1 = "${outputPrefix}_REFINE_TMP1.nii.gz";
  my $tmp2 = "${outputPrefix}_REFINE_TMP2.nii.gz";
  my $refinedTumorCoreFilled = "${outputPrefix}_REFINE_TUMOR_CORE_FILLED.nii.gz";

  print FILE "${UTILPATH}UnaryOperateImage 3 $refinedLabels r 0 $refinedTumorCore $edemaLabel 0\n\n";
  print FILE "${UTILPATH}UnaryOperateImage 3 $refinedTumorCore t 0 $refinedTumorCore 1 3 0\n\n";
  print FILE "${ANTSPATH}ThresholdImage 3 $refinedTumorCore $refinedTumorCore 0 0 0 1\n\n";

  # need to take care of connected components for tumor core (should only have one component)

  print FILE "${UTILPATH}GetConnectedComponents 3 $refinedTumorCore $tmp1 0 0.1\n\n";
  print FILE "${ANTSPATH}ThresholdImage 3 $refinedTumorCore $refinedTumorCore 0 0 0 1\n\n";
  print FILE "${ANTSPATH}ThresholdImage 3 $tmp1 $tmp1 0 0 0 1\n\n";
  print FILE "${UTILPATH}BinaryOperateImages 3 $refinedTumorCore - $tmp1 $tmp2\n\n";
  print FILE "cp $tmp1 $refinedTumorCore\n\n";
  print FILE "${ANTSPATH}ThresholdImage 3 $tmp2 $tmp1 0 0 1 0\n\n";
  print FILE "${UTILPATH}BinaryOperateImages 3 $tmp1 x $refinedLabels $refinedLabels\n\n";
  print FILE "${UTILPATH}UnaryOperateImage 3 $tmp2 x $edemaLabel $tmp2\n\n";
  print FILE "${UTILPATH}BinaryOperateImages 3 $refinedLabels max $tmp2 $refinedLabels\n\n";

   ##
  print FILE "${UTILPATH}BinaryMorphology 3 $refinedTumorCore $refinedTumorCoreFilled 6 2\n\n";
  print FILE "${UTILPATH}BinaryMorphology 3 $refinedTumorCoreFilled $refinedTumorCoreFilled 5\n\n";

  print FILE "${UTILPATH}BinaryOperateImages 3 $refinedTumorCoreFilled - $refinedTumorCore $tmp1\n\n";
  print FILE "cp $refinedTumorCoreFilled $refinedTumorCore\n\n";

  print FILE "${UTILPATH}UnaryOperateImage 3 $tmp1 x $necrosisLabel $tmp1\n\n";
  print FILE "${UTILPATH}BinaryOperateImages 3 $refinedLabels replace $tmp1 $refinedLabels\n\n";

  print FILE "rm $tmp1\n";
  print FILE "rm $tmp2\n";
  print FILE "rm $refinedTumorCoreFilled\n\n\n\n";

  ## Create different regions

  print FILE "${ANTSPATH}ThresholdImage 3 $refinedLabels $refinedCompleteTumor $necrosisLabel $enhancingLabel 1 0\n\n";
  if( $prefix !~ m/Sim/ )
    {
    print FILE "${ANTSPATH}ThresholdImage 3 $refinedLabels $refinedEnhancingTumor $enhancingLabel $enhancingLabel 1 0\n\n";
    }

  print FILE "${UTILPATH}BinaryOperateImages 3 $maskEroded x $refinedLabels $refinedLabels\n\n";
  print FILE "${UTILPATH}BinaryOperateImages 3 $maskEroded x $refinedTumorCore $refinedTumorCore\n\n";
  print FILE "${UTILPATH}BinaryOperateImages 3 $maskEroded x $refinedEnhancingTumor $refinedEnhancingTumor\n\n";
  print FILE "${UTILPATH}BinaryOperateImages 3 $maskEroded x $refinedCompleteTumor $refinedCompleteTumor\n\n";

  print FILE "rm $maskEroded\n\n";

  close( FILE );

#   if( ! -e $refinedEnhancingTumor )
#     {
    print "** refinement ${filename}\n";
    my @qargs = ( 'qsub',
                  '-N', "${prefix}",
                  '-v', "ANTSPATH=$ANTSPATH",
                  '-v', "UTILPATH=$UTILPATH",
                  '-q', 'standard',
                  '-l', 'mem=4gb',
                  '-l', 'nodes=1:ppn=1',
                  '-l', 'walltime=01:00:00',
                  $commandFile );
    system( @qargs ) == 0 || die "qsub\n";
#     }
#   else
#     {
#     print " refinement ${filename}\n";
#     }
  }

