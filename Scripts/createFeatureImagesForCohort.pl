#/usr/bin/perl -w

use strict;

use Cwd 'realpath';
use File::Find;
use File::Basename;
use File::Path;
use File::Spec;
use FindBin qw($Bin);

my $usage = qq{
  Usage: createFeatureImagesForCohort.pl <outputDir> <cohort>
 };

my ( $outputBaseDirectory, $cohort ) = @ARGV;

my $ANTSPATH = $ENV{ 'ANTSPATH' };
my $UTILPATH = $ENV{ 'UTILPATH' };

my $basedir = '/home/njt4n/share/Data/Tumor/BRATS/';
my $imagedir = "${basedir}/Images/";
my $maskdir = "${basedir}/Masks/";
my $truthdir = "${basedir}/TruthLabels2/";
my $templatedir = '/home/njt4n/share/Data/Public/Kirby/SymmetricTemplate/';
my $templateLabels = "${templatedir}/S_templateJointLabels_6labels.nii.gz";

my @templates = ();
$templates[0] = "${templatedir}/S_template2_skullStripped_RESCALED.nii.gz";          #FLAIR
$templates[1] = "${templatedir}/S_template3_skullStripped_RESCALED.nii.gz";          #T1
$templates[2] = "${templatedir}/S_template3_skullStripped_RESCALED.nii.gz";          #T1
$templates[3] = "${templatedir}/S_template5_skullStripped_RESCALED.nii.gz";          #T2

my @suffixList = ( ".mha", ".nii.gz" );

my @subjectdirs = <${outputBaseDirectory}/${cohort}*>;

###
##
## Create csv files if they don't exist
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
  my $truth = "${truthdir}/${prefix}_atropos_truth_masked.nii.gz";

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

    if( ! -e $mask || ! -e $truth )
      {
      print "One of the following files is missing:\n";
      print "  mask         -> $mask\n";
      print "  truth labels -> $truth\n";
      next;
      }

    open( CSV_FILE, ">${csvFile}" );
    for( my $j = 0; $j < @images; $j++ )
      {
      my @out = `LabelIntensityStatistics 3 $images[$j] $truth`;

      my @means = ( 0, 0, 0, 0, 0, 0, 0 );
      if( $cohort =~ m/Sim/ )
        {
        @means = ( 0, 0, 0, 0, 0 );
        }
      for( my $k = 1; $k < @out; $k++ )
        {
        my @stats = split( ' ', $out[$k] );
        $means[${stats[0]}-1] = $stats[1];
        }
      my $meansString = join( ',', @means );
      print CSV_FILE "${meansString}\n";
      }
    close( CSV_FILE );
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

  my $coreLabel = 4;
  if( $cohort =~ m/Sim/ )
    {
    $coreLabel = 5;
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

  my @meansStrings = ();
  my @indices = ( 0, 1, 2, 3 );  # ( FLAIR, T1, T1C, T2 )
  for( my $j = 0; $j < @indices; $j++ )
    {
    my @means = getMeans( $indices[$j], $j, \@clusterCenterFiles );
    my $meanString = join( 'x', @means );
    push( @meansStrings, $meanString );
    }

  my @args = ( 'sh', "${UTILPATH}/../scripts/createFeatureImages.sh",
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
                     '-f', '0x2',
                     '-o', "${outputPrefix}_",
                     '-r', 1,
                     '-r', 3,
                     '-s', 2
                     );
  if( -e "${outputPrefix}_RF_POSTERIORS1.nii.gz" )
    {
    push( @args, '-p', "${outputPrefix}_RF_POSTERIORS%d.nii.gz" );
    }

  my $commandFile = "${outputPrefix}FeaturesCommand.sh";
  my $logFile = "${outputPrefix}log.txt";

  open( FILE, ">${commandFile}" );
  print FILE "#!/bin/sh\n";
  print FILE "export ITK_GLOBAL_DEFAULT_NUMBER_OF_THREADS=1\n";
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
                  '-l', 'walltime=15:00:00',
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
