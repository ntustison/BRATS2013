#/usr/bin/perl -w

use strict;

use Cwd 'realpath';
use File::Find;
use File::Basename;
use File::Path;
use File::Spec;
use FindBin qw($Bin);

my $usage = qq{
  Usage: createRandomForestModel.pl <cohortFeatureImageDirectoryList.txt> <outputPrefix>

  Create a single random forest model from the list of image feature
  directories.

 };

my ( $subjectListFile, $outputPrefix, $numberOfUniqueLabels ) = @ARGV;

my $ANTSPATH = $ENV{ 'ANTSPATH' };
my $UTILPATH = $ENV{ 'UTILPATH' };

my $basedir = '/home/njt4n/share/Data/Tumor/BRATS/';
my $maskdir = "${basedir}/Masks/";
my $truthdir = "${basedir}/TruthLabels2/";
my $templatedir = '/home/njt4n/share/Data/Public/Kirby/SymmetricTemplate/';
my $templateLabels = "${templatedir}/S_templateJointLabels_6labels.nii.gz";

my @suffixList = ( ".mha", ".nii.gz" );

open( FILE, "<${subjectListFile}" );
my @subjectdirs = <FILE>;
close( FILE );

###
##
## Create CSV feature image file for model
##
###

my $outputModelCSVFile = "${outputPrefix}FeatureImageList.csv";
my $outputModelPrefix = "${outputPrefix}";
my ( $title, $garbage1, $garbage2 ) = fileparse( ${outputPrefix}, @suffixList );

open( FILE, ">${outputModelCSVFile}" );
for( my $i = 0; $i < @subjectdirs; $i++ )
  {
  chomp( ${subjectdirs[$i]} );
  my @images = <${subjectdirs[$i]}/*NORMALIZED.nii.gz>;

  my ( $filename, $directories, $suffix ) = fileparse( $images[0], @suffixList );
  my $prefix = $filename;
  $prefix =~ s/_FLAIR_NORMALIZED//;

  my $mask = "${maskdir}/${prefix}_CEREBRUM_MASK.nii.gz";
  my $truth = "${truthdir}/${prefix}_atropos_truth_masked.nii.gz";
#   if( $prefix =~ m/Sim/ )
#     {
#     $truth = "${truthdir}/${prefix}_complete_truth.nii.gz";
#     }

  if( ! -e $mask || ! -e $truth )
    {
    die "The mask or truth labels do not exist.\n  mask -> $mask\n  truth -> $truth\n";
    }

  my @gmmImages = <${subjectdirs[$i]}/*GMM_*nii.gz>;
  my @mrfImages = <${subjectdirs[$i]}/*MAP_MRF_*nii.gz>;
  my @statsImages = <${subjectdirs[$i]}/*RADIUS*nii.gz>;
  my @jacobianImages = <${subjectdirs[$i]}/*JACOBIAN*nii.gz>;
  my @differenceImages = <${subjectdirs[$i]}/*DIFFERENCE*nii.gz>;
#   my @t1_t1c_differenceImages = <${subjectdirs[$i]}/*T1_T1C_DIFFERENCE.nii.gz>;
  my @distanceImages = <${subjectdirs[$i]}/*NORMALIZED_DISTANCE*nii.gz>;
  my @fractalImages = <${subjectdirs[$i]}/*FRACTAL*nii.gz>;

  my @featureImages = ( $truth, $mask, @statsImages, @jacobianImages, @differenceImages, @distanceImages, @fractalImages );

  if( @mrfImages == 0 )
    {
    push( @featureImages, @gmmImages );
    if( $i == 0 )
      {
      $outputModelPrefix .= "GMM";
      }
    }
  else
    {
    push( @featureImages, @mrfImages );
    if( $i == 0 )
      {
      $outputModelPrefix .= "MAP_MRF";
      }
    }
#   @featureImages = grep ! /\_T1\_/, @featureImages;
#   @featureImages = ( @featureImages, @t1_t1c_differenceImages );

  my $featureImagesString = join( ',', @featureImages );

  if( $i == 0 )
    {
    my @featureImagesTypes = ( 'TRUTH_LABELS', 'MASK' );

    for( my $j = 2; $j < @featureImages; $j++ )
      {
      my ( $type, $directories, $suffix ) = fileparse( $featureImages[$j], @suffixList );
      $type =~ s/${prefix}\_//;
      push( @featureImagesTypes, $type );
      }
    my $featureImagesTypesString = join( ',', @featureImagesTypes );
    print FILE "$featureImagesTypesString\n";
    }
  print FILE "$featureImagesString\n";
  }
close( FILE );

my $commandFile = "${outputPrefix}RandomForestCommand.sh";

open( FILE, ">${commandFile}" );
print FILE "#!/bin/sh\n";
print FILE "export ITK_GLOBAL_DEFAULT_NUMBER_OF_THREADS=1\n";

print FILE "export LD_LIBRARY_PATH=";
print FILE "\"/home/njt4n/share/Pkg/R/library/Rcpp/lib:";
print FILE "/home/njt4n/share/Pkg/ANTsR/src/ANTS/ANTS-build/lib:";
print FILE "\$LD_LIBRARY_PATH\"\n";
print FILE "\n";

##
##  The following combinations work on the cluster for numberOfThreads = 1
##    (numberOfTreesPerThread/numberOfSamplesPerLabel/requestedMemory):
##    * BRATS_LG & BRATS_HG (2000/2500/64gb)
##    * SimBRATS_LG & SimBRATS_HG (2000/500/64gb)
##


my @args = ( '/usr/bin/Rscript',
             "${UTILPATH}/../scripts/createModel.R",
             $outputModelCSVFile,
             $outputModelPrefix,
             1,  # number of threads
             1,  # training portion
             2000,   # number of trees per thread
             500,    # number of samples per label
             $numberOfUniqueLabels          # how many classes?
             );
print FILE "@args\n";

@args =    ( '/usr/bin/Rscript',
             "${UTILPATH}/../scripts/plotVariableImportance.R",
             "${outputModelPrefix}.RData",
             "${outputModelPrefix}.pdf",
             $title
           );
print FILE "if [[ -e ${outputModelPrefix}.RData ]]; then\n";
print FILE "@args\n";
print FILE "fi\n";
close( FILE );


if( ! -e "${outputModelPrefix}.RData" )
  {
  print "** model creation ${outputModelPrefix}.RData \n";
  my @qargs = ( 'qsub',
                '-N', 'RF',
                '-v', "ANTSPATH=$ANTSPATH",
                '-v', "UTILPATH=$UTILPATH",
                '-q', 'standard',
                '-l', 'mem=64gb',
                '-l', 'nodes=1:ppn=1',
                '-l', 'walltime=15:00:00',
                $commandFile );
  system( @qargs ) == 0 || die "qsub\n";
  }
