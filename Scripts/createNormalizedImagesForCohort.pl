#/usr/bin/perl -w

use strict;

use Cwd 'realpath';
use File::Find;
use File::Basename;
use File::Path;
use File::Spec;
use FindBin qw($Bin);

my $usage = qq{
  Usage: createNormalizedImagesForCohort.pl <outputDir> <cohort>
 };

my ( $outputBaseDirectory, $cohort ) = @ARGV;

my $ANTSPATH = $ENV{ 'ANTSPATH' };
my $UTILPATH = $ENV{ 'UTILPATH' };

my $basedir = '/home/njt4n/share/Data/Tumor/BRATS/';
my $maskdir = "${basedir}/Masks/";

my @suffixList = ( ".mha", ".nii.gz" );

my @subjectdirs = <${basedir}/Images/${cohort}*>;

###
##
## Create normalized images for each subject (send to cluster)
##
###

for( my $i = 0; $i < @subjectdirs; $i++ )
  {
  print "****************************\n";
  print "$subjectdirs[$i]            \n";
  print "****************************\n";

  my @images = <${subjectdirs[$i]}/*.nii.gz>;

  my ( $filename, $directories, $suffix ) = fileparse( $images[0], @suffixList );
  my $prefix = $filename;
  $prefix =~ s/_FLAIR//;

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
    print "One of the following files is missing:\n";
    print "  mask         -> $mask\n";
    next;
    }

  my $commandFile = "${outputPrefix}NormalizationCommand.sh";

  open( FILE, ">${commandFile}" );
  print FILE "#!/bin/sh\n";
  print FILE "export ITK_GLOBAL_DEFAULT_NUMBER_OF_THREADS=1\n";
  print FILE "\n";

  for( my $j = 0; $j < @images; $j++ )
    {
    my ( $filename, $directories, $suffix ) = fileparse( $images[$j] );
    my $normalizedImage = $filename;
    $normalizedImage =~ s/\.nii\.gz/\_NORMALIZED\.nii\.gz/;
    $normalizedImage = "${outputSubjectDirectory}/${normalizedImage}";

    print FILE "${ANTSPATH}ImageMath 3 $normalizedImage TruncateImageIntensity $images[$j] 0.01 0.99 200\n";
#     print FILE "${ANTSPATH}N4BiasFieldCorrection -d 3 -c[50x50x50x10,0] -x $mask -b [200] -s 2 -i $normalizedImage -o $normalizedImage\n";
#     print FILE "${ANTSPATH}ImageMath 3 $normalizedImage m $mask $normalizedImage\n";
    print FILE "${UTILPATH}RescaleImageIntensity 3 $normalizedImage $normalizedImage 0 1\n";
#    print FILE "${ANTSPATH}HistogramMatchImages 3 $normalizedImage $templates[$i] 200 12";
    }
  close( FILE );

  if( ! -e "${outputPrefix}_T2_NORMALIZED.nii.gz" )
    {
    print "** normalization ${filename}\n";
    my @qargs = ( 'qsub',
                  '-N', "${prefix}",
                  '-v', "ANTSPATH=$ANTSPATH",
                  '-v', "UTILPATH=$UTILPATH",
                  '-q', 'standard',
                  '-l', 'mem=8gb',
                  '-l', 'nodes=1:ppn=1',
                  '-l', 'walltime=05:00:00',
                  $commandFile );
    system( @qargs ) == 0 || die "qsub\n";
    }
  else
    {
    print " normalization ${filename}\n";
    }
  }
