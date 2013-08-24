
brats <- read.csv( "BRATS_results.csv" )

# All labels

# p-value = 0.4204
staple_vs_gmm <- wilcox.test( brats$AllLabels[which( brats$GMMxMRF == "STAPLE" )],
                              brats$AllLabels[which( brats$GMMxMRF == "GMM" )],
                              paired = TRUE, alternative = "greater" )
# p-value = 0.8919
staple_vs_mrf <- wilcox.test( brats$AllLabels[which( brats$GMMxMRF == "STAPLE" )],
                              brats$AllLabels[which( brats$GMMxMRF == "MRF" )],
                              paired = TRUE, alternative = "greater" )
# p-value = 0.3781
mrf_vs_gmm    <- wilcox.test( brats$AllLabels[which( brats$GMMxMRF == "MRF" )],
                              brats$AllLabels[which( brats$GMMxMRF == "GMM" )],
                              paired = TRUE, alternative = "greater" )

# Complete tumor

# p-value = 0.04865
staple_vs_gmm <- wilcox.test( brats$CompleteTumor[which( brats$GMMxMRF == "STAPLE" )],
                              brats$CompleteTumor[which( brats$GMMxMRF == "GMM" )],
                              paired = TRUE, alternative = "greater" )
# p-value = 0.7021
staple_vs_mrf <- wilcox.test( brats$CompleteTumor[which( brats$GMMxMRF == "STAPLE" )],
                              brats$CompleteTumor[which( brats$GMMxMRF == "MRF" )],
                              paired = TRUE, alternative = "greater" )
# p-value = 0.02913
mrf_vs_gmm    <- wilcox.test( brats$CompleteTumor[which( brats$GMMxMRF == "MRF" )],
                              brats$CompleteTumor[which( brats$GMMxMRF == "GMM" )],
                              paired = TRUE, alternative = "greater" )

# Tumor core

# p-value = 0.1081
staple_vs_gmm <- wilcox.test( brats$TumorCore[which( brats$GMMxMRF == "STAPLE" )],
                              brats$TumorCore[which( brats$GMMxMRF == "GMM" )],
                              paired = TRUE, alternative = "greater" )
# p-value = 0.7738
staple_vs_mrf <- wilcox.test( brats$TumorCore[which( brats$GMMxMRF == "STAPLE" )],
                              brats$TumorCore[which( brats$GMMxMRF == "MRF" )],
                              paired = TRUE, alternative = "greater" )
# p-value = 0.01638
mrf_vs_gmm    <- wilcox.test( brats$TumorCore[which( brats$GMMxMRF == "MRF" )],
                              brats$TumorCore[which( brats$GMMxMRF == "GMM" )],
                              paired = TRUE, alternative = "greater" )


# Enhancing tumor

# p-value = 0.0001612
staple_vs_gmm <- wilcox.test( brats$EnhancingTumor[which( brats$GMMxMRF == "STAPLE" )],
                              brats$EnhancingTumor[which( brats$GMMxMRF == "GMM" )],
                              paired = TRUE, alternative = "greater" )
# p-value = 0.4204
staple_vs_mrf <- wilcox.test( brats$EnhancingTumor[which( brats$GMMxMRF == "STAPLE" )],
                              brats$EnhancingTumor[which( brats$GMMxMRF == "MRF" )],
                              paired = TRUE, alternative = "greater" )
# p-value = 5.245e-05
mrf_vs_gmm    <- wilcox.test( brats$EnhancingTumor[which( brats$GMMxMRF == "MRF" )],
                              brats$EnhancingTumor[which( brats$GMMxMRF == "GMM" )],
                              paired = TRUE, alternative = "greater" )



simbrats <- read.csv( "SimBRATS_results.csv" )

# Complete tumor

# p-value = 1
staple_vs_gmm <- wilcox.test( simbrats$CompleteTumor[which( simbrats$GMMxMRF == "STAPLE" )],
                              simbrats$CompleteTumor[which( simbrats$GMMxMRF == "GMM" )],
                              paired = TRUE, alternative = "greater" )
# p-value = 1
staple_vs_mrf <- wilcox.test( simbrats$CompleteTumor[which( simbrats$GMMxMRF == "STAPLE" )],
                              simbrats$CompleteTumor[which( simbrats$GMMxMRF == "MRF" )],
                              paired = TRUE, alternative = "greater" )
# p-value = 0.007904
mrf_vs_gmm    <- wilcox.test( simbrats$CompleteTumor[which( simbrats$GMMxMRF == "MRF" )],
                              simbrats$CompleteTumor[which( simbrats$GMMxMRF == "GMM" )],
                              paired = TRUE, alternative = "greater" )

# Tumor core

# p-value = 0.4923
staple_vs_gmm <- wilcox.test( simbrats$TumorCore[which( simbrats$GMMxMRF == "STAPLE" )],
                              simbrats$TumorCore[which( simbrats$GMMxMRF == "GMM" )],
                              paired = TRUE, alternative = "greater" )
# p-value = 0.907
staple_vs_mrf <- wilcox.test( simbrats$TumorCore[which( simbrats$GMMxMRF == "STAPLE" )],
                              simbrats$TumorCore[which( simbrats$GMMxMRF == "MRF" )],
                              paired = TRUE, alternative = "greater" )
# p-value = 0.006206
mrf_vs_gmm    <- wilcox.test( simbrats$TumorCore[which( simbrats$GMMxMRF == "MRF" )],
                              simbrats$TumorCore[which( simbrats$GMMxMRF == "GMM" )],
                              paired = TRUE, alternative = "greater" )


