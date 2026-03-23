####### REMOVE ALL OBJECTS IN WORKPLACE ########
rm(list=ls())

###LOAD all packages###
library(readxl)
library(dplyr)
library(stringr)
library(purrr)
library(openxlsx)

##ROUND 1 ###
####### REMOVE ALL OBJECTS IN WORKPLACE ########
rm(list=ls())

## 1. Read the R1 survey files (keep statement1 as col names)
##Qualtrics
setwd("C:/Users/OrielTsao/Desktop/COVID-19 RCHEs/DATA/1. Raw Data/R1/Qualtric Download/20251124_missingentered")

INSMAIN_raw <- read_excel("EVAX_INSMAIN_TEXT_finalvar.xlsx", col_names = FALSE)

# ##Others Cyrus dataset
setwd("C:/Users/OrielTsao/Desktop/COVID-19 RCHEs/DATA/1. Raw Data/R1/Other datasets")

RCHE_raw <- read_excel("EVAX_RCHE.xlsx", col_names = TRUE)

## 2. Correct to desired colnames as header
#A. Qualtrics Remove statement2 from header
#col_names = TRUE
rm_stat2 <- function(df) {
  df_wostat2 <- df[-(1:2), ] #df[1,] is statement 2, statement 1 is colname
  df_wostat2
}

INSMAIN_clean <- rm_stat2(INSMAIN_raw)

header_row2 <- function(df) {
  # 1. Set row 3 as column names
  colnames(df) <- as.character(unlist(df[1, ]))
  # 2. Remove rows 1 to 3
  df <- df[-(1:2), ]
  return(df)
}

INSMAIN_clean <- header_row2(INSMAIN_clean)

##3 Prep 1 to join surveys within Round: convert everything to character 
#if error: names(resident3_clean)[duplicated(names(resident3_clean))]
INSMAIN_clean <- INSMAIN_clean %>% mutate(across(everything(), as.character))
RCHE_clean <-RCHE_raw %>% mutate(across(everything(), as.character))



##4 Prep 3: make sure core joining variable are the same
##Make sure RCHEID is in RCHEID col and formate "EXXX"
fullRCHEID <- function(df) {
  df$RCHEID <- paste0("E",df$RCHEID)
  return(df)
}

INSMAIN_clean <- fullRCHEID(INSMAIN_clean)
RCHE_clean <- fullRCHEID(RCHE_clean)


##5 Prep 4: prefix all final var names with dataset origin
## except for the core variable so we can still join by ID and other vars correctly
RCHEID <- "RCHEID"

INSMAIN_clean <- INSMAIN_clean %>%
  rename_with(~ paste0("RCHEINSMAIN.", .x), .cols = -all_of(c(RCHEID)))

RCHE_clean <- RCHE_clean %>%
  rename_with(~ paste0("RCHEBasic.", .x), .cols = -all_of(c(RCHEID)))

#6 Join surveys within R1 (full join) by PID
# full join keeps everyone in the surveys
combined_R1_RCHE_1 <- INSMAIN_clean %>%
  full_join(RCHE_clean, by = c(RCHEID))


combined_R1_RCHE_1$round <- 1

##7 Sort by RCHEID
combined_R1_RCHE_1 <- combined_R1_RCHE_1 %>%
  arrange(.data[[RCHEID]])

##8. Reorder colnames to round, RCHEID, PID, name_CHI
combined_R1_RCHE_1 <- combined_R1_RCHE_1 %>%
  select(round, RCHEID, everything())


##save combined_R1_RCHE into excel
setwd("C:/Users/OrielTsao/Desktop/COVID-19 RCHEs/DATA/3. Clean Data/R1")
write.xlsx(combined_R1_RCHE_1, 
           file = "combined_R1_RCHE_1.xlsx",
           colNames = TRUE,
           rowNames = FALSE)

##QC # make sure there's no duplicate RCHEID
combined_R1_RCHE_1 %>%
  count(RCHEID) %>%     # count how many times each PID appears
  count(n)           # count how many PIDs have n duplicates

sum(duplicated(combined_R1_RCHE_1[[RCHEID]]))

unique(combined_R1_RCHE_1$RCHEID[duplicated(combined_R1_RCHE_1$RCHEID)])

###################################################################################################

##ROUND 2.2 ###
####### REMOVE ALL OBJECTS IN WORKPLACE ########
rm(list=ls())

setwd("C:/Users/OrielTsao/Desktop/COVID-19 RCHEs/DATA/1. Raw Data/R2/R2 and R3_Qualtric Download/20251124_withfinalvarname")

## 1. Read the R2 survey files (no col names, because first 3 rows are special)
RCHE_raw <- read_excel("RCHE_finalvar.xlsx", col_names = FALSE)


## 2. Pull out the 3 header rows from a Qualtrics file to be reconstructed later
get_header <- function(df) {
  list(
    stmt1 = as.character(df[1, ]),  # row 1: old var name
    stmt2 = as.character(df[2, ]),  # row 2: question text
    finalvar = as.character(df[3, ])   # row 3: final var name
  )
}

RCHE_header <- get_header(RCHE_raw)


##3. Only keep and set data colnames to statement 1 for cleaning participant data
clean_pdata <- function(df) {
  finalvar <- as.character(df[3,])
  df_woheader <- df[-(1:3), ]
  names(df_woheader) <- finalvar
  df_woheader
}

RCHE_clean <- clean_pdata(RCHE_raw)

##4 Prep 1 to join surveys within Round: convert everything to character 
#if error: names(RCHE_clean)[duplicated(names(RCHE_clean))]
RCHE_clean <- RCHE_clean %>% mutate(across(everything(), as.character))


## 4A. Include only Round 2 Participants
R2_RCHE_clean <- RCHE_clean %>% filter(round == '2')



##5 Prep 3: prefix all final var names with dataset origin
## except for the core variable so we can still join by ID and other vars correctly
RCHEID <- "RCHEID"
round <- "round"

#list of all var with no prefix
noprefix_var <- c(round, RCHEID)

combined_R2_RCHE_1 <- R2_RCHE_clean %>%
  rename_with(~ paste0("R2RCHE.", .x), .cols = -all_of(noprefix_var))

##7 Sort by ID
combined_R2_RCHE_1 <- combined_R2_RCHE_1 %>%
  arrange(.data[[RCHEID]])

##8 Reorder colnames to round, RCHEID, PID, name_CHI
combined_R2_RCHE_1 <- combined_R2_RCHE_1 %>%
  select(round, RCHEID, everything())

##save combined_R2.2 into excel
setwd("C:/Users/OrielTsao/Desktop/COVID-19 RCHEs/DATA/3. Clean Data/R2")
write.xlsx(combined_R2_RCHE_1, 
           file = "combined_R2.2_RCHE_1.xlsx",
           colNames = TRUE,
           rowNames = FALSE)

##QC
combined_R2_RCHE_1 %>%
  count(RCHEID) %>%     # count how many times each PID appears
  count(n)           # count how many PIDs have n duplicates

#END

###################################################################################################
##ROUND 3 ###
####### REMOVE ALL OBJECTS IN WORKPLACE ########
rm(list=ls())
setwd("C:/Users/OrielTsao/Desktop/COVID-19 RCHEs/DATA/1. Raw Data/R2/R2 and R3_Qualtric Download/20251124_withfinalvarname")

## 1. Read the R2 survey files (no col names, because first 3 rows are special)
RCHE_raw <- read_excel("RCHE_finalvar.xlsx", col_names = FALSE)


## 2. Pull out the 3 header rows from a Qualtrics file to be reconstructed later
get_header <- function(df) {
  list(
    stmt1 = as.character(df[1, ]),  # row 1: old var name
    stmt2 = as.character(df[2, ]),  # row 2: question text
    finalvar = as.character(df[3, ])   # row 3: final var name
  )
}

RCHE_header <- get_header(RCHE_raw)


##3. Only keep and set data colnames to statement 1 for cleaning participant data
clean_pdata <- function(df) {
  finalvar <- as.character(df[3,])
  df_woheader <- df[-(1:3), ]
  names(df_woheader) <- finalvar
  df_woheader
}

RCHE_clean <- clean_pdata(RCHE_raw)

##4 Prep 1 to join surveys within Round: convert everything to character 
#if error: names(RCHE_clean)[duplicated(names(RCHE_clean))]
RCHE_clean <- RCHE_clean %>% mutate(across(everything(), as.character))


## 4A. Include only Round 2 Participants
R3_RCHE_clean <- RCHE_clean %>% filter(round == '3')



##5 Prep 3: prefix all final var names with dataset origin
## except for the core variable so we can still join by ID and other vars correctly
RCHEID <- "RCHEID"
round <- "round"

#list of all var with no prefix
noprefix_var <- c(round, RCHEID)

combined_R3_RCHE_1 <- R3_RCHE_clean %>%
  rename_with(~ paste0("R3RCHE.", .x), .cols = -all_of(noprefix_var))

##7 Sort by ID
combined_R3_RCHE_1 <- combined_R3_RCHE_1 %>%
  arrange(.data[[RCHEID]])

##8 Reorder colnames to round, RCHEID, PID, name_CHI
combined_R3_RCHE_1 <- combined_R3_RCHE_1 %>%
  select(round, RCHEID, everything())

##save combined_R2.2 into excel
setwd("C:/Users/OrielTsao/Desktop/COVID-19 RCHEs/DATA/3. Clean Data/R3")
write.xlsx(combined_R3_RCHE_1, 
           file = "combined_R3_RCHE_1.xlsx",
           colNames = TRUE,
           rowNames = FALSE)

##QC
combined_R3_RCHE_1 %>%
  count(RCHEID) %>%     # count how many times each PID appears
  count(n)           # count how many PIDs have n duplicates

#END OF PART 1-9
################################################################################
####### REMOVE ALL OBJECTS IN WORKPLACE ########
rm(list=ls())

###PART 10D ALL ROUND joining combined_R1 to R3 ### (Prep for Part 10e Phase 2)

setwd("C:/Users/OrielTsao/Desktop/COVID-19 RCHEs/DATA/10d/ALL ROUNDS/RCHE")

## 1. Read the R2 survey files (no col names, because first 3 rows are special)
R1_raw <- read_excel("combined_R1_RCHE_1.xlsx", col_names = T)
R2_raw <- read_excel("combined_R2.2_RCHE_1.xlsx", col_names = T)
R3_raw <- read_excel("combined_R3_RCHE_1.xlsx", col_names = T)

## 1. Read the R2 survey files (no col names, because first 3 rows are special)
R1_clean <- R1_raw %>% mutate(across(everything(), as.character))
R2_clean <- R2_raw %>% mutate(across(everything(), as.character))
R3_clean <- R3_raw %>% mutate(across(everything(), as.character))

##2.  Prep 2 to join survey within Round: set participant ID and merge name_CHI
round <- "round"
RCHEID <- "RCHEID"
unique_RCHEID <- "unique_RCHEID"

##7 Join surveys within R2 (full join) by PID
#full join keeps everyone in the surveys
ALLRound <- R1_clean %>%
  full_join(R2_clean, by = c(round, RCHEID)) %>%
  full_join(R3_clean, by = c(round, RCHEID)) 

###make sure new/old RCHEID is the same RCHEID in unique_RCHEID
#df$col[df$col == "old"] <- "new"

ALLRound$unique_RCHEID <- ALLRound$RCHEID

###list of RCHEID with old and new
ALLRound$unique_RCHEID[ALLRound$unique_RCHEID == "E201"] <- "E947"
ALLRound$unique_RCHEID[ALLRound$unique_RCHEID == "E003"] <- "E948"
ALLRound$unique_RCHEID[ALLRound$unique_RCHEID == "E005"] <- "E961"

##8 Sort by ID
ALLRound <- ALLRound %>% 
  arrange(.data[[unique_RCHEID]], RCHEID, round)

##9. Reorder colnames to round, RCHEID, PID, name_CHI
ALLRound <- ALLRound %>%
  select(round, RCHEID, unique_RCHEID, everything())

##save combined_R2.2 into excel

setwd("C:/Users/OrielTsao/Desktop/COVID-19 RCHEs/DATA/10d/ALL ROUNDS/RCHE")

write.xlsx(ALLRound, 
           file = "RCHE_ALLRound.xlsx",
           colNames = TRUE,
           rowNames = FALSE)

#END of Part 10D
###################################################################################
####################################################################################