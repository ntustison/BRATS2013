#/usr/bin/perl -w

use strict;

use Cwd 'realpath';
use File::Find;
use File::Basename;
use File::Path;
use File::Spec;
use FindBin qw($Bin);

my $usage = qq{
  Usage: runLeaveOneOutCrossValidation.pl <output_dir> <cohort>
 };

my ( $outputdir, $cohort ) = @ARGV;

my $ANTSPATH = $ENV{ 'ANTSPATH' };
my $UTILPATH = $ENV{ 'UTILPATH' };

my $basedir = '/home/njt4n/share/Data/Tumor/BRATS/';
my $maskdir = "${basedir}/Masks/";
my $truthdir = "${basedir}/TruthLabels2/";

my $numberOfUniqueLabels = 7;
if( $cohort =~ m/Sim/ )
  {
  $numberOfUniqueLabels = 5;
  }

my @suffixList = ( ".mha", ".nii.gz" );

my @subjectdirs = <${outputdir}/${cohort}*>;

for( my $i = 0; $i < @subjectdirs; $i++ )
  {
  my @comps = split( '/', @subjectdirs[$i] );
  my $prefix = $comps[-1];

  # create csv list minus the current subject

  my $subjectCSV = "${subjectdirs[$i]}/leaveOneOutDirectoryList.csv";
  if( ! -e $subjectCSV )
    {
    open( FILE, ">$subjectCSV" );

    for( my $j = 0; $j < @subjectdirs; $j++ )
      {
      if( $i == $j )
        {
        next;
        }

      print FILE "${subjectdirs[$j]}\n";
      }
    close( FILE );
    }

  print "Creating model for ${prefix}\n";
  system( "/usr/bin/perl ${basedir}/Scripts2/createRandomForestModel.pl $subjectCSV ${subjectdirs[$i]}/${prefix} $numberOfUniqueLabels" );
  }
