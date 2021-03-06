#Sarah V. Leavitt
#Boston University Dissertation
#Paper 2

################################################################################
# This program estimates transmission probabilities and serial interval, and 
# reproductive number for the Mass DPH data using the NB transmission method.
# The data are cleaned in MassPrep.R.

# NOTE: Program takes around 5 hours to run completely (with the original dataset).
# Best to run using MassQsub.qsub and run on a shared commuting cluster
################################################################################


#setwd("~/Boston University/Dissertation/nbPaper2")
setwd("/project/sv-thesis/nbPaper2")
rm(list = ls())


######################### Estimating Probabilities ############################

library(dplyr)
library(tidyr)
library(devtools)
load_all("../nbTransmission")

#Reading in cleaned datasets from MassPrep.R
set.seed(103020)
massInd <- readRDS("../Datasets/MassInd.rds")
massPair <- readRDS("../Datasets/MassPair.rds")

#How many pairs are different lineages (52%)
sum(massPair$Lineage == "Different", na.rm = TRUE)
sum(massPair$Lineage == "Different", na.rm = TRUE) / nrow(massPair)

#Creating an ordered dataset that also removes pairs with different lineages
orderedMass <- (massPair
                %>% filter(CombinedDiff >= 0, Lineage == "Same" | is.na(Lineage))
                %>% select(EdgeID, StudyID.1, StudyID.2, ContactGroup, Lineage.1, Lineage.2,
                           CombinedDt.1, CombinedDt.2, RecentArrival1.1, RecentArrival1.2,
                           RecentArrival2.1, RecentArrival2.2, County, Sex, Age, Spoligotype,
                           MIRUDiff, MIRUDiffG, GENType, PCRType, Lineage, CountryOfBirth,
                           Smear, SharedResG, AnyImmunoSup, TimeCat, CombinedDiff, CombinedDiffY,
                           CombinedDiffYM, ContactTrain)
)

print(table(orderedMass$ContactTrain, useNA = "always"))
print(prop.table(table(orderedMass$ContactTrain, useNA = "always")))

#Looking at all contact pairs
contactPairs <- (orderedMass
                 %>% filter(ContactGroup == TRUE)
                 %>% select(EdgeID, RecentArrival2.1, RecentArrival2.2, CombinedDt.1, CombinedDt.2,
                            CombinedDiff, Lineage.1, Lineage.2, Spoligotype, GENType, PCRType,
                            MIRUDiffG, SharedResG, ContactTrain)
)



#### Estimating Probabilities ####

## NOTE BEGIN RUNNING HERE IF YOU ARE USING THE SIMULATED DATASET "orderedMassSim.rds" ##
# orderedMass <- readRDS("orderedMassSim.rds")

#Estimating the probabilities with time difference
covariates <- c("Sex", "Age", "CountryOfBirth", "County", "Smear", "AnyImmunoSup",
                "SharedResG", "GENType", "TimeCat")

resMass <- nbProbabilities(orderedPair = orderedMass, indIDVar = "StudyID", pairIDVar = "EdgeID",
                           goldStdVar = "ContactTrain", covariates = covariates,
                           label = "ContactTime", l = 0.5, n = 10, m = 1, nReps = 50,
                           progressBar = FALSE)

resMassCov <- (orderedMass
               %>% full_join(resMass$probabilities, by = "EdgeID")
               #Setting probabilities to 0 if infectee was a recent immigrant but not if it was a training link
               %>% mutate(pScaledI1 = ifelse(!is.na(RecentArrival1.2) &
                                              RecentArrival1.2 == TRUE &
                                              (is.na(ContactTrain) | ContactTrain != TRUE), 0, pScaled),
                          pScaledI2 = ifelse(!is.na(RecentArrival2.2) &
                                               RecentArrival2.2 == TRUE &
                                               (is.na(ContactTrain) | ContactTrain != TRUE), 0, pScaled))
)
resMassCoeff <- resMass$estimates

print("Finished estimating probabilities with time difference")


#Estimating probabilities without time difference
covariates2 <- c("Sex", "Age", "CountryOfBirth", "County", "Smear", "AnyImmunoSup",
                 "SharedResG", "GENType")

resMass2 <- nbProbabilities(orderedPair = orderedMass, indIDVar = "StudyID", pairID = "EdgeID",
                            goldStdVar = "ContactTrain", covariates = covariates2,
                            label = "ContactNoTime", l = 0.5, n = 10, m = 1, nReps = 50,
                            progressBar = FALSE)

resMassCov2 <- (orderedMass
                %>% full_join(resMass2$probabilities, by = c("EdgeID"))
                #Setting probabilities to 0 if infectee was a recent immigrant but not if it was a training link
                %>% mutate(pScaledI1 = ifelse(!is.na(RecentArrival1.2) &
                                                RecentArrival1.2 == TRUE &
                                                (is.na(ContactTrain) | ContactTrain != TRUE), 0, pScaled),
                           pScaledI2 = ifelse(!is.na(RecentArrival2.2) &
                                                RecentArrival2.2 == TRUE &
                                                (is.na(ContactTrain) | ContactTrain != TRUE), 0, pScaled))
)
resMassCoeff2 <- resMass2$estimates

print("Finished estimating probabilities without time difference")


#Saving the results
saveRDS(resMassCov, "../Datasets/MassResults.rds")
saveRDS(resMassCov2, "../Datasets/MassResults_NoTime.rds")




###################### Serial Interval ########################


siHC1 <- estimateSI(df = resMassCov2, indIDVar = "StudyID",
                  timeDiffVar = "CombinedDiffYM", pVar = "pScaledI2",
                  clustMethod = "hc_absolute", cutoffs = seq(0.025, 0.25, 0.025),
                  initialPars = c(1.2, 2), shift = 0, bootSamples = 1000, progressBar = FALSE)
siHC1$label <- "HC: Excluding 1-month co-prevalent cases"
print("HC: Excluding 1-month co-prevalent cases")

siHC2 <- estimateSI(df = resMassCov2, indIDVar = "StudyID",
                   timeDiffVar = "CombinedDiffYM", pVar = "pScaledI2",
                   clustMethod = "hc_absolute", cutoffs = seq(0.025, 0.25, 0.025),
                   initialPars = c(1.2, 2), shift = 1/12, bootSamples = 1000, progressBar = FALSE)
siHC2$label <- "HC: Excluding 2-month co-prevalent cases"
print("HC: Excluding 2-month co-prevalent cases")

siHC3 <- estimateSI(df = resMassCov2, indIDVar = "StudyID",
                     timeDiffVar = "CombinedDiffYM", pVar = "pScaledI2",
                     clustMethod = "hc_absolute", cutoffs = seq(0.025, 0.25, 0.025),
                     initialPars = c(1.2, 2), shift = 2/12, bootSamples = 1000, progressBar = FALSE)
siHC3$label <- "HC: Excluding 3-month co-prevalent cases"
print("HC: Excluding 3-month co-prevalent cases")


siKD1 <- estimateSI(df = resMassCov2, indIDVar = "StudyID",
                   timeDiffVar = "CombinedDiffYM", pVar = "pScaledI2",
                   clustMethod = "kd", cutoffs = seq(0.01, 0.1, 0.01),
                   initialPars = c(1.2, 2), shift = 0, bootSamples = 1000, progressBar = FALSE)
siKD1$label <- "KD: Excluding 1-month co-prevalent cases"
print("KD: Excluding 1-month co-prevalent cases")

siKD2 <- estimateSI(df = resMassCov2, indIDVar = "StudyID",
                    timeDiffVar = "CombinedDiffYM", pVar = "pScaledI2",
                    clustMethod = "kd", cutoffs = seq(0.01, 0.1, 0.01),
                    initialPars = c(1.2, 2), shift = 1/12, bootSamples = 1000, progressBar = FALSE)
siKD2$label <- "KD: Excluding 2-month co-prevalent cases"
print("KD: Excluding 2-month co-prevalent cases")

siKD3 <- estimateSI(df = resMassCov2, indIDVar = "StudyID",
                    timeDiffVar = "CombinedDiffYM", pVar = "pScaledI2",
                    clustMethod = "kd", cutoffs = seq(0.01, 0.1, 0.01),
                    initialPars = c(1.2, 2), shift = 2/12, bootSamples = 1000, progressBar = FALSE)
siKD3$label <- "KD: Excluding 3-month co-prevalent cases"
print("KD: Excluding 3-month co-prevalent cases")


#Sensitivity analysis for recent immigration definition
siHCI1 <- estimateSI(df = resMassCov2, indIDVar = "StudyID",
                   timeDiffVar = "CombinedDiffYM", pVar = "pScaledI1",
                   clustMethod = "hc_absolute", cutoffs = seq(0.025, 0.25, 0.025),
                   initialPars = c(1.2, 2), shift = 0, bootSamples = 1000, progressBar = FALSE)
siHCI1$label <- "HC: Recent Arrival = 1 Year"
print("HC: Recent Arrival = 1 Year")

siKDI1 <- estimateSI(df = resMassCov2, indIDVar = "StudyID",
                   timeDiffVar = "CombinedDiffYM", pVar = "pScaledI1",
                   clustMethod = "kd", cutoffs = seq(0.01, 0.1, 0.01),
                   initialPars = c(1.2, 2), shift = 0, bootSamples = 1000, progressBar = FALSE)
siKDI1$label <- "KD: Recent Arrival = 1 Year"
print("KD: Recent Arrival = 1 Year")

siAll <- bind_rows(siHC1, siHC2, siHC3, siKD1, siKD2, siKD3, siHCI1, siKDI1)

#Saving the serial interval dataset
saveRDS(siAll, "../Datasets/MassSI.rds")




####################### Reproductive Number ###########################

#Initially calculating reproductive number to decide cut points
rInitial <- estimateR(df = resMassCov, dateVar = "CombinedDt", indIDVar = "StudyID",
                      pVar = "pScaledI2", timeFrame = "months")
rInitial$RtAvgDf
rt <- rInitial$RtDf

#Cutting the outbreak
totalTime <- max(rt$timeRank) - min(rt$timeRank)
monthCut1 <- ceiling(0.1 * totalTime)
monthCut2 <- ceiling(0.8 * totalTime)

#Plotting where to cut
# ggplot(data = rt) +
#   geom_line(aes(x = timeRank, y = Rt)) +
#   scale_y_continuous(name = "Rt") +
#   geom_vline(aes(xintercept = monthCut1), linetype = 2, size = 0.7, col = "blue") +
#   geom_vline(aes(xintercept = monthCut2), linetype = 2, size = 0.7, col = "blue")


#Calculating the reproductive number using 1 year definition for recent immigration
rFinal1 <- estimateR(resMassCov, dateVar = "CombinedDt", indIDVar = "StudyID",
                     pVar = "pScaledI1", timeFrame = "months",
                     rangeForAvg = c(monthCut1, monthCut2),
                     bootSamples = 1000, alpha = 0.05, progressBar = FALSE)

rFinal1$RiDf$label <- "Recent Arrival = 1 Year"
rFinal1$RtDf$label <- "Recent Arrival = 1 Year"
rFinal1$RtAvgDf$label <- "Recent Arrival = 1 Year"

print("Recent Arrival = 1 Year")

#Calculating the reproductive number using 2 year definition for recent immigration
rFinal2 <- estimateR(resMassCov, dateVar = "CombinedDt", indIDVar = "StudyID",
                     pVar = "pScaledI2", timeFrame = "months",
                     rangeForAvg = c(monthCut1, monthCut2),
                     bootSamples = 1000, alpha = 0.05, progressBar = FALSE)

rFinal2$RiDf$label <- "Recent Arrival = 2 Years"
rFinal2$RtDf$label <- "Recent Arrival = 2 Years"
rFinal2$RtAvgDf$label <- "Recent Arrival = 2 Years"

print("Recent Arrival = 2 Years")

RiData <- bind_rows(rFinal1$RiDf, rFinal2$RiDf)
RtData <- bind_rows(rFinal1$RtDf, rFinal2$RtDf)
RtAvg <- bind_rows(rFinal1$RtAvgDf, rFinal2$RtAvgDf)


#Saving the confidence interval datasets
saveRDS(RiData, "../Datasets/MassRi.rds")
saveRDS(RtData, "../Datasets/MassRtCI.rds")
saveRDS(RtAvg, "../Datasets/MassRtAvgCI.rds")



