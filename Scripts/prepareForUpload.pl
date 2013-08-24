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
my $uploadDir = "${baseDir}/Upload/";
my $posteriorsDir = "${baseDir}/Posteriors2/";
my $gmmPosteriorsDir = "${posteriorsDir}/GMM_RF_POSTERIORS/";
my $mrfPosteriorsDir = "${posteriorsDir}/MAP_MRF_RF_POSTERIORS/";
my $refineDir = "${baseDir}/Refinement/";
my $truthDir = "${baseDir}/TruthLabels2/";

my @atroposTruthLabels = <${truthDir}/*atropos_truth.nii.gz>;

for( my $i = 0; $i < @atroposTruthLabels; $i++ )
  {
  my @comps = split( '/', $atroposTruthLabels[$i] );

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
    $referenceDir .= "/HG/${number}/VSD.Brain.XX.O.MR_Flair/";
    }
  else
    {
    $number =~ s/LG//;
    $referenceDir .= "/LG/${number}/VSD.Brain.XX.O.MR_Flair/";
    }

  my @referenceFLAIR = <${referenceDir}/*.mha>;

  @tmp = split( '\.', $referenceFLAIR[0] );
  my $id = $tmp[-2];

  my $outputFile = "${uploadDir}/VSD.Seg_${prefix}.${id}.mha";

  print "$prefix -> $outputFile\n";

  my $refinedLabels = "${refineDir}/${prefix}_REFINE_RF_LABELS.nii.gz";

#   my $mrfLabels = "${mrfPosteriorsDir}/${prefix}_RF_LABELS.nii.gz";
#   if( ! -e $mrfLabels )
#     {
#     my @mrfPosteriors = <${mrfPosteriorsDir}/${prefix}_RF_POSTERIORS*.nii.gz>;
#     `MultipleOperateImages 3 seg $mrfLabels none @mrfPosteriors`;
#     }
#
#   `UnaryOperateImage 3 $mrfLabels t 0 $outputFile 1 3 0`;
  `UnaryOperateImage 3 $refinedLabels t 0 $outputFile 1 3 0`;

  `UnaryOperateImage 3 $outputFile - 3 $outputFile`;
  `UnaryOperateImage 3 $outputFile r 0 $outputFile -3 0`;
  `ChangeImageInformation 3 $outputFile $outputFile 4 $referenceFLAIR[0]`;
  `ConvertImage 3 $outputFile $outputFile 4`;
  }
