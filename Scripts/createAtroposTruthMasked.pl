#! /usr/bin/perl -w


###################################################
# Truth labels:  1 for necrosis
#                2 for edema
#                3 for non-enhancing tumor
#                4 for enhancing tumor
#
# The evaulation is done for 3 different tumor sub-compartements:
# Region 1: complete tumor (labels 1+2+3+4 for patient data, labesl 1+2 for synthetic data
# Region 2: Tumor core (labels 1+3+4 for patient data, label 2 for synthetic data
# Region 3: Enhancing tumor (label 4 for patient data, n.a. for synthetic data
###################################################


my $baseDir = '/Users/ntustison/Data/Public/BRATS-2/';
my $realDir = "${baseDir}/Image_Data/";
my $simDir = "${baseDir}/Synthetic_Data/";
my $uploadDir = "${baseDir}/Upload2/";
my $posteriorsDir = "${baseDir}/Posteriors2/";
my $refineDir1 = "${baseDir}/Refinement/";
my $refineDir2 = "${baseDir}/RefinementB/";
my $gmmPosteriorsDir = "${posteriorsDir}/GMM_RF_POSTERIORS/";
my $mrfPosteriorsDir = "${posteriorsDir}/MAP_MRF_RF_POSTERIORS/";
my $truthDir = "${baseDir}/TruthLabels2/";

my @atroposTruthLabels = <${truthDir}/*atropos_truth.nii.gz>;

for( my $i = 0; $i < @atroposTruthLabels; $i++ )
  {
  my @comps = split( '/', $atroposTruthLabels[$i] );

  print "$atroposTruthLabels[$i]\n";

  my $prefix = $comps[-1];
  $prefix =~ s/_atropos_truth\.nii\.gz//;

  my @tmp = split( '_', $prefix );
  my $number = $tmp[1];

  my $referenceDir = $realDir;
  if( $prefix =~ m/Sim/ )
    {
    $referenceDir = $simDir;
    }
  if( $prefix =~ m/HG/ )
    {
    $number =~ s/HG//;
    $referenceDir .= "/HG/${number}/";
    }
  else
    {
    $number =~ s/LG//;
    $referenceDir .= "/LG/${number}/";
    }

  my @referenceImages = <${referenceDir}/VSD.Brain.XX*//*.mha>;

  my $maskedAtropos = "${truthDir}/${prefix}_atropos_truth_masked.nii.gz";
  my $tmpAtropos = "${truthDir}/*atropos_truth_tmp.nii.gz";

  `ThresholdImage 3 $referenceImages[0] $maskedAtropos 0 0 0 1`;
  for( my $j = 1; $j < @referenceImages; $j++ )
    {
    `ThresholdImage 3 $referenceImages[$j] $tmpAtropos 0 0 0 1`;
    `BinaryOperateImages 3 $maskedAtropos x $tmpAtropos $maskedAtropos`;
    }
  unlink( $tmpAtropos );

  `ChangeImageInformation 3 $maskedAtropos $maskedAtropos 4 $atroposTruthLabels[$i]`;
  `BinaryOperateImages 3 $atroposTruthLabels[$i] x $maskedAtropos $maskedAtropos`;
  }
