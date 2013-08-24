#################################
#
# exampleTrain - this simple example uses 2-D slices from the BRATS data
#                to illustrate methods briefly sketched in "ANTs and Arboles."
#                Specifically, we create a random forest model from the training
#                data to then predict using the testing data.
#
#                Input:  FLAIR, T1, T1C, T2 images
#                Training subjects:  BRATS_HG0001, BRATS_HG0002, BRATS_HG0003, BRATS_HG0004, BRATS_HG0005
#
#                The following steps are performed:
#                   1. Create feature images for each training subject.
#                   2. Create "GMM" random forest model from feature images.
#                   3. Create additional features images using model from 2.
#                   4. Create "MRF" random forest model from new and previous feature images.

######################################################################################
#
# Step 1:  Create feature images for each training subject
#
######################################################################################

BASE_DIRECTORY=./

SCRIPTS_DIRECTORY=${BASE_DIRECTORY}/../Scripts/

DATA_DIRECTORY=${BASE_DIRECTORY}/BRATS2DData/
TRAINING_DATA_DIRECTORY=${DATA_DIRECTORY}/TrainingData/
PROCESSED_DIRECTORY=${DATA_DIRECTORY}/Processed

if [[ ! -e $PROCESSED_DIRECTORY ]];
  then
    mkdir -p $PROCESSED_DIRECTORY
  fi

TEMPLATE_DIRECTORY=${DATA_DIRECTORY}/SymmetricTemplate/
TEMPLATE_FLAIR=${TEMPLATE_DIRECTORY}/S_templateFLAIR_RESCALED_slice141.nii.gz
TEMPLATE_T1=${TEMPLATE_DIRECTORY}/S_templateT1_RESCALED_slice141.nii.gz
TEMPLATE_T2=${TEMPLATE_DIRECTORY}/S_templateT2_RESCALED_slice141.nii.gz

TRAINING_SUBJECTS=( BRATS_HG0001 BRATS_HG0002 BRATS_HG0003 BRATS_HG0004 BRATS_HG0005 )
TRAINING_SLICES=( 90 90 95 94 95 )

NUMBER_OF_CLASSES=7
TUMOR_CORE_LABEL=4

for (( i=0; i<${#TRAINING_SUBJECTS[@]}; i++ ))
  do
    echo "Creating training images for ${TRAINING_SUBJECTS[$i]}"

    MASK=${TRAINING_DATA_DIRECTORY}/${TRAINING_SUBJECTS[$i]}/${TRAINING_SUBJECTS[$i]}_MASK_slice${TRAINING_SLICES[$i]}.nii.gz
    FLAIR=${TRAINING_DATA_DIRECTORY}/${TRAINING_SUBJECTS[$i]}/${TRAINING_SUBJECTS[$i]}_FLAIR_slice${TRAINING_SLICES[$i]}.nii.gz
    T1=${TRAINING_DATA_DIRECTORY}/${TRAINING_SUBJECTS[$i]}/${TRAINING_SUBJECTS[$i]}_T1_slice${TRAINING_SLICES[$i]}.nii.gz
    T1C=${TRAINING_DATA_DIRECTORY}/${TRAINING_SUBJECTS[$i]}/${TRAINING_SUBJECTS[$i]}_T1C_slice${TRAINING_SLICES[$i]}.nii.gz
    T2=${TRAINING_DATA_DIRECTORY}/${TRAINING_SUBJECTS[$i]}/${TRAINING_SUBJECTS[$i]}_T2_slice${TRAINING_SLICES[$i]}.nii.gz

    SUBJECT_PROCESSED_DIRECTORY=${PROCESSED_DIRECTORY}/${TRAINING_SUBJECTS[$i]}/
    OUTPUT_PREFIX=${SUBJECT_PROCESSED_DIRECTORY}/${TRAINING_SUBJECTS[$i]}

    sh ${SCRIPTS_DIRECTORY}/createFeatureImages.sh \
      -d 2 \
      -x $MASK \
      -l $TUMOR_CORE_LABEL \
      -n T1 \
      -a $T1 \
      -t $TEMPLATE_T1 \
      -n FLAIR \
      -a $FLAIR \
      -t $TEMPLATE_FLAIR \
      -n T1C \
      -a $T1C \
      -t $TEMPLATE_T1 \
      -n T2 \
      -a $T2 \
      -t $TEMPLATE_T2 \
      -f 0x2 \
      -o ${OUTPUT_PREFIX}_ \
      -r 1 \
      -r 3 \
      -s 2 \
      -b ${NUMBER_OF_CLASSES}

  done

######################################################################################
#
# Step 2:  Create "GMM" RF model
#          First, though, we need to create a csv file from the files in the
#          processed training directories.  We list the truth labels and the
#          mask first.
#
######################################################################################

##
#
# Create csv file
#
##

GMM_CSV_FILE=${PROCESSED_DIRECTORY}/example_GMM_FeatureImageList.csv

ROW_NAMES=()
GMM_FILES=( `ls ${PROCESSED_DIRECTORY}/${TRAINING_SUBJECTS[0]}/*.nii.gz` )
for (( i=0; i<${#GMM_FILES[@]}; i++ ))
  do
    FILENAME=$( basename ${GMM_FILES[$i]} )
    FILENAME=${FILENAME/\.nii\.gz/}
    FILENAME=${FILENAME/${TRAINING_SUBJECTS[0]}_/}
    if [[ "$FILENAME" != *Warp && "$FILENAME" != *Affine* && "$FILENAME" != *Segmentation* ]];
      then
        ROW_NAMES[${#ROW_NAMES[@]}]=$FILENAME
      fi
  done
ROW_NAMES_STRING=$( printf ",%s" "${ROW_NAMES[@]}" )
ROW_NAMES_STRING=${ROW_NAMES_STRING:1}
echo "TRUTH_LABELS,MASK,$ROW_NAMES_STRING" > $GMM_CSV_FILE

for (( i=0; i<${#TRAINING_SUBJECTS[@]}; i++ ))
  do
    FILES=()
    for (( j=0; j<${#ROW_NAMES[@]}; j++ ))
      do
        FILES=( ${FILES[@]} ${PROCESSED_DIRECTORY}/${TRAINING_SUBJECTS[$i]}/${TRAINING_SUBJECTS[$i]}_${ROW_NAMES[$j]}.nii.gz )
      done
    TRUTH=${TRAINING_DATA_DIRECTORY}/${TRAINING_SUBJECTS[$i]}/${TRAINING_SUBJECTS[$i]}_atropos_truth_slice${TRAINING_SLICES[$i]}.nii.gz
    MASK=${TRAINING_DATA_DIRECTORY}/${TRAINING_SUBJECTS[$i]}/${TRAINING_SUBJECTS[$i]}_MASK_slice${TRAINING_SLICES[$i]}.nii.gz
    FILES=( $TRUTH $MASK ${FILES[@]} )
    FILES_STRING=$( printf ",%s" "${FILES[@]}" )
    FILES_STRING=${FILES_STRING:1}
    echo $FILES_STRING >> $GMM_CSV_FILE
  done

##
#
# Create "GMM"-model and plot variable importance
#
##

GMM_MODEL=${PROCESSED_DIRECTORY}/example_GMM_Model
if [[ ! -f "${GMM_MODEL}.RData" ]];
  then
    Rscript ${SCRIPTS_DIRECTORY}/createModel.R 2 $GMM_CSV_FILE $GMM_MODEL 1 1 2000 500 $NUMBER_OF_CLASSES
  fi
Rscript ${SCRIPTS_DIRECTORY}/plotVariableImportance.R ${GMM_MODEL}.RData ${GMM_MODEL}VariableImportance.pdf

######################################################################################
#
# Step 3:  Apply "GMM" RF model to each training subject.  This provides a set of
#          probability maps for each class.  We can then use these probability maps
#          to seed a MAP-MRF Atropos segmentation to produce a new set of feature
#          images for the "MAP-MRF" RF Model.
#
######################################################################################

for (( i=0; i<${#TRAINING_SUBJECTS[@]}; i++ ))
  do
    echo "Applying GMM model to ${TRAINING_SUBJECTS[$i]}"

    MASK=${TRAINING_DATA_DIRECTORY}/${TRAINING_SUBJECTS[$i]}/${TRAINING_SUBJECTS[$i]}_MASK_slice${TRAINING_SLICES[$i]}.nii.gz
    FLAIR=${TRAINING_DATA_DIRECTORY}/${TRAINING_SUBJECTS[$i]}/${TRAINING_SUBJECTS[$i]}_FLAIR_slice${TRAINING_SLICES[$i]}.nii.gz
    T1=${TRAINING_DATA_DIRECTORY}/${TRAINING_SUBJECTS[$i]}/${TRAINING_SUBJECTS[$i]}_T1_slice${TRAINING_SLICES[$i]}.nii.gz
    T1C=${TRAINING_DATA_DIRECTORY}/${TRAINING_SUBJECTS[$i]}/${TRAINING_SUBJECTS[$i]}_T1C_slice${TRAINING_SLICES[$i]}.nii.gz
    T2=${TRAINING_DATA_DIRECTORY}/${TRAINING_SUBJECTS[$i]}/${TRAINING_SUBJECTS[$i]}_T2_slice${TRAINING_SLICES[$i]}.nii.gz

    SUBJECT_PROCESSED_DIRECTORY=${PROCESSED_DIRECTORY}/${TRAINING_SUBJECTS[$i]}/
    OUTPUT_PREFIX=${SUBJECT_PROCESSED_DIRECTORY}/${TRAINING_SUBJECTS[$i]}

    sh ${SCRIPTS_DIRECTORY}/applyTumorSegmentationModel.sh \
      -d 2 \
      -x $MASK \
      -l $TUMOR_CORE_LABEL \
      -n T1 \
      -a $T1 \
      -t $TEMPLATE_T1 \
      -n FLAIR \
      -a $FLAIR \
      -t $TEMPLATE_FLAIR \
      -n T1C \
      -a $T1C \
      -t $TEMPLATE_T1 \
      -n T2 \
      -a $T2 \
      -t $TEMPLATE_T2 \
      -f 0x2 \
      -o ${OUTPUT_PREFIX}_ \
      -r 1 \
      -r 3 \
      -s 2 \
      -b ${NUMBER_OF_CLASSES} \
      -m ${GMM_MODEL}.RData

    sh ${SCRIPTS_DIRECTORY}/createFeatureImages.sh \
      -d 2 \
      -x $MASK \
      -l $TUMOR_CORE_LABEL \
      -n T1 \
      -a $T1 \
      -t $TEMPLATE_T1 \
      -n FLAIR \
      -a $FLAIR \
      -t $TEMPLATE_FLAIR \
      -n T1C \
      -a $T1C \
      -t $TEMPLATE_T1 \
      -n T2 \
      -a $T2 \
      -t $TEMPLATE_T2 \
      -f 0x2 \
      -o ${OUTPUT_PREFIX}_ \
      -r 1 \
      -r 3 \
      -s 2 \
      -b ${NUMBER_OF_CLASSES} \
      -p ${OUTPUT_PREFIX}_RF_POSTERIORS%d.nii.gz

  done

######################################################################################
#
# Step 4:  Create "MAP_MRF" RF model
#          First, though, we need to create a csv file from the files in the
#          processed training directories.  We also exclude the GMM files which
#          were used in the first model.
#
######################################################################################

##
#
# Create csv file
#
##


MAP_MRF_CSV_FILE=${PROCESSED_DIRECTORY}/example_MAP_MRF_FeatureImageList.csv

ROW_NAMES=()
MAP_MRF_FILES=( `ls ${PROCESSED_DIRECTORY}/${TRAINING_SUBJECTS[0]}/*.nii.gz` )
for (( i=0; i<${#MAP_MRF_FILES[@]}; i++ ))
  do
    FILENAME=$( basename ${MAP_MRF_FILES[$i]} )
    FILENAME=${FILENAME/\.nii\.gz/}
    FILENAME=${FILENAME/${TRAINING_SUBJECTS[0]}_/}
    if [[ "$FILENAME" != *Warp && "$FILENAME" != *Affine* && "$FILENAME" != *Segmentation* && "$FILENAME" != *GMM* && "$FILENAME" != *RF_POSTERIORS* ]];
      then
        ROW_NAMES[${#ROW_NAMES[@]}]=$FILENAME
      fi
  done
ROW_NAMES_STRING=$( printf ",%s" "${ROW_NAMES[@]}" )
ROW_NAMES_STRING=${ROW_NAMES_STRING:1}
echo "TRUTH_LABELS,MASK,$ROW_NAMES_STRING" > $MAP_MRF_CSV_FILE

for (( i=0; i<${#TRAINING_SUBJECTS[@]}; i++ ))
  do
    FILES=()
    for (( j=0; j<${#ROW_NAMES[@]}; j++ ))
      do
        FILES=( ${FILES[@]} ${PROCESSED_DIRECTORY}/${TRAINING_SUBJECTS[$i]}/${TRAINING_SUBJECTS[$i]}_${ROW_NAMES[$j]}.nii.gz )
      done
    TRUTH=${TRAINING_DATA_DIRECTORY}/${TRAINING_SUBJECTS[$i]}/${TRAINING_SUBJECTS[$i]}_atropos_truth_slice${TRAINING_SLICES[$i]}.nii.gz
    MASK=${TRAINING_DATA_DIRECTORY}/${TRAINING_SUBJECTS[$i]}/${TRAINING_SUBJECTS[$i]}_MASK_slice${TRAINING_SLICES[$i]}.nii.gz
    FILES=( $TRUTH $MASK ${FILES[@]} )
    FILES_STRING=$( printf ",%s" "${FILES[@]}" )
    FILES_STRING=${FILES_STRING:1}
    echo $FILES_STRING >> $MAP_MRF_CSV_FILE
  done

##
#
# Create "MAPMRF"-model and plot variable importance
#
##

MAP_MRF_MODEL=${PROCESSED_DIRECTORY}/example_MAP_MRF_Model
if [[ ! -f "${MAP_MRF_MODEL}.RData" ]];
  then
    Rscript ${SCRIPTS_DIRECTORY}/createModel.R 2 $MAP_MRF_CSV_FILE $MAP_MRF_MODEL 1 1 2000 500 $NUMBER_OF_CLASSES
  fi
Rscript ${SCRIPTS_DIRECTORY}/plotVariableImportance.R ${MAP_MRF_MODEL}.RData ${MAP_MRF_MODEL}VariableImportance.pdf


