#############
#PRINTING - line number
setwd("C:/Users/OrielTsao/Desktop/COVID-19 RCHEs/DATA/2. R scripts")
lines <- readLines("Resident_Part1-9.R")
numbered <- paste(sprintf("%3d", seq_along(lines)), lines, sep = "  ")
cat(numbered, sep = "\n")

# Wrap in HTML with a monospace font
html_content <- paste0(
  "<html><head><style>",
  "body { font-family: monospace; font-size: 12pt; white-space: pre; }",
  "</style></head><body>",
  paste(htmltools::htmlEscape(numbered), collapse = "\n"),
  "</body></html>"
)

writeLines(html_content, "Resident_Part1-9.R.html")
###########

#####################################
#### Part 1.  Coding consensus
#####################################
#NOT APPLICABLE

#####################################
#### Part 2. Load packages
#####################################
library(readxl)
library(dplyr)
library(stringr)
library(purrr)
library(openxlsx)
library(writexl)
library(purrr)
library(tidyr)
library(tibble)

#####################################
###ROUND 1 ###
#####################################
####### REMOVE ALL OBJECTS IN WORKPLACE ########
rm(list=ls())

#####################################
#### Part 3. Manually add the final variable names as the third header row in raw data
#####################################
#ADDED MANUALLY IN EXCEL named "dataset_finalvar.xlsx

#####################################
#### Part 4. Load raw data, error repot, and all needed files
#####################################

## 1. Read the R1 survey files (keep statement1 as col names)
##Qualtrics
setwd("C:/Users/OrielTsao/Desktop/COVID-19 RCHEs/DATA/1. Raw Data/R1/Qualtric Download/20251124_missingentered")

residentINS_raw<- read_excel("EVAX_Institution.xlsx", col_names = TRUE)
residentMAINIADL_raw <- read_excel("EVAX_Main_IADL.xlsx", col_names = TRUE)
residentVISVH_raw <- read_excel("EVAX_VIS_VH.xlsx", col_names = TRUE)
residentMC_raw <- read_excel("EVAX_MiniCog.xlsx", col_names = TRUE)

##SurveyMonkey
setwd("C:/Users/OrielTsao/Desktop/COVID-19 RCHEs/DATA/1. Raw Data/R1/SurveyMonkey")

residentSM_raw <- read_excel("EVAX_SMTEXT.xlsx", col_names = FALSE)

##Others Cyrus dataset
setwd("C:/Users/OrielTsao/Desktop/COVID-19 RCHEs/DATA/1. Raw Data/R1/Other datasets")

residentdatacrd_raw <- read.csv("data_crd copy.csv", header = FALSE)
residentADD2_raw <- read_excel("EVAXADD2.xlsx", col_names = FALSE)
residentMINI_raw <- read_excel("MINI_Resident_dated20221228.xlsx", col_names = FALSE)
residentNHVE_raw <- read_excel("NHVE_fu_230705.xlsx", col_names = TRUE)

#####################################
#### Part 5. Correct raw data according to error repot
#####################################
#HARD CODE - DOB_DATE 
#E936-1-011
idx <- which(residentMINI_raw$`...1` == "E936-1-011") #`...1` = PID
residentMINI_raw$`...7`[idx] <- "1948" # `...7` = dob_yyyy
residentMINI_raw$`...8`[idx] <- "07" # `...8` = dob_mm
residentMINI_raw$`...9`[idx] <- "23" # `...9` = dob_dd

#####################################
####Part 6.  Combine datasets within the same round in wide form
#####################################

## 1. Correct to desired colnames as header
#A. Qualtrics Remove statement2 from header
#col_names = TRUE
rm_stat2 <- function(df) {
  df_wostat2 <- df[-(1), ] #df[1,] is statement 2, statement 1 is colname
  df_wostat2
}

residentINS_clean <- rm_stat2(residentINS_raw)
residentMAINIADL_clean <- rm_stat2(residentMAINIADL_raw)
residentVISVH_clean <- rm_stat2(residentVISVH_raw)
residentMC_clean <- rm_stat2(residentMC_raw)

#B. SurveyMonkey row 3 is header
#col_names = FALSE
header_row3 <- function(df) {
  # 1. Set row 3 as column names
  colnames(df) <- as.character(unlist(df[3, ]))
  # 2. Remove rows 1 to 3
  df <- df[-(1:3), ]
  return(df)
}


residentSM_clean <- header_row3(residentSM_raw)

#C. Cyrus's dataset row 2 is header
#col_names = FALSE
header_row2 <- function(df) {
  # 1. Set row 3 as column names
  colnames(df) <- as.character(unlist(df[2, ]))
  # 2. Remove rows 1 to 3
  df <- df[-(1:2), ]
  return(df)
}

residentdatacrd_clean <- header_row2(residentdatacrd_raw)
residentADD2_clean <- header_row2(residentADD2_raw)
residentMINI_clean <- header_row2(residentMINI_raw)


##2. Prep 1 to join surveys within Round: convert everything to character 
#if error: names(resident3_clean)[duplicated(names(resident3_clean))]
residentINS_clean <- residentINS_clean %>% mutate(across(everything(), as.character))
residentMAINIADL_clean <-residentMAINIADL_clean %>% mutate(across(everything(), as.character))
residentVISVH_clean <-residentVISVH_clean %>% mutate(across(everything(), as.character))
residentMC_clean <-residentMC_clean %>% mutate(across(everything(), as.character))
residentSM_clean <-residentSM_clean %>% mutate(across(everything(), as.character))
residentdatacrd_clean <-residentdatacrd_clean %>% mutate(across(everything(), as.character))
residentADD2_clean <-residentADD2_clean %>% mutate(across(everything(), as.character))
residentMINI_clean <-residentMINI_clean %>% mutate(across(everything(), as.character))
residentNHVE_clean <-residentNHVE_raw %>% mutate(across(everything(), as.character))

##3. Prep 2: make sure core joining variable are the same
##SurveyMonkey
fullPID <- function(df) {
  df$PID <- paste0(df$RCHEID,"-1-",df$PID)
  return(df)
}

residentSM_clean <- fullPID(residentSM_clean)

## For Cyrus's dataset
##Dataset: data_crd copy
convertsid <- function(df) {
  df$PID <- df$sid    # Start from the original sid column
  df$PID <- gsub("[^0-9]", "", df$PID)    # Remove all non-digits
  part1 <- substr(df$PID, 1, 3)    # Extract first 3 digits
  part2 <- substr(df$PID, 4, 6)   # Extract last 3 digits
  df$PID <- paste0("E", part1, "-1-", part2) # Rebuild into EVAX PID format
  return(df)
}

##Datset: NHVE
convertnumber <- function(df) {
  df$PID <- df$`Study no.`    # Start from the original sid column
  df$PID <- gsub("[^0-9]", "", df$PID)    # Remove all non-digits
  part1 <- substr(df$PID, 1, 3)    # Extract first 3 digits
  part2 <- substr(df$PID, 4, 6)   # Extract last 3 digits
  df$PID <- paste0("E", part1, "-1-", part2) # Rebuild into EVAX PID format
  return(df)
}

residentdatacrd_clean <- convertsid(residentdatacrd_clean)
residentNHVE_clean <- convertnumber(residentNHVE_clean)

#remove NA PIDs
residentNHVE_clean <- residentNHVE_clean %>% 
  filter(!is.na(PID) & PID != "ENA-1-NA")

#reorganise cols
residentdatacrd_clean <- residentdatacrd_clean %>%
  select(PID, everything())
residentNHVE_clean <- residentNHVE_clean %>%
  select(PID, everything())

#remove the last 3 columns 
residentNHVE_clean <- residentNHVE_clean %>% select(1:34)


##EVAXADD2
combconv_sid <- function(df) {
  df <- df %>% 
    mutate(PID = paste0(PID, PID2, PID3)) %>%  # combine 3 parts
    select(-PID2, -PID3)                       # drop old parts
  
  # make sure it's character and strip non-digits
  df$PID <- gsub("[^0-9]", "", as.character(df$PID))
  
  # first 3 digits
  part1 <- substr(df$PID, 1, 3)
  # last 3 digits (robust)
  part2 <- substr(df$PID, 4, 6)
  
  df$PID <- paste0("E", part1, "-1-", part2)
  return(df)
}

residentADD2_clean <- combconv_sid(residentADD2_clean)

##EVAX_MINI
#first is new_name, after = is old_name
residentMINI_clean <- residentMINI_clean %>% 
  rename(PID = sid) %>% 
  rename(name_CHI = cname)

# 4. Prep 3: Convert format of vactype (R1 MINI) to CVD1_type, CVD2_type, etc.
residentMINI_clean <- residentMINI_clean %>%
  mutate(
    CVd1_type = case_when(
      vactype == 1 & vacnum >= 1 ~ "Sinovac",   # has at least dose 1
      vactype == 2 & vacnum >= 1 ~ "BioNTech",
      vactype == 3 ~ "Sinovac",
      vactype == 4 ~ "Sinovac",
      vactype == 5 ~ "BioNTech",
      vactype == 6 ~ "BioNTech",
      vactype == 7 ~ "BioNTech",
      vactype == 9 ~ "BioNTech",
      TRUE ~ NA_character_
    ),
    CVd2_type = case_when(
      vactype == 1 & vacnum >= 2 ~ "Sinovac",   # has at least dose 2
      vactype == 2 & vacnum >= 2 ~ "BioNTech",
      vactype == 3 ~ "Sinovac",
      vactype == 4 ~ "Sinovac",
      vactype == 5 ~ "BioNTech",
      vactype == 6 ~ "BioNTech",
      vactype == 7 ~ "Sinovac",
      vactype == 9 ~ "BioNTech",
      TRUE ~ NA_character_
    ),
    CVd3_type = case_when(
      vactype == 1 & vacnum >= 3 ~ "Sinovac",   # has at least dose 3
      vactype == 2 & vacnum >= 3 ~ "BioNTech",
      vactype == 3 ~ "BioNTech",
      vactype == 4 ~ "Sinovac",
      vactype == 5 ~ "Sinovac",
      vactype == 6 ~ "BioNTech",
      vactype == 9 ~ "Sinovac",
      TRUE ~ NA_character_
    ),
    CVd4_type = case_when(
      vactype == 1 & vacnum >= 4 ~ "Sinovac",   # has at least dose 4
      vactype == 2 & vacnum >= 4 ~ "BioNTech",
      vactype == 4 ~ "BioNTech",
      vactype == 6 ~ "Sinovac",
      vactype == 9 ~ "Sinovac",
      TRUE ~ NA_character_
    )
  )

#QC check prep 3 (i.e. E910-1-003 R1-R3 Sinovac TRUE)
residentMINI_try <- residentMINI_clean %>% 
  select(PID, starts_with("CVd") & ends_with("type"))

##5. Prep 4: prefix all final var names with dataset origin
## except for the core variable so we can still join by ID and other vars correctly
id_var <- "PID"
RCHEID <- "RCHEID"
name_CHI <- "name_CHI"

residentINS_clean <- residentINS_clean %>%
  rename_with(~ paste0("ResidentINS.", .x), .cols = -all_of(c(id_var, RCHEID, name_CHI)))
residentMAINIADL_clean <- residentMAINIADL_clean %>%
  rename_with(~ paste0("ResidentMAINIADL.", .x), .cols = -all_of(c(id_var, RCHEID, name_CHI)))
residentVISVH_clean <- residentVISVH_clean %>%
  rename_with(~ paste0("ResidentVISVH.", .x), .cols = -all_of(c(id_var, RCHEID, name_CHI)))
residentMC_clean <- residentMC_clean %>%
  rename_with(~ paste0("ResidentMC.", .x), .cols = -all_of(c(id_var, RCHEID, name_CHI)))
residentSM_clean <- residentSM_clean %>%
  rename_with(~ paste0("ResidentSM.", .x), .cols = -all_of(c(id_var, RCHEID, name_CHI)))
residentMINI_clean <- residentMINI_clean  %>%
  rename_with(~ paste0("ResidentMINI.", .x), .cols = -all_of(c(id_var, name_CHI)))
residentdatacrd_clean <- residentdatacrd_clean %>%
  rename_with(~ paste0("ResidentCRD.", .x), .cols = -all_of(c(id_var)))
residentADD2_clean <- residentADD2_clean %>%
  rename_with(~ paste0("ResidentADD2.", .x), .cols = -all_of(c(id_var)))
residentNHVE_clean <- residentNHVE_clean %>%
  rename_with(~ paste0("ResidentNHVE.", .x), .cols = -all_of(c(id_var)))

##6 Join surveys within R1 (full join) by PID, RCHEID and name_CHI (if applicable)
#full join keeps everyone in the surveys
combined_R1_Res_1 <- residentINS_clean %>%
  full_join(residentMAINIADL_clean, by = c(id_var, RCHEID, name_CHI)) %>%
  full_join(residentVISVH_clean, by = c(id_var, RCHEID, name_CHI)) %>%
  full_join(residentMC_clean, by = c(id_var, RCHEID, name_CHI)) %>%
  full_join(residentSM_clean, by = c(id_var, RCHEID, name_CHI)) %>%
  full_join(residentMINI_clean, by = c(id_var, name_CHI))  %>%
  full_join(residentdatacrd_clean, by = c(id_var)) %>%
  full_join(residentADD2_clean, by = c(id_var)) %>%
  full_join(residentNHVE_clean, by = c(id_var))

##7 Sort by ID
combined_R1_Res_1 <- combined_R1_Res_1 %>%
  arrange(.data[[id_var]])

##8. Reorder colnames to round, RCHEID, PID, name_CHI
combined_R1_Res_1 <- combined_R1_Res_1 %>%
  select(RCHEID, PID, name_CHI, everything())


##save combined_R1 into excel
setwd("C:/Users/OrielTsao/Desktop/COVID-19 RCHEs/DATA/3. Clean Data/R1")
write.xlsx(combined_R1_Res_1, 
           file = "combined_R1_Res_1.xlsx",
           colNames = TRUE,
           rowNames = FALSE)

##QC
combined_R1_Res_1 %>%
  count(PID) %>%     # count how many times each PID appears
  count(n)           # count how many PIDs have n duplicates

sum(duplicated(combined_R1_Res_1[[id_var]]))

unique(combined_R1_Res_1$PID[duplicated(combined_R1_Res_1$PID)])

#################################
## Further processing of combined_R1_2 PID & name_CHI to ensure no PID duplicates as 
## a result of error in chinese name typing
rm(list=ls())
setwd("C:/Users/OrielTsao/Desktop/COVID-19 RCHEs/DATA/3. Clean Data/R1")

combined_R1_Res_2 <- read_excel("combined_R1_Res_2.xlsx", col_names = TRUE)

## 1. Convert everything to character
combined_R1_Res_2 <- combined_R1_Res_2 %>%
  mutate(across(everything(), as.character))

# ##2 remove all blanks in PID in E933 (as do not have consent)
# combined_R1_Res_2 <- combined_R1_Res_2 %>%
#   filter(!(PID == "" & RCHEID == "E933"))

## 3. merge together duplicated rows to one row (Remarks: no more duplicated PIDs)
combined_R1_Res_3 <- combined_R1_Res_2 %>% 
  # 0. Remove the unwanted column
  select(-name_CHI) %>% 
  # 1. Turn blanks into NA temporarily
  mutate(across(everything(), ~na_if(.x, ""))) %>% 
  # 2. Group by PID
  group_by(PID) %>% 
  # 3. For each column, take the first non-NA value
  summarise(
    across(everything(), ~ first(na.omit(.x)))
  )

## 4. Add new column called round
combined_R1_Res_3$round <- 1

# 5. Remove RCHEID (incomplete) and study no. (duplicated from PID) from nhve. dataset
combined_R1_Res_3 <- combined_R1_Res_3 %>%  select(-ResidentNHVE.RCHE, -`ResidentNHVE.Study no.`)

## 5. Reorder colnames to round, RCHEID, PID, name_CHI
combined_R1_Res_3 <- combined_R1_Res_3 %>%
  select(round, RCHEID, PID, final_name_CHI, everything())

##save combined_R1 into excel
write.xlsx(combined_R1_Res_3, 
           file = "combined_R1_Res_3.xlsx",
           colNames = TRUE,
           rowNames = FALSE)



#############################################################################################
####### REMOVE ALL OBJECTS IN WORKPLACE ########
rm(list=ls())

###ROUND 2.1 ###
#####################################
#### Part 3. Manually add the final variable names as the third header row in raw data
#####################################
#ADDED MANUALLY IN EXCEL named "dataset_finalvar.xlsx

#####################################
#### Part 4. Load raw data, error repot, and all needed files
#####################################

setwd("C:/Users/OrielTsao/Desktop/COVID-19 RCHEs/DATA/1. Raw Data/R2/R2.1 only_Qualtric Download/20251124_finalvar")

## 1. Read the R2 survey files (no col names, because first 3 rows are special)
residenttopup_raw <- read_excel("R2.1_Resident_topup_finalvar.xlsx", col_names = FALSE)
residentmental_raw <- read_excel("R2.1_Resident_mental_finalvar.xlsx", col_names = FALSE)

## 2. Pull out the 3 header rows from a Qualtrics file to be reconstructed later
get_header <- function(df) {
  list(
    stmt1 = as.character(df[1, ]),  # row 1: old var name
    stmt2 = as.character(df[2, ]),  # row 2: question text
    finalvar = as.character(df[3, ])   # row 3: final var name
  )
}

residenttopup_header <- get_header(residenttopup_raw)
residentmental_header <- get_header(residentmental_raw)


#####################################
#### Part 5. Correct raw data according to error repot
#####################################
#NOT APPLICABLE


#####################################
#### Part 6.  Combine datasets within the same round in wide form
#####################################
##3. Only keep and set data colnames to statement 1 for cleaning participant data
clean_pdata <- function(df) {
  finalvar <- as.character(df[3,])
  df_woheader <- df[-(1:3), ]
  names(df_woheader) <- finalvar
  df_woheader
}

residenttopup_clean <- clean_pdata(residenttopup_raw)
residentmental_clean <- clean_pdata(residentmental_raw)

##4 Prep 1 to join surveys within Round: convert everything to character 
#if error: names(resident3_clean)[duplicated(names(resident3_clean))]
residenttopup_clean <- residenttopup_clean %>% mutate(across(everything(), as.character))
residentmental_clean <-residentmental_clean %>% mutate(across(everything(), as.character))


##5 Prep 2 to join survey within Round: set participant ID and merge name_CHI
id_var <- "PID"
RCHEID <- "RCHEID"
name_CHI <- "name_CHI"

#dataset with name_CHI separated into first and last name
lastname <- "name_CHI_1"
firstname <- "name_CHI_2"

#merge name_CHI_1, name_CHI_2 in Resident Topup and Mental survey
merge_name_CHI <- function(df) {
  df %>%
    mutate(name_CHI = paste(name_CHI_1, name_CHI_2, sep = "")) %>%
    select(-name_CHI_1, -name_CHI_2)
}

residenttopup_clean <- merge_name_CHI(residenttopup_clean)
residentmental_clean <- merge_name_CHI(residentmental_clean)


##6 Prep 3: prefix all final var names with dataset origin
## except for the core variable so we can still join by ID and other vars correctly

residenttopup_clean <- residenttopup_clean %>%
  rename_with(~ paste0("ResidentTU.", .x), .cols = -all_of(c(id_var, RCHEID, name_CHI)))

residentmental_clean <- residentmental_clean %>%
  rename_with(~ paste0("ResidentMen.", .x), .cols = -all_of(c(id_var, RCHEID, name_CHI)))

##7 Join surveys within R2 (full join) by PID
#full join keeps everyone in the surveys
combined_R2.1 <- residenttopup_clean %>%
  full_join(residentmental_clean, by = c(id_var, RCHEID, name_CHI))


##8 Sort by ID
combined_R2.1 <- combined_R2.1 %>%
  arrange(.data[[id_var]])

##9. Reorder colnames to round, RCHEID, PID, name_CHI
combined_R2.1 <- combined_R2.1 %>%
  select(RCHEID, PID, name_CHI, everything())

setwd("C:/Users/OrielTsao/Desktop/COVID-19 RCHEs/DATA/3. Clean Data/R2")

##save combined_R2.2 into excel
write.xlsx(combined_R2.1, 
           file = "combined_R2.1_Res_1.xlsx",
           colNames = TRUE,
           rowNames = FALSE)

##QC
combined_R2.1 %>%
  count(PID) %>%     # count how many times each PID appears
  count(n)           # count how many PIDs have n duplicates

sum(duplicated(combined_R2.1[[id_var]]))


#####################################
## Further processing of combined_R2.1_1 PID and name_CHI to ensure no PID duplicates as 
## a result of error in chinese name typing

setwd("C:/Users/OrielTsao/Desktop/COVID-19 RCHEs/DATA/3. Clean Data/R2")
combined_R2.1_2 <- read_excel("combined_R2.1_Res_2.xlsx", col_names = TRUE)

## 1. Convert everything to character
combined_R2.1_2 <- combined_R2.1_2 %>%
  mutate(across(everything(), as.character))

## 2. merge together duplicated rows to one row (none of the duplicated rows overlap)
combined_R2.1_3 <- combined_R2.1_2 %>% 
  # A. Remove the unwanted column
  select(-name_CHI) %>% 
  # B. Turn blanks into NA temporarily
  mutate(across(everything(), ~na_if(.x, ""))) %>% 
  # C. Group by PID
  group_by(PID) %>% 
  # D. For each column, take the first non-NA value
  summarise(
    across(everything(), ~ first(na.omit(.x)))
  )

## 3. Add new column called round
combined_R2.1_3$round <- 2

## 4. Reorder colnames to round, RCHEID, PID, name_CHI
combined_R2.1_3 <- combined_R2.1_3 %>%
  select(round, RCHEID, PID, final_name_CHI, everything())

setwd("C:/Users/OrielTsao/Desktop/COVID-19 RCHEs/DATA/3. Clean Data/R2")
##save combined_R2.1 into excel
write.xlsx(combined_R2.1_3, 
           file = "combined_R2.1_Res_3.xlsx",
           colNames = TRUE,
           rowNames = FALSE)


######################################################################################
####### REMOVE ALL OBJECTS IN WORKPLACE ########
rm(list=ls())

##ROUND 2.2 ###
#####################################
#### Part 3. Manually add the final variable names as the third header row in raw data
#####################################
#ADDED MANUALLY IN EXCEL named "dataset_finalvar.xlsx

#####################################
#### Part 4. Load raw data, error repot, and all needed files
#####################################
setwd("C:/Users/OrielTsao/Desktop/COVID-19 RCHEs/DATA/1. Raw Data/R2/R2 and R3_Qualtric Download/20251124_withfinalvarname")

## Read the R2 survey files (no col names, because first 3 rows are special)
resident1_raw <- read_excel("Resident1_finalvar.xlsx", col_names = FALSE)
resident2_raw <- read_excel("Resident2_finalvar.xlsx", col_names = FALSE)
resident3_raw <- read_excel("Resident3_finalvar.xlsx", col_names = FALSE)
resident4_raw <- read_excel("Resident4_finalvar.xlsx", col_names = FALSE)
resident5_raw <- read_excel("Resident5_finalvar.xlsx", col_names = FALSE)
resident6_raw <- read_excel("Resident6_finalvar.xlsx", col_names = FALSE)
residentMC_raw <- read_excel("ResidentMC_finalvar.xlsx", col_names = FALSE)

#####################################
#### Part 5. Correct raw data according to error repot
#####################################
#1. DOB_DATE
#R2
#E001-1-031
idx <- which(resident5_raw$`...20` == "E001-1-031" & resident5_raw$`...18` == 2) #`...20` = PID, `...18` = round
resident5_raw$`...30`[idx] <- "1945" # `...30` = dob_yyyy
resident5_raw$`...30`[idx] <- "12" # `...30` = dob_mm
resident5_raw$`...30`[idx] <- "20" # `...30` = dob_dd

#E917-1-010
idx <- which(resident5_raw$`...20` == "E917-1-010" & resident5_raw$`...18` == 2) #`...20` = PID, `...18` = round
resident5_raw$`...30`[idx] <- "1958" # `...30` = dob_yyyy
resident5_raw$`...30`[idx] <- "02" # `...30` = dob_mm
resident5_raw$`...30`[idx] <- "02" # `...30` = dob_dd

#E923-1-037
idx <- which(resident5_raw$`...20` == "E923-1-037" & resident5_raw$`...18` == 2) #`...20` = PID, `...18` = round
resident5_raw$`...30`[idx] <- "1951" # `...30` = dob_yyyy
resident5_raw$`...30`[idx] <- "10" # `...30` = dob_mm
resident5_raw$`...30`[idx] <- "10" # `...30` = dob_dd

#E929-1-014
idx <- which(resident5_raw$`...20` == "E929-1-014" & resident5_raw$`...18` == 2) #`...20` = PID, `...18` = round
resident5_raw$`...30`[idx] <- "1950" # `...30` = dob_yyyy
resident5_raw$`...30`[idx] <- "11" # `...30` = dob_mm
resident5_raw$`...30`[idx] <- "21" # `...30` = dob_dd

#E929-1-021
idx <- which(resident5_raw$`...20` == "E929-1-021" & resident5_raw$`...18` == 2) #`...20` = PID, `...18` = round
resident5_raw$`...30`[idx] <- "1950" # `...30` = dob_yyyy
resident5_raw$`...30`[idx] <- "06" # `...30` = dob_mm
resident5_raw$`...30`[idx] <- "12" # `...30` = dob_dd

#E929-1-023
idx <- which(resident5_raw$`...20` == "E929-1-023" & resident5_raw$`...18` == 2) #`...20` = PID, `...18` = round
resident5_raw$`...30`[idx] <- "1959" # `...30` = dob_yyyy
resident5_raw$`...30`[idx] <- "07" # `...30` = dob_mm
resident5_raw$`...30`[idx] <- "13" # `...30` = dob_dd

#E936-1-016
idx <- which(resident5_raw$`...20` == "E936-1-016" & resident5_raw$`...18` == 2) #`...20` = PID, `...18` = round
resident5_raw$`...30`[idx] <- "1925" # `...30` = dob_yyyy
resident5_raw$`...30`[idx] <- "10" # `...30` = dob_mm
resident5_raw$`...30`[idx] <- "25" # `...30` = dob_dd

#E936-1-037
idx <- which(resident5_raw$`...20` == "E936-1-037" & resident5_raw$`...18` == 2) #`...20` = PID, `...18` = round
resident5_raw$`...30`[idx] <- "1961" # `...30` = dob_yyyy
resident5_raw$`...30`[idx] <- "07" # `...30` = dob_mm
resident5_raw$`...30`[idx] <- "11" # `...30` = dob_dd

#E947-1-003
idx <- which(resident5_raw$`...20` == "E947-1-003" & resident5_raw$`...18` == 2) #`...20` = PID, `...18` = round
resident5_raw$`...30`[idx] <- "1954" # `...30` = dob_yyyy
resident5_raw$`...30`[idx] <- "04" # `...30` = dob_mm
resident5_raw$`...30`[idx] <- "08" # `...30` = dob_dd

#E950-1-002
idx <- which(resident5_raw$`...20` == "E950-1-002" & resident5_raw$`...18` == 2) #`...20` = PID, `...18` = round
resident5_raw$`...30`[idx] <- "1954" # `...30` = dob_yyyy
resident5_raw$`...30`[idx] <- "03" # `...30` = dob_mm
resident5_raw$`...30`[idx] <- "26" # `...30` = dob_dd

#####################################
#### Part 6.  Combine datasets within the same round in wide form
#####################################
## 2. Pull out the 3 header rows from a Qualtrics file to be reconstructed later
get_header <- function(df) {
  list(
    stmt1 = as.character(df[1, ]),  # row 1: old var name
    stmt2 = as.character(df[2, ]),  # row 2: question text
    finalvar = as.character(df[3, ])   # row 3: final var name
  )
}

resident1_header <- get_header(resident1_raw)
resident2_header <- get_header(resident2_raw)
resident3_header <- get_header(resident3_raw)
resident4_header <- get_header(resident4_raw)
resident5_header <- get_header(resident5_raw)
resident6_header <- get_header(resident6_raw)
residentMC_header <- get_header(residentMC_raw)

##3. Only keep and set data colnames to statement 1 for cleaning participant data
clean_pdata <- function(df) {
  finalvar <- as.character(df[3,])
  df_woheader <- df[-(1:3), ]
  names(df_woheader) <- finalvar
  df_woheader
}

resident1_clean <- clean_pdata(resident1_raw)
resident2_clean <- clean_pdata(resident2_raw)
resident3_clean <- clean_pdata(resident3_raw)
resident4_clean <- clean_pdata(resident4_raw)
resident5_clean <- clean_pdata(resident5_raw)
resident6_clean <- clean_pdata(resident6_raw)
residentMC_clean <- clean_pdata(residentMC_raw)

##4 Prep 1 to join surveys within Round: convert everything to character 
#error: names(resident5_clean )[duplicated(names(resident5_clean ))]
resident1_clean <- resident1_clean %>% mutate(across(everything(), as.character))
resident2_clean <-resident2_clean %>% mutate(across(everything(), as.character))
resident3_clean <- resident3_clean %>% mutate(across(everything(), as.character))
resident4_clean <- resident4_clean %>% mutate(across(everything(), as.character))
resident5_clean <- resident5_clean %>% mutate(across(everything(), as.character))
resident6_clean <- resident6_clean %>% mutate(across(everything(), as.character))
residentMC_clean <- residentMC_clean %>% mutate(across(everything(), as.character))

## 4A. Include only Round 2 Participants
R2_resident1_clean <- resident1_clean %>% filter(round == '2')
R2_resident2_clean <- resident2_clean %>% filter(round == '2')
R2_resident3_clean <- resident3_clean %>% filter(round == '2')
R2_resident4_clean <- resident4_clean %>% filter(round == '2')
R2_resident5_clean <- resident5_clean %>% filter(round == '2')
R2_resident6_clean <- resident6_clean %>% filter(round == '2')
R2_residentMC_clean <- residentMC_clean %>% filter(round == '2')

##5 Prep 2 to join survey within Round: set participant ID and merge name_CHI
id_var <- "PID"
RCHEID <- "RCHEID"
round <- "round"
name_CHI <- "name_CHI"
#dataset with name_CHI separated into first and last name
lastname <- "name_CHI_1"
firstname <- "name_CHI_2"

#merge name_CHI_1 and name_CHI_2 in Resident1, 4, 5, 6 dataset
merge_name_CHI <- function(df) {
  df %>%
    mutate(name_CHI = paste(name_CHI_1, name_CHI_2, sep = "")) %>%
    select(-name_CHI_1, -name_CHI_2)
}

R2_resident1_clean <- merge_name_CHI(R2_resident1_clean)
R2_resident4_clean <- merge_name_CHI(R2_resident4_clean)
R2_resident5_clean <- merge_name_CHI(R2_resident5_clean)
R2_resident6_clean <- merge_name_CHI(R2_resident6_clean)


##6 Prep 3: Prefix all final var names with dataset origin
## except for the core variable so we can still join by ID and other vars correctly

#list of all var with no prefix
noprefix_var <- c(id_var, RCHEID, round, name_CHI)

R2_resident1_clean <- R2_resident1_clean %>%
  rename_with(~ paste0("Resident1.", .x), .cols = -all_of(noprefix_var))
R2_resident2_clean <- R2_resident2_clean %>%
  rename_with(~ paste0("Resident2.", .x), .cols = -all_of(noprefix_var))
R2_resident3_clean <- R2_resident3_clean %>%
  rename_with(~ paste0("Resident3.", .x), .cols = -all_of(c(id_var, RCHEID, round)))
R2_resident4_clean <- R2_resident4_clean %>%
  rename_with(~ paste0("Resident4.", .x), .cols = -all_of(noprefix_var))
R2_resident5_clean <- R2_resident5_clean %>%
  rename_with(~ paste0("Resident5.", .x), .cols = -all_of(noprefix_var))
R2_resident6_clean <- R2_resident6_clean %>%
  rename_with(~ paste0("Resident6.", .x), .cols = -all_of(noprefix_var))
R2_residentMC_clean <- R2_residentMC_clean %>%
  rename_with(~ paste0("ResidentnMC.", .x), .cols = -all_of(noprefix_var))

##7 Join surveys within R2 (full join) by PID
# full join keeps everyone in the surveys
combined_R2.2 <- R2_resident1_clean %>%
  full_join(R2_resident2_clean, by = c(id_var, RCHEID, round, name_CHI)) %>%
  full_join(R2_resident3_clean, by = c(id_var, RCHEID, round)) %>%
  full_join(R2_resident4_clean, by = c(id_var, RCHEID, round, name_CHI)) %>%
  full_join(R2_resident5_clean, by = c(id_var, RCHEID, round, name_CHI)) %>%
  full_join(R2_resident6_clean, by = c(id_var, RCHEID, round, name_CHI)) %>%
  full_join(R2_residentMC_clean, by = c(id_var, RCHEID, round, name_CHI))

##8 Sort by ID
combined_R2.2 <- combined_R2.2 %>%
  arrange(.data[[id_var]])

##9. Reorder colnames to round, RCHEID, PID, name_CHI
combined_R2.2 <- combined_R2.2 %>%
  select(round, RCHEID, PID, name_CHI, everything())

##save combined_R2.2 into excel
setwd("C:/Users/OrielTsao/Desktop/COVID-19 RCHEs/DATA/3. Clean Data/R2")

write.xlsx(combined_R2.2, 
           file = "combined_R2.2_Res_1.xlsx",
           colNames = TRUE,
           rowNames = FALSE)

##QC
combined_R2.2 %>%
  count(PID) %>%     # count how many times each PID appears
  count(n)           # count how many PIDs have n duplicates

sum(duplicated(combined_R2.2[[id_var]]))

#####################################
## Further processing of combined_R2.2_2 PID & name_CHI to ensure no PID duplicates as 
## a result of error in chinese name typing
setwd("C:/Users/OrielTsao/Desktop/COVID-19 RCHEs/DATA/3. Clean Data/R2")
combined_R2.2_2 <- read_excel("combined_R2.2_Res_2.xlsx", col_names = TRUE)

## 1. Convert everything to character
combined_R2.2_2 <- combined_R2.2_2 %>%
  mutate(across(everything(), as.character))

## 2. merge together duplicated rows to one row (none of the duplicated rows overlap)
combined_R2.2_3 <- combined_R2.2_2 %>% 
  # A. Remove the unwanted column
  select(-name_CHI) %>% 
  # B. Turn blanks into NA temporarily
  mutate(across(everything(), ~na_if(.x, ""))) %>% 
  # C. Group by PID
  group_by(PID) %>% 
  # D. For each column, take the first non-NA value
  summarise(
    across(everything(), ~ first(na.omit(.x)))
  )

## 3. Reorder colnames to round, RCHEID, PID, name_CHI
combined_R2.2_3 <- combined_R2.2_3 %>%
  select(round, RCHEID, PID, final_name_CHI, everything())

##save combined_R2.2 into excel
write.xlsx(combined_R2.2_3, 
           file = "combined_R2.2_Res_3.xlsx",
           colNames = TRUE,
           rowNames = FALSE)

#################################################################################
###ROUND 2.1 & 2.2 QC ####
#1. Check presence of overlap
id_var <- "PID"
any(combined_R2.1_3[[id_var]] %in% combined_R2.2_3[[id_var]])

#2. If yes presence of overlap, which PIDs overlap?
intersect(combined_R2.1_3[[id_var]], combined_R2.2_3[[id_var]])

#3. Table overlap in R2.1 and R2.2
table(df1 = combined_R2.1_3[[id_var]] %in% combined_R2.1_3[[id_var]])

##RESULT: All 77 residents in R2.1 overlaps with R2.2 (As Expected)
#due R2.1 participants that fill in resident 3 surveys

##################################################################################
####### REMOVE ALL OBJECTS IN WORKPLACE ########
rm(list=ls())

## MERGING R2.1 and R2.2 dataset (simple join by PID) 
### Remarks: no within-round var merging + fixing naming inconsistency between R2.1 & R2.2

setwd("C:/Users/OrielTsao/Desktop/COVID-19 RCHEs/DATA/3. Clean Data/R2")

combined_R2.1_Res <- read_excel("combined_R2.1_Res_3.xlsx",col_names = TRUE)
combined_R2.2_Res <- read_excel("combined_R2.2_Res_3.xlsx",col_names = TRUE)


##1. Make sure everything is character (avoid type issues when joining)
combined_R2.1_Res <- combined_R2.1_Res %>%
  mutate(across(everything(), as.character))

combined_R2.2_Res <- combined_R2.2_Res %>%
  mutate(across(everything(), as.character))

##2. Set ID variable for joining
id_var <- "PID"
RCHEID <- "RCHEID"
round <- "round"
final_name_CHI <- "final_name_CHI"

##3. Join R2.1 and R2.2 side by side by PID (keep anyone who did at least one)
combined_R2_Res_1 <- full_join(combined_R2.1_Res,
                             combined_R2.2_Res,
                             by = c(round, RCHEID, id_var, final_name_CHI))

#rename final_name_CHI column to not_final_name_CHI and arrange PID
combined_R2_Res_1 <- combined_R2_Res_1 %>%
  rename(not_final_name_CHI = final_name_CHI) %>%
  arrange(PID)

setwd("C:/Users/OrielTsao/Desktop/COVID-19 RCHEs/DATA/3. Clean Data/R2")
write.xlsx(combined_R2_Res_1, 
           file = "combined_R2_Res_1.xlsx",
           colNames = TRUE,
           rowNames = FALSE)

##QC - 9 duplicates PID
combined_R2_Res_1 %>%
  count(PID) %>%     # count how many times each PID appears
  count(n)           # count how many PIDs have n duplicates

#####################################
## Further processing of combined_R2 PID & name_CHI to ensure no PID duplicates as 
## a result of error in chinese name typing
setwd("C:/Users/OrielTsao/Desktop/COVID-19 RCHEs/DATA/3. Clean Data/R2")
combined_R2_Res_2 <- read_excel("combined_R2_Res_2.xlsx", col_names = TRUE)

## 1. Convert everything to character
combined_R2_Res_2 <- combined_R2_Res_2 %>%
  mutate(across(everything(), as.character))

## 2. merge together duplicated rows to one row (none of the duplicated rows overlap)
combined_R2_Res_3 <- combined_R2_Res_2 %>% 
  # A. Remove the unwanted column
  select(-not_final_name_CHI) %>% 
  # B. Turn blanks into NA temporarily
  mutate(across(everything(), ~na_if(.x, ""))) %>% 
  # C. Group by PID
  group_by(PID) %>% 
  # D. For each column, take the first non-NA value
  summarise(
    across(everything(), ~ first(na.omit(.x)))
  )

## 3. Reorder colnames to round, RCHEID, PID, name_CHI
combined_R2_Res_3 <- combined_R2_Res_3 %>%
  select(round, RCHEID, PID, final_name_CHI, everything())

##save final combined_R2 into excel
write.xlsx(combined_R2_Res_3, 
           file = "combined_R2_Res_3.xlsx",
           colNames = TRUE,
           rowNames = FALSE)

##QC - no more PID duplicates
combined_R2_Res_3 %>%
  count(PID) %>%     # count how many times each PID appears
  count(n)           # count how many PIDs have n duplicates
##################################################################################
####### REMOVE ALL OBJECTS IN WORKPLACE ########
rm(list=ls())

###ROUND 3###

#####################################
#### Part 3. Manually add the final variable names as the third header row in raw data
#####################################
##DONE IN EXCEL MANUALLY

#####################################
#### Part 4. Load raw data, error repot, and all needed files
#####################################
#load df (same df for R2.2 and R3)
setwd("C:/Users/OrielTsao/Desktop/COVID-19 RCHEs/DATA/1. Raw Data/R2/R2 and R3_Qualtric Download/20251124_withfinalvarname")

## 1. Read the R2 survey files (no col names, because first 3 rows are special)
resident1_raw <- read_excel("Resident1_finalvar.xlsx", col_names = FALSE)
resident2_raw <- read_excel("Resident2_finalvar.xlsx", col_names = FALSE)
resident3_raw <- read_excel("Resident3_finalvar.xlsx", col_names = FALSE)
resident4_raw <- read_excel("Resident4_finalvar.xlsx", col_names = FALSE)
resident5_raw <- read_excel("Resident5_finalvar.xlsx", col_names = FALSE)
resident6_raw <- read_excel("Resident6_finalvar.xlsx", col_names = FALSE)
residentMC_raw <- read_excel("ResidentMC_finalvar.xlsx", col_names = FALSE)

#####################################
#### Part 5. Correct raw data according to error repot
#####################################
#NOT APPLICABLE

#####################################
#### Part 6.  Combine datasets within the same round in wide form
#####################################

## 2. Pull out the 3 header rows from a Qualtrics file to be reconstructed later
get_header <- function(df) {
  list(
    stmt1 = as.character(df[1, ]),  # row 1: old var name
    stmt2 = as.character(df[2, ]),  # row 2: question text
    finalvar = as.character(df[3, ])   # row 3: final var name
  )
}

resident1_header <- get_header(resident1_raw)
resident2_header <- get_header(resident2_raw)
resident3_header <- get_header(resident3_raw)
resident4_header <- get_header(resident4_raw)
resident5_header <- get_header(resident5_raw)
resident6_header <- get_header(resident6_raw)
residentMC_header <- get_header(residentMC_raw)

##3. Only keep and set data colnames to statement 1 for cleaning participant data
clean_pdata <- function(df) {
  finalvar <- as.character(df[3,])
  df_woheader <- df[-(1:3), ]
  names(df_woheader) <- finalvar
  df_woheader
}

resident1_clean <- clean_pdata(resident1_raw)
resident2_clean <- clean_pdata(resident2_raw)
resident3_clean <- clean_pdata(resident3_raw)
resident4_clean <- clean_pdata(resident4_raw)
resident5_clean <- clean_pdata(resident5_raw)
resident6_clean <- clean_pdata(resident6_raw)
residentMC_clean <- clean_pdata(residentMC_raw)

##4 Prep 1 to join surveys within Round: convert everything to character 
resident1_clean <- resident1_clean %>% mutate(across(everything(), as.character))
resident2_clean <-resident2_clean %>% mutate(across(everything(), as.character))
resident3_clean <- resident3_clean %>% mutate(across(everything(), as.character))
resident4_clean <- resident4_clean %>% mutate(across(everything(), as.character))
resident5_clean <- resident5_clean %>% mutate(across(everything(), as.character))
resident6_clean <- resident6_clean %>% mutate(across(everything(), as.character))
residentMC_clean <- residentMC_clean %>% mutate(across(everything(), as.character))

##4A. Include only Round 2 Participants
R3_resident1_clean <- resident1_clean %>% filter(round == '3')
R3_resident2_clean <- resident2_clean %>% filter(round == '3')
R3_resident3_clean <- resident3_clean %>% filter(round == '3')
R3_resident4_clean <- resident4_clean %>% filter(round == '3')
R3_resident5_clean <- resident5_clean %>% filter(round == '3')
R3_resident6_clean <- resident6_clean %>% filter(round == '3')
R3_residentMC_clean <- residentMC_clean %>% filter(round == '3')

#5 Prep 2 to join survey within Round: set participant ID and merge name_CHI
id_var <- "PID"
RCHEID <- "RCHEID"
round <- "round"
name_CHI <- "name_CHI"
#dataset with name_CHI separated into first and last name
lastname <- "name_CHI_1"
firstname <- "name_CHI_2"

#merge name_CHI_1 and name_CHI_2 in Resident1, 4, 5, 6 dataset
merge_name_CHI <- function(df) {
  df %>%
    mutate(name_CHI = paste(name_CHI_1, name_CHI_2, sep = "")) %>%
    select(-name_CHI_1, -name_CHI_2)
}

R3_resident1_clean <- merge_name_CHI(R3_resident1_clean)
R3_resident4_clean <- merge_name_CHI(R3_resident4_clean)
R3_resident5_clean <- merge_name_CHI(R3_resident5_clean)
R3_resident6_clean <- merge_name_CHI(R3_resident6_clean)


##6 Prep 3: prefix all final var names with dataset origin
## except for the core variable so we can still join by ID and other vars correctly

#list of all var with no prefix
noprefix_var <- c(id_var, RCHEID, round, name_CHI)

R3_resident1_clean <- R3_resident1_clean %>%
  rename_with(~ paste0("Resident1.", .x), .cols = -all_of(noprefix_var))
R3_resident2_clean <- R3_resident2_clean %>%
  rename_with(~ paste0("Resident2.", .x), .cols = -all_of(noprefix_var))
R3_resident3_clean <- R3_resident3_clean %>%
  rename_with(~ paste0("Resident3.", .x), .cols = -all_of(c(id_var, RCHEID, round)))
R3_resident4_clean <- R3_resident4_clean %>%
  rename_with(~ paste0("Resident4.", .x), .cols = -all_of(noprefix_var))
R3_resident5_clean <- R3_resident5_clean %>%
  rename_with(~ paste0("Resident5.", .x), .cols = -all_of(noprefix_var))
R3_resident6_clean <- R3_resident6_clean %>%
  rename_with(~ paste0("Resident6.", .x), .cols = -all_of(noprefix_var))
R3_residentMC_clean <- R3_residentMC_clean %>%
  rename_with(~ paste0("ResidentnMC.", .x), .cols = -all_of(noprefix_var))

##7 Join surveys within R3 (full join) by PID
#full join keeps everyone in the surveys
combined_R3 <- R3_resident1_clean %>%
  full_join(R3_resident2_clean, by = c(id_var, RCHEID, round, name_CHI)) %>%
  full_join(R3_resident3_clean, by = c(id_var, RCHEID, round)) %>%
  full_join(R3_resident4_clean, by = c(id_var, RCHEID, round, name_CHI)) %>%
  full_join(R3_resident5_clean, by = c(id_var, RCHEID, round, name_CHI)) %>%
  full_join(R3_resident6_clean, by = c(id_var, RCHEID, round, name_CHI)) %>%
  full_join(R3_residentMC_clean, by = c(id_var, RCHEID, round, name_CHI))

##8 Sort by ID
combined_R3 <- combined_R3 %>%
  arrange(.data[[id_var]])

##9. Reorder colnames to round, RCHEID, PID, name_CHI
combined_R3 <- combined_R3 %>%
  select(round, RCHEID, PID, name_CHI, everything())

##save combined_R3 into excel

setwd("C:/Users/OrielTsao/Desktop/COVID-19 RCHEs/DATA/3. Clean Data/R3")

write.xlsx(combined_R3, 
           file = "combined_R3_Res_1.xlsx",
           colNames = TRUE,
           rowNames = FALSE)
##QC
combined_R3 %>%
  count(PID) %>%     # count how many times each PID appears
  count(n)           # count how many PIDs have n duplicates

sum(duplicated(combined_R3[[id_var]]))

#####################################
## Further processing of combined_R3 PID & name_CHI to ensure no PID duplicates as 
## a result of error in chinese name typing
setwd("C:/Users/OrielTsao/Desktop/COVID-19 RCHEs/DATA/3. Clean Data/R3")

combined_R3_2 <- read_excel("combined_R3_Res_2.xlsx", col_names = TRUE)

## 1. Convert everything to character
combined_R3_2 <- combined_R3_2 %>%
  mutate(across(everything(), as.character))

## 2. merge together duplicated rows to one row (none of the duplicated rows overlap)
combined_R3_3 <- combined_R3_2 %>% 
  # A. Remove the unwanted column
  select(-name_CHI) %>% 
  # B. Turn blanks into NA temporarily
  mutate(across(everything(), ~na_if(.x, ""))) %>% 
  # C. Group by PID
  group_by(PID) %>% 
  # D. For each column, take the first non-NA value
  summarise(
    across(everything(), ~ first(na.omit(.x)))
  )

## 3. Reorder colnames to round, RCHEID, PID, name_CHI
combined_R3_3 <- combined_R3_3 %>%
  select(round, RCHEID, PID, final_name_CHI, everything())

##save combined_R3 into excel
setwd("C:/Users/OrielTsao/Desktop/COVID-19 RCHEs/DATA/3. Clean Data/R3")
write.xlsx(combined_R3_3, 
           file = "combined_R3_Res_3.xlsx",
           colNames = TRUE,
           rowNames = FALSE)

##QC # Not more duplicates
combined_R3_3 %>%
  count(PID) %>%     # count how many times each PID appears
  count(n)           # count how many PIDs have n duplicates

sum(duplicated(combined_R3_3[[id_var]]))

#####################################
#### Part 7. Combine datasets across rounds
#####################################
#NOT APPLICABLE for RESIDENTS (due to R1 issue resolved in Part 10)

#####################################
#### Part 8. Re-position columns by category and (within category) by similarity
#####################################
#NOT APPLICABLE, native format in survey already by category

#####################################
#### Part 9.  Prior validation for separate files
#####################################
# Vetting condcted in EXCEL

##END of Part 1 - 9 
