#/usr/bin/perl -w

use strict;

use Cwd 'realpath';
use File::Find;
use File::Basename;
use File::Path;
use File::Spec;
use FindBin qw($Bin);

my $usage = qq{
  Usage: applyTumorSegmentationModelForCohort.pl <outputDirectory> <cohort> <which=GMM or MRF>

  Create a single random forest model from the list of image feature
  directories.

 };

my ( $outputBaseDirectory, $cohort, $which ) = @ARGV;

my $ANTSPATH = $ENV{ 'ANTSPATH' };
my $UTILPATH = $ENV{ 'UTILPATH' };

my $basedir = '/home/njt4n/share/Data/Tumor/BRATS/';
my $maskdir = "${basedir}/Masks/";
my $templatedir = '/home/njt4n/share/Data/Public/Kirby/SymmetricTemplate/';
my $templateLabels = "${templatedir}/S_templateJointLabels_6labels.nii.gz";

my @templates = ();
$templates[0] = "${templatedir}/S_template2_RESCALED.nii.gz";          #FLAIR
$templates[1] = "${templatedir}/S_template3_RESCALED.nii.gz";          #T1
$templates[2] = "${templatedir}/S_template3_RESCALED.nii.gz";          #T1
$templates[3] = "${templatedir}/S_template5_RESCALED.nii.gz";          #T2

my @suffixList = ( ".mha", ".nii.gz" );

my @subjectdirs = <${outputBaseDirectory}/${cohort}*>;

###
##
## Check csv files
##
###

my @clusterCenterFiles = ();
for( my $i = 0; $i < @subjectdirs; $i++ )
  {
  print "****************************\n";
  print "$subjectdirs[$i]            \n";
  print "****************************\n";

  my @images = <${subjectdirs[$i]}/*NORMALIZED.nii.gz>;

  if( @images == 0 )
    {
    die "The normalized images don't exist for ${subjectdirs[$i]}.  Did you forget to run createNormalizedImagesForCohort.pl?\n";
    }

  my ( $filename, $directories, $suffix ) = fileparse( $images[0], @suffixList );
  my $prefix = $filename;
  $prefix =~ s/_FLAIR_NORMALIZED//;

  my $mask = "${maskdir}/${prefix}_CEREBRUM_MASK.nii.gz";

  my $outputSubjectDirectory = "${outputBaseDirectory}/${prefix}/";
  my $outputPrefix = "${outputSubjectDirectory}/${prefix}";

  if( ! -d $outputSubjectDirectory )
    {
    mkpath( $outputSubjectDirectory, {verbose => 0, mode => 0755} ) or
      die "Can't create output directory $outputSubjectDirectory\n\t";
    }

  my $csvFile = "${outputPrefix}_CLUSTER_CENTERS.csv";
  push( @clusterCenterFiles, $csvFile );
  if( ! -e $csvFile )
    {
    die "The csv file $csvFile doesn't exist.\n";
    }
  }

###
##
## Create feature images for each subject (send to cluster)
##
###

if( @clusterCenterFiles != @subjectdirs )
  {
  die "The number of cluster center files does not match the number of subjects.\n";
  }

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
  my $csvFile = "${outputPrefix}_CLUSTER_CENTERS.csv";

  if( ! -e $mask || ! -e $csvFile )
    {
    print "One of the following files is missing:\n";
    print "  mask         -> $mask\n";
    print "  csv file ->      $csvFile\n";
    next;
    }

  my @model = <${subjectdirs[$i]}/*${which}*.RData>;
  if( @model == 0 )
    {
    die "The model doesn't exist for ${subjectdirs[$i]}.\n";
    }

  my $coreLabel = 4;
  if( $cohort =~ m/Sim/ )
    {
    $coreLabel = 5;
    }

  my @meansStrings = ( );
  for( my $j = 0; $j < @images; $j++ )
    {
    my @means = getMeans( $i, $j, \@clusterCenterFiles );
    my $meanString = join( 'x', @means );
    push( @meansStrings, $meanString );
    }

  my @args = ( 'sh', "${UTILPATH}/../scripts/applyTumorSegmentationModel.sh",
                     '-m', "${model[0]}",
                     '-d', 3,
                     '-x', $mask,
                     '-l', $coreLabel,
                     '-n', 'T1',
                     '-a', ${images[1]},
                     '-t', ${templates[1]},
                     '-c', ${meansStrings[1]},
                     '-n', 'FLAIR',
                     '-a', ${images[0]},
                     '-t', ${templates[0]},
                     '-c', ${meansStrings[0]},
                     '-n', 'T1C',
                     '-a', ${images[2]},
                     '-t', ${templates[2]},
                     '-c', ${meansStrings[2]},
                     '-n', 'T2',
                     '-a', ${images[3]},
                     '-t', ${templates[3]},
                     '-c', ${meansStrings[3]},
                     '-o', "${outputPrefix}_",
                     '-f', '0x2',
                     '-r', 1,
                     '-r', 3,
                     '-s', 2
                     );
  if( $which =~ /MRF/ )
    {
    push( @args, '-p', "${outputPrefix}_RF_POSTERIORS%d.nii.gz" );
    }

  my $commandFile = "${outputPrefix}Apply${which}Model.sh";

  open( FILE, ">${commandFile}" );
  print FILE "#!/bin/sh\n";
  print FILE "export ITK_GLOBAL_DEFAULT_NUMBER_OF_THREADS=1\n";

  print FILE "export LD_LIBRARY_PATH=";
  print FILE "\"/home/njt4n/share/Pkg/R/library/Rcpp/lib:";
  print FILE "/home/njt4n/share/Pkg/ANTsR/src/ANTS/ANTS-build/lib:";
  print FILE "\$LD_LIBRARY_PATH\"\n";
  print FILE "\n";
  print FILE "@args\n";
  close( FILE );

#   if( ! -e "${outputPrefix}_NORMALIZED_DISTANCE.nii.gz" )
#     {
    print "** feature images ${filename}\n";
    my @qargs = ( 'qsub',
                  '-N', "${prefix}",
                  '-v', "ANTSPATH=$ANTSPATH",
                  '-v', "UTILPATH=$UTILPATH",
                  '-q', 'standard',
                  '-l', 'mem=8gb',
                  '-l', 'nodes=1:ppn=1',
                  '-l', 'walltime=01:00:00',
                  $commandFile );
    system( @qargs ) == 0 || die "qsub\n";
#     }
#   else
#     {
#     print " feature images ${filename}\n";
#     }
  }

###
##
## Sub-routine which averages all the cluster centers except for the
## current subject.  This permits a leave-one-out cross validation.
##
###

sub getMeans
  {
  my $index = $_[0];
  my $which = $_[1];
  my $files = $_[2];

  my @means;
  my $count = 0;
  for( my $i = 0; $i < @$files; $i++ )
    {
    if( $i == $index )
      {
      next;
      }
    else
      {
      open( FILE, "<$files->[$i]" );
      my @contents = <FILE>;
      close( FILE );
      my @localMeans = split( ",", ${contents[$which]} );
      for( my $j = 0; $j < @localMeans; $j++ )
        {
        if( defined( $localMeans[$j] ) )
          {
          if( $count == 0 )
            {
            ${means[$j]} = ${localMeans[$j]};
            }
          else
            {
            ${means[$j]} += ${localMeans[$j]};
            }
          }
        }
      $count++;
      }
    }

  for( my $j = 0; $j < @means; $j++ )
    {
    ${means[$j]} /= $count;
    }

  return @means;
  }
