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
my $refineDir2 = "${baseDir}/Refinement/";
my $gmmPosteriorsDir = "${posteriorsDir}/GMM_RF_POSTERIORS/";
my $mrfPosteriorsDir = "${posteriorsDir}/MAP_MRF_RF_POSTERIORS/";
my $truthDir = "${baseDir}/TruthLabels2/";

my @atroposTruthLabels = <${truthDir}/*atropos_truth_masked.nii.gz>;

for( my $i = 0; $i < @atroposTruthLabels; $i++ )
  {
  my @comps = split( '/', $atroposTruthLabels[$i] );

  my $prefix = $comps[-1];
  $prefix =~ s/_atropos_truth_masked\.nii\.gz//;

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

  @tmp = split( '\.', $referenceImages[0] );
  my $id = $tmp[-2];

#   my $outputFile = "${uploadDir}/VSD.Seg_${prefix}.${id}.mha";
#   my $truthFile = "${truthDir}/${prefix}_truth.nii.gz";

  my $outputFile1 = "${refineDir1}/${prefix}_RF_LABELS.nii.gz";
  my $outputFile2 = "${refineDir2}/${prefix}_REFINE_RF_LABELS.nii.gz";
  my $truthFile = "${truthDir}/${prefix}_atropos_truth.nii.gz";

#   print "/Applications/ITK-SNAP.app/Contents/MacOS/InsightSNAP -g $referenceImages[0] -s $truthFile & ";
#   print "/Applications/ITK-SNAP.app/Contents/MacOS/InsightSNAP -g $referenceImages[1] -s $truthFile & ";
#   print "/Applications/ITK-SNAP.app/Contents/MacOS/InsightSNAP -g $referenceImages[2] -s $truthFile & ";
#   print "/Applications/ITK-SNAP.app/Contents/MacOS/InsightSNAP -g $referenceImages[3] -s $truthFile\n";

#   print "/Applications/ITK-SNAP.app/Contents/MacOS/InsightSNAP -g $referenceImages[0]\n";
#   print "/Applications/ITK-SNAP.app/Contents/MacOS/InsightSNAP -g $referenceImages[1]\n";
#   print "/Applications/ITK-SNAP.app/Contents/MacOS/InsightSNAP -g $referenceImages[2]\n";
#   print "/Applications/ITK-SNAP.app/Contents/MacOS/InsightSNAP -g $referenceImages[3]\n";

  print "/Applications/ITK-SNAP.app/Contents/MacOS/InsightSNAP -g $referenceImages[3] -s $outputFile1 & ";
  print "/Applications/ITK-SNAP.app/Contents/MacOS/InsightSNAP -g $referenceImages[2] -s $outputFile2 & ";
  print "/Applications/ITK-SNAP.app/Contents/MacOS/InsightSNAP -g $referenceImages[0] -s $atroposTruthLabels[$i]\n";
  }
