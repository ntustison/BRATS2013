#################################
#
# examplePredict - use after calling "exampleTrain.sh"

BASE_DIRECTORY=./

SCRIPTS_DIRECTORY=${BASE_DIRECTORY}/../Scripts/

DATA_DIRECTORY=${BASE_DIRECTORY}/BRATS2DData/
TESTING_DATA_DIRECTORY=${DATA_DIRECTORY}/TestingData/
PROCESSED_DIRECTORY=${DATA_DIRECTORY}/Processed

TEMPLATE_DIRECTORY=${DATA_DIRECTORY}/SymmetricTemplate/
TEMPLATE_FLAIR=${TEMPLATE_DIRECTORY}/S_templateFLAIR_RESCALED_slice141.nii.gz
TEMPLATE_T1=${TEMPLATE_DIRECTORY}/S_templateT1_RESCALED_slice141.nii.gz
TEMPLATE_T2=${TEMPLATE_DIRECTORY}/S_templateT2_RESCALED_slice141.nii.gz

TESTING_SUBJECTS=( BRATS_HG0006 BRATS_HG0008 BRATS_HG0009 )
TESTING_SLICES=( 103 96 110 )

NUMBER_OF_CLASSES=7
TUMOR_CORE_LABEL=4

GMM_MODEL=${PROCESSED_DIRECTORY}/example_GMM_Model
MAP_MRF_MODEL=${PROCESSED_DIRECTORY}/example_MAP_MRF_Model

######################################################################################
#
# Apply "GMM" and then "MAP_MRF" RF models to each testing subject.
#
######################################################################################

for (( i=0; i<${#TESTING_SUBJECTS[@]}; i++ ))
  do
    echo "Applying GMM model to ${TESTING_SUBJECTS[$i]}"

    MASK=${TESTING_DATA_DIRECTORY}/${TESTING_SUBJECTS[$i]}/${TESTING_SUBJECTS[$i]}_MASK_slice${TESTING_SLICES[$i]}.nii.gz
    FLAIR=${TESTING_DATA_DIRECTORY}/${TESTING_SUBJECTS[$i]}/${TESTING_SUBJECTS[$i]}_FLAIR_slice${TESTING_SLICES[$i]}.nii.gz
    T1=${TESTING_DATA_DIRECTORY}/${TESTING_SUBJECTS[$i]}/${TESTING_SUBJECTS[$i]}_T1_slice${TESTING_SLICES[$i]}.nii.gz
    T1C=${TESTING_DATA_DIRECTORY}/${TESTING_SUBJECTS[$i]}/${TESTING_SUBJECTS[$i]}_T1C_slice${TESTING_SLICES[$i]}.nii.gz
    T2=${TESTING_DATA_DIRECTORY}/${TESTING_SUBJECTS[$i]}/${TESTING_SUBJECTS[$i]}_T2_slice${TESTING_SLICES[$i]}.nii.gz

    SUBJECT_PROCESSED_DIRECTORY=${PROCESSED_DIRECTORY}/${TESTING_SUBJECTS[$i]}/
    OUTPUT_PREFIX=${SUBJECT_PROCESSED_DIRECTORY}/${TESTING_SUBJECTS[$i]}

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
      -p ${OUTPUT_PREFIX}_RF_POSTERIORS%d.nii.gz \
      -m ${MAP_MRF_MODEL}.RData

    ${ANTSPATH}/ImageMath 2 ${OUTPUT_PREFIX}_RF_LABELS.nii.gz MostLikely 0 ${OUTPUT_PREFIX}_RF_POSTERIORS*.nii.gz

  done

######################################################################################
#
# Screen dump consisting of label overlap measures with "true" labels
#
######################################################################################

for (( i=0; i<${#TESTING_SUBJECTS[@]}; i++ ))
  do
    echo ""
    echo "============================================================="
    echo "    Label overlap measures for ${TESTING_SUBJECTS[$i]}"
    echo ""

    TRUTH=${TESTING_DATA_DIRECTORY}/${TESTING_SUBJECTS[$i]}/${TESTING_SUBJECTS[$i]}_atropos_truth_slice${TESTING_SLICES[$i]}.nii.gz

    SUBJECT_PROCESSED_DIRECTORY=${PROCESSED_DIRECTORY}/${TESTING_SUBJECTS[$i]}/
    OUTPUT_PREFIX=${SUBJECT_PROCESSED_DIRECTORY}/${TESTING_SUBJECTS[$i]}

    echo "    Command call: ${ANTSPATH}/LabelOverlapMeasures 2 ${OUTPUT_PREFIX}_RF_LABELS.nii.gz $TRUTH"
    echo "-------------------------------------------------------------"
    echo ""

    ${ANTSPATH}/LabelOverlapMeasures 2 ${OUTPUT_PREFIX}_RF_LABELS.nii.gz $TRUTH

    echo "============================================================="
    echo ""
  done
