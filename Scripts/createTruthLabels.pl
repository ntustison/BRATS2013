#/usr/bin/perl -w

use strict;

use Cwd 'realpath';
use Switch;
use File::Find;
use File::Basename;
use File::Path;
use File::Spec;
use FindBin qw($Bin);

my $usage = qq{
  Usage: createTruthLabels.pl <outputDir> <cohort>

  Steps:
    1. Register template to subject
    2. Warp template labels to subject
    3. Refine subject labels using Atropos
    4. Add truth labels
 };

my ( $outputBaseDirectory, $cohort ) = @ARGV;

my $ANTSPATH = $ENV{ 'ANTSPATH' };
my $UTILPATH = $ENV{ 'UTILPATH' };

my $basedir = '/home/njt4n/share/Data/Tumor/BRATS/';
my $maskdir = "${basedir}/Masks/";
my $truthdir = "${basedir}/TruthLabels2/";
my $templatedir = '/home/njt4n/share/Data/Public/Kirby/SymmetricTemplate/';
my $template = "${templatedir}/S_template3_skullStripped_RESCALED.nii.gz";  #T1
my $templateLabels = "${templatedir}/S_templateJointLabels_6labels.nii.gz";

my @suffixList = ( ".mha", ".nii.gz" );

my @subjectdirs = <${basedir}/Images/${cohort}*>;

for( my $i = 0; $i < @subjectdirs; $i++ )
  {
  print "****************************\n";
  print "$subjectdirs[$i]            \n";
  print "****************************\n";

  my @t1Images = <${subjectdirs[$i]}/*T1.nii.gz>;

  my ( $filename, $directories, $suffix ) = fileparse( $t1Images[0], @suffixList );
  my $prefix = $filename;
  $prefix =~ s/_T1//;

  my $t1Image = $t1Images[0];
  my $t1cImage = "${directories}/${filename}C.nii.gz";
  my $mask = "${maskdir}/${prefix}_CEREBRUM_MASK.nii.gz";
  my $truth = "${truthdir}/${prefix}_truth.nii.gz";
  my $tmp = "${truthdir}/${prefix}_tmp.nii.gz";
  my $output = "${truthdir}/${prefix}_atropos_truth.nii.gz";

  if( ! -e $t1Image || ! -e $t1cImage || ! -e $mask || ! -e $truth )
    {
    next;
    }

  my $outputSubjectDirectory = "${outputBaseDirectory}/${prefix}/";
  my $outputPrefix = "${outputSubjectDirectory}/${prefix}";

  if( ! -d $outputSubjectDirectory )
    {
    mkpath( $outputSubjectDirectory, {verbose => 0, mode => 0755} ) or
      die "Can't create output directory $outputSubjectDirectory\n\t";
    }

  my $commandFile = "${outputPrefix}command.sh";

  open( FILE, ">${commandFile}" );
  print FILE "#!/bin/sh\n";
  print FILE "export ITK_GLOBAL_DEFAULT_NUMBER_OF_THREADS=1\n";
  print FILE "\n";

  ##
  ## Register the template to the individual subject
  ##

  my @regArgs = ( "${ANTSPATH}/antsRegistration", '-d', 3,
                                                  '-o', "${outputPrefix}_ANTs_REGISTRATION",
                                                  '-w', '[0.01,0.995]',
                                                  '-r', "[${t1Image},${template},1]",
                                                  '-t', 'Rigid[0.1]',
                                                  '-m', "MI[${t1Image},${template},1,32,Regular,0.25]",
                                                  '-s', '2x1x0',
                                                  '-f', '4x2x1',
                                                  '-c', '[500x250x100,1e-8,15]',
                                                  '-t', 'Affine[0.1]',
                                                  '-m', "MI[${t1Image},${template},1,32,Regular,0.25]",
                                                  '-s', '2x1x0',
                                                  '-f', '4x2x1',
                                                  '-c', '[500x250x100,1e-8,15]',
                                                  '-t', 'BSplineSyN[0.1,10x10x11,0x0x0]',
                                                  '-m', "CC[${t1Image},${template},1,4]",
                                                  '-s', '2x1x0',
                                                  '-f', '4x2x1',
                                                  '-c', '[70x50x10,1e-8,15]'
                                                  );
  if( ! -e "${outputPrefix}_ANTs_REGISTRATION1Warp.nii.gz" )
    {
    print FILE "@regArgs\n";
    }

  my @xformArgs = ( 'antsApplyTransforms', '-d', 3,
                                           '-i', $templateLabels,
                                           '-n', 'NearestNeighbor',
                                           '-r', $t1Image,
                                           '-o', $output,
                                           '-t', "${outputPrefix}_ANTs_REGISTRATION1Warp.nii.gz",
                                           '-t', "${outputPrefix}_ANTs_REGISTRATION0GenericAffine.mat"
                                           );
  print FILE "@xformArgs\n";

  my @args = ( '${UTILPATH}/UnaryOperateImage', '3',  $output, 't', '0', $output, '5', '6',  '0' );
  print FILE "@args\n";
  @args = ( '${UTILPATH}/UnaryOperateImage', '3',  $output, 'r', '0', $output, '4', '3' );
  print FILE "@args\n";

  ##
  ## Refine warped template labels with Atropos
  ##

  my @atroposArgs = ( '${ANTSPATH}/Atropos', '-d', 3,
                          '-a', $t1cImage,
                          '-i', "PriorLabelImage[3,${output},0.1]",
                          '-l', '1[5.0,0.25]',
                          '-l', '2[5.0,0.25]',
                          '-l', '3[5.0,0.25]',
                          '-p', 'Aristotle[1]',
                          '-g', '[1,2]',
                          '-x', $mask,
                          '-c', '[10,0]',
                          '-k', 'Gaussian',
                          '-m', "[0.1,1x1x1]",
                          '-o', ${output}
                          );
  print FILE "@atroposArgs\n";

  ##
  ## Add edema and tumor labels to subject labels
  ##

  @args = ( '${UTILPATH}/UnaryOperateImage', '3',  $truth, 'r', '0', $tmp, '4', '7' );
  print FILE "@args\n";
  @args = ( '${UTILPATH}/UnaryOperateImage', '3',  $tmp, 'r', '0', $tmp, '3', '6' );
  print FILE "@args\n";
  @args = ( '${UTILPATH}/UnaryOperateImage', '3',  $tmp, 'r', '0', $tmp, '2', '5' );
  print FILE "@args\n";
  @args = ( '${UTILPATH}/UnaryOperateImage', '3',  $tmp, 'r', '0', $tmp, '1', '4' );
  print FILE "@args\n";
  @args = ( '${UTILPATH}/BinaryOperateImages', '3', $output, 'max', $tmp, $output );
  print FILE "@args\n";
  @args = ( 'rm', $tmp );
  print FILE "@args\n";

  close( FILE );

  if( ! -e $output )
    {
    print "** truth labels ${filename}\n";
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
    }
  else
    {
    print " truth labels ${filename}\n";
    }

  }

