#####################################
#### Part 1.  Coding consensus
#####################################
#[NOT APPLICABLE]

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
library(janitor)
library(lubridate)
################################################################################
####### REMOVE ALL OBJECTS IN WORKPLACE ########
rm(list=ls())

##ROUND 1 ###
#####################################
#### Part 3. Manually add the final variable names as the third header row in raw data
#####################################
#NOT APPLICABLE TO ROUND 1

#####################################
#### Part 4. Load raw data, error repot, and all needed files
#####################################

## 1. Read the R1 survey files (keep statement1 as col names)
setwd("C:/Users/OrielTsao/Desktop/COVID-19 RCHEs/DATA/1. Raw Data/R1/Qualtric Download/20251124_missingentered")

staff_raw <- read_excel("EVAX_STAFF.xlsx", col_names = TRUE)

setwd("C:/Users/OrielTsao/Desktop/COVID-19 RCHEs/DATA/1. Raw Data/R1/Other datasets")

staffMINI_raw <- read_excel("MINI_Staff_dated20221228.xlsx", col_names = FALSE) 

#####################################
#### Part 5. Correct raw data according to error report
#####################################
#NOT APPLICABLE

#####################################
#### Part 6.  Combine datasets within the same round in wide form
#####################################

## 2. Remove statement2 from header
##EVAX_Staff 
rm_stat2 <- function(df) {
  df_wostat2 <- df[-(1), ] #df[1,] is statement 2, statement 1 is colname
  df_wostat2
}

staff_clean <- rm_stat2(staff_raw)

##MINI - row 2 is header
#col_names = FALSE
header_row2 <- function(df) {
  # 1. Set row 3 as column names
  colnames(df) <- as.character(unlist(df[2, ]))
  # 2. Remove rows 1 to 3
  df <- df[-(1:2), ]
  return(df)
}

staffMINI_clean <- header_row2(staffMINI_raw)


##3 Prep 1 to join surveys within Round: convert everything to character 
#if error: names(resident3_clean)[duplicated(names(resident3_clean))]
staff_clean <- staff_clean %>% mutate(across(everything(), as.character))
staffMINI_clean <- staffMINI_clean %>% mutate(across(everything(), as.character))


##4 Prep 2: make sure core joining variable are the same
#first is new_name, after = is old_name
staffMINI_clean <- staffMINI_clean %>% 
  rename(PID = sid) %>% 
  rename(name_CHI = cname)


##5. Prep 3: Convert format of vactype (R1 MINI) to CVD1_type, CVD2_type, etc.
staffMINI_clean <- staffMINI_clean %>%
  mutate(
    CVd1_type = case_when(
      vactype == 1 & vacnum >= 1 ~ "Sinovac",   # has at least dose 1
      vactype == 2 & vacnum >= 1 ~ "BioNTech",
      vactype == 3 ~ "Sinovac",
      vactype == 4 ~ "Sinovac",
      vactype == 5 ~ "BioNTech",
      vactype == 6 ~ "BioNTech",
      vactype == 7 ~ "Sinovac",
      vactype == 8 ~ "Sinovac",
      vactype == 9 ~ "Sinopharm",
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
      vactype == 8 ~ "Sinopharm",
      vactype == 9 ~ "Sinovac",
      TRUE ~ NA_character_
    ),
    CVd3_type = case_when(
      vactype == 1 & vacnum >= 3 ~ "Sinovac",   # has at least dose 3
      vactype == 2 & vacnum >= 3 ~ "BioNTech",
      vactype == 3 ~ "BioNTech",
      vactype == 4 ~ "Sinovac",
      vactype == 5 ~ "Sinovac",
      vactype == 6 ~ "BioNTech",
      vactype == 7 ~ "BioNTech",
      vactype == 8 ~ "Sinopharm",
      vactype == 9 ~ "Sinovac",
      TRUE ~ NA_character_
    ),
    CVd4_type = case_when(
      vactype == 1 & vacnum >= 4 ~ "Sinovac",   # has at least dose 4
      vactype == 2 & vacnum >= 4 ~ "BioNTech",
      vactype == 4 ~ "BioNTech",
      vactype == 6 ~ "Sinovac",
      vactype == 7 ~ "BioNTech",
      vactype == 9 ~ "Sinovac",
      TRUE ~ NA_character_
    )
  )

#QC check prep 3 (i.e. E910-1-003 R1-R3 Sinovac TRUE)
staffMINI_try <- staffMINI_clean %>% 
  select(PID, starts_with("CVd") & ends_with("type"))

##6 Prep 4: prefix all final var names with dataset origin
## except for the core variable so we can still join by ID and other vars correctly
id_var <- "PID"
RCHEID <- "RCHEID"
name_CHI <- "name_CHI"

staff_clean <- staff_clean %>%
  rename_with(~ paste0("STAFF.", .x), .cols = -all_of(c(id_var, RCHEID, name_CHI)))

staffMINI_clean <- staffMINI_clean  %>%
  rename_with(~ paste0("StaffMINI.", .x), .cols = -all_of(c(id_var, name_CHI)))



##6 Join surveys within R1 (full join) by PID
#full join keeps everyone in the surveys
combined_R1_Staf_1 <- staff_clean %>%
  full_join(staffMINI_clean, by = c(id_var, name_CHI)) 

## 7. Add new column called round
combined_R1_Staf_1$round <- 1

##8 Sort by ID
combined_R1_Staf_1 <- combined_R1_Staf_1 %>%
  arrange(.data[[id_var]])

##7. Reorder colnames to round, RCHEID, PID, name_CHI
combined_R1_Staf_1 <- combined_R1_Staf_1 %>%
  select(round, RCHEID, PID, name_CHI, everything())

setwd("C:/Users/OrielTsao/Desktop/COVID-19 RCHEs/DATA/3. Clean Data/R1")
##save combined_R2.2 into excel
write.xlsx(combined_R1_Staf_1, 
           file = "combined_R1_Staf_1.xlsx",
           colNames = TRUE,
           rowNames = FALSE)

##QC
combined_R1_Staf_1 %>%
  count(PID) %>%     # count how many times each PID appears (46 unique PID duplicated)
  count(n)           # count how many PIDs have n duplicates

sum(duplicated(combined_R1_Staf_1[[id_var]]))


## Further processing of PID and chinese name to ensure no PID duplicates as 
## a result of error in chinese name typing

setwd("C:/Users/OrielTsao/Desktop/COVID-19 RCHEs/DATA/3. Clean Data/R1")

combined_R1_Staf_2 <- read_excel("combined_R1_Staf_2.xlsx", col_names = TRUE)

## 1. Convert everything to character
combined_R1_Staf_2 <- combined_R1_Staf_2 %>%
  mutate(across(everything(), as.character))


## 2. merge together duplicated rows to one row (Remarks: no more duplicated PIDs)
combined_R1_Staf_3 <- combined_R1_Staf_2 %>% 
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

##3. Further QC## to ensure no duplicates
combined_R1_Staf_3 %>%
  count(PID) %>%     # count how many times each PID appears (46 unique PID duplicated)
  count(n)           # count how many PIDs have n duplicates

## 4. Add new column called round
combined_R1_Staf_3$round <- 1

## 5. Reorder colnames to round, RCHEID, PID, name_CHI
combined_R1_Staf_3 <- combined_R1_Staf_3 %>%
  select(round, RCHEID, PID, final_name_CHI, everything())

##save combined_R2.2 into excel
write.xlsx(combined_R1_Staf_3, 
           file = "combined_R1_Staf_3.xlsx",
           colNames = TRUE,
           rowNames = FALSE)


##################################################################################
##################################################################################
####### REMOVE ALL OBJECTS IN WORKPLACE ########
rm(list=ls())

##ROUND 2.1 ###

#####################################
#### Part 3.  Add the final variable names as the third header row in raw data
#####################################
#MANUALLY ADDED FINAL VAR TO EXCEL

#####################################
#### Part 4 Load raw data, error repot, and all needed files
#####################################

setwd("C:/Users/OrielTsao/Desktop/COVID-19 RCHEs/DATA/1. Raw Data/R2/R2.1 only_Qualtric Download/20251124_finalvar")

## 1. Read the R2 survey files (no col names, because first 3 rows are special)
residentstaff_raw <- read_excel("R2.1_Staff_finalvar.xlsx", col_names = FALSE)

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

residentstaff_header <- get_header(residentstaff_raw)


##3. Only keep and set data colnames to statement 1 for cleaning participant data
clean_pdata <- function(df) {
  finalvar <- as.character(df[3,])
  df_woheader <- df[-(1:3), ]
  names(df_woheader) <- finalvar
  df_woheader
}

residentstaff_clean <- clean_pdata(residentstaff_raw)

##4 Prep 1 for processing - change to characters
#if error: names(resident3_clean)[duplicated(names(resident3_clean))]
residentstaff_clean <- residentstaff_clean %>% mutate(across(everything(), as.character))


##5 Prep 2: set participant ID and merge name_CHI
id_var <- "PID"
RCHEID <- "RCHEID"
name_CHI <- "name_CHI"
final_name_CHI <- "final_name_CHI"
#dataset with name_CHI separated into first and last name
lastname <- "name_CHI_1"
firstname <- "name_CHI_2"

#merge name_CHI_1, name_CHI_2 in Resident Topup and Mental survey
merge_name_CHI <- function(df) {
  df %>%
    mutate(final_name_CHI = paste(name_CHI_1, name_CHI_2, sep = "")) %>%
    select(-name_CHI_1, -name_CHI_2)
}

residentstaff_clean <- merge_name_CHI(residentstaff_clean)

##6 Prep 3: prefix all final var names with dataset origin
## except for the core variable so we can still join by ID and other vars correctly

residentstaff_clean <- residentstaff_clean %>%
  rename_with(~ paste0("R2.1StaffBasic.", .x), .cols = -all_of(c(id_var, RCHEID, final_name_CHI)))

##7 Sort by ID
residentstaff_clean <- residentstaff_clean %>%
  arrange(.data[[id_var]])


## 8. Add new column called round
residentstaff_clean$round <- 2

##9. Reorder colnames to RCHEID, PID, final_name_CHI
residentstaff_clean <- residentstaff_clean %>%
  select(round, RCHEID, PID, final_name_CHI, everything())

setwd("C:/Users/OrielTsao/Desktop/COVID-19 RCHEs/DATA/3. Clean Data/R2/")

##save combined_R2.1 into excel
write.xlsx(residentstaff_clean, 
           file = "combined_R2.1_Staf_1.xlsx",     #directly can concert to final.xlsx
           colNames = TRUE,
           rowNames = FALSE)


##QC
residentstaff_clean %>%
  count(PID) %>%     # count how many times each PID appears
  count(n)           # count how many PIDs have n duplicates

sum(duplicated(residentstaff_clean[[id_var]]))
#RESULTS: No duplicates hence final_name_CHI instead of name_CHI

##################################################################################
####### REMOVE ALL OBJECTS IN WORKPLACE ########
rm(list=ls())

##ROUND 2.2 ###

#####################################
#### Part 3. Manually add the final variable names as the third header row in raw data
#####################################
#MANUALLY ADDED TO EXCEL

#####################################
#### Part 4. Load raw data, error repot, and all needed files
#####################################

setwd("C:/Users/OrielTsao/Desktop/COVID-19 RCHEs/DATA/1. Raw Data/R2/R2 and R3_Qualtric Download/20251124_withfinalvarname")

## 1. Read the two R2 survey files (no col names, because first 3 rows are special)
staff1_raw <- read_excel("Staff1_finalvar.xlsx", col_names = FALSE)
staff2_raw <- read_excel("Staff2_finalvar.xlsx", col_names = FALSE)
staff2.2_raw <- read_excel("Staff2.2_finalvar.xlsx", col_names = FALSE)

#####################################
#### Part 5. Correct raw data according to error repot
#####################################
#HARD CODE - dob_date_1
#R2 
#E103-2-002: 09/09/1962 -> 29/09/1962
idx <- which(staff2_raw$`...21` == "E103-2-002" & staff2_raw$`...19` == 2) #`...21` = PID, `...19` = round
staff2_raw$`...30`[idx] <- "29/09/1962" # `...30` = dob_date_1 

#E920-2-001: 16/03/1996 -> 16/03/1966
idx <- which(staff2_raw$`...21` == "E920-2-001" & staff2_raw$`...19` == 2)
staff2_raw$`...30`[idx] <- "16/03/1966"

#E947-2-002 12/12/1995 -> 22/12/1995
idx <- which(staff2_raw$`...21` == "E947-2-002" & staff2_raw$`...19` == 2) #`...21` = PID `...19` = round
staff2_raw$`...30`[idx] <- "22/12/1995" #`...30` = dob_date_1

#HARD CODE - CVDx_dates (found at Part 10G1 Check 1)
#R2 
#E001-2-003: 
idx <- which(staff2.2_raw$`...20` == "E001-2-003" & staff2.2_raw$`...18` == 2) #`...20` = PID, `...18` = round
staff2.2_raw$`...316`[idx] <- "2022/07/01" # `...316` = CVd2_date_3
staff2.2_raw$`...344`[idx] <- "2022/11/01" # `...344` = CVd3_date_3

#E001-2-004: 
idx <- which(staff2.2_raw$`...20` == "E001-2-004" & staff2.2_raw$`...18` == 2) #`...20` = PID, `...18` = round
staff2.2_raw$`...288`[idx] <- "2022/06/01" # `...288` = CVd1_date_1
staff2.2_raw$`...316`[idx] <- "2022/09/01" # `...316` = CVd2_date_3

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

staff1_header <- get_header(staff1_raw)
staff2_header <- get_header(staff2_raw)
staff2.2_header <- get_header(staff2.2_raw)


##3. Only keep and set data colnames to statement 1 for cleaning participant data
clean_pdata <- function(df) {
  finalvar <- as.character(df[3,])
  df_woheader <- df[-(1:3), ]
  names(df_woheader) <- finalvar
  df_woheader
}

staff1_clean <- clean_pdata(staff1_raw)
staff2_clean <- clean_pdata(staff2_raw)
staff2.2_clean <- clean_pdata(staff2.2_raw)


##4 Prep 1 to join surveys within Round: convert everything to character 
#if error: names(resident3_clean)[duplicated(names(resident3_clean))]

staff1_clean <- staff1_clean %>% mutate(across(everything(), as.character))
staff2_clean <-staff2_clean %>% mutate(across(everything(), as.character))
staff2.2_clean <- staff2.2_clean %>% mutate(across(everything(), as.character))

## 4A. Include only Round 2 Participants
R2_staff1_clean <- staff1_clean %>% filter(round == '2')
R2_staff2_clean <- staff2_clean %>% filter(round == '2')
R2_staff2.2_clean <- staff2.2_clean %>% filter(round == '2')


##5 Prep 2 to join survey within Round: set participant ID
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

R2_staff1_clean <- merge_name_CHI(R2_staff1_clean)
R2_staff2_clean <- merge_name_CHI(R2_staff2_clean)



#list of all var with no prefix
noprefix_var <- c(id_var, RCHEID, round, name_CHI)

##6 Prep 3: prefix all final var names with dataset origin
## except for the ID variable so we can still join by ID correctly
R2_staff1_clean <- R2_staff1_clean %>%
  rename_with(~ paste0("Staff1.", .x), .cols = -all_of(noprefix_var))

R2_staff2_clean <- R2_staff2_clean %>%
  rename_with(~ paste0("Staff2.", .x), .cols = -all_of(noprefix_var))

R2_staff2.2_clean <- R2_staff2.2_clean %>%
  rename_with(~ paste0("Staff2.2.", .x), .cols = -all_of(c(id_var, RCHEID, round)))


##6 Join surveys within R2 (full join) by PID
#full join keeps everyone in the surveys
combined_R2.2 <- R2_staff1_clean %>%
  full_join(R2_staff2_clean, by = c(id_var, RCHEID, round, name_CHI)) %>%
  full_join(R2_staff2.2_clean, by = c(id_var, RCHEID, round))

##7 Sort by ID
combined_R2.2 <- combined_R2.2 %>%
  arrange(.data[[id_var]])

##8. Reorder colnames to round, RCHEID, PID, name_CHI
combined_R2.2 <- combined_R2.2 %>%
  select(round, RCHEID, PID, name_CHI, everything())

##save combined_R2.2 into excel
setwd("C:/Users/OrielTsao/Desktop/COVID-19 RCHEs/DATA/3. Clean Data/R2/")
write.xlsx(combined_R2.2, 
           file = "combined_R2.2_Staf_1.xlsx",
           colNames = TRUE,
           rowNames = FALSE)

##QC
combined_R2.2 %>%
  count(PID) %>%     # count how many times each PID appears
  count(n)           # count how many PIDs have n duplicates

sum(duplicated(combined_R2.2[[id_var]]))

## Further processing of combined_R2_2 PID and name_CHI to ensure no PID duplicates as 
## a result of error in chinese name typing
setwd("C:/Users/OrielTsao/Desktop/COVID-19 RCHEs/DATA/3. Clean Data/R2/")

combined_R2.2_2 <- read_excel("combined_R2.2_Staf_2.xlsx", col_names = TRUE)

## 1. Convert everything to character
combined_R2.2_2 <- combined_R2.2_2 %>%
  mutate(across(everything(), as.character))

## 2. merge together duplicated rows to one row (none of the duplicated rows overlap)
combined_R2.2_3 <- combined_R2.2_2 %>% 
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

## 3. Reorder colnames to round, RCHEID, PID, name_CHI
combined_R2.2_3 <- combined_R2.2_3 %>%
  select(round, RCHEID, PID, final_name_CHI, everything())

##save combined_R2.2 into excel
setwd("C:/Users/OrielTsao/Desktop/COVID-19 RCHEs/DATA/3. Clean Data/R2/")
write.xlsx(combined_R2.2_3, 
           file = "combined_R2.2_Staf_3.xlsx",
           colNames = TRUE,
           rowNames = FALSE)


###ROUND 2.1 & 2.2 QC ####
####### REMOVE ALL OBJECTS IN WORKPLACE ########
rm(list=ls())

setwd("C:/Users/OrielTsao/Desktop/COVID-19 RCHEs/DATA/3. Clean Data/R2")

combined_R2.1_Staf <- read_excel("combined_R2.1_Staf_1.xlsx",col_names = TRUE)
combined_R2.2_Staf <- read_excel("combined_R2.2_Staf_3.xlsx",col_names = TRUE)

# ##Only keep and set data colnames to final var column
# clean_pdata <- function(df) {
#   finalvar <- as.character(df[3,])
#   df_woheader <- df[-(1:3), ]
#   names(df_woheader) <- finalvar
#   df_woheader
# }
# 
# combined_R2.1_Staf <- clean_pdata(combined_R2.1_Staf)
# combined_R2.2_Staf <- clean_pdata(combined_R2.2_Staf)

#1. Check presence of overlap
id_var <- "PID"
any(combined_R2.1_Staf[[id_var]] %in% combined_R2.2_Staf[[id_var]])

#2. If yes presence of overlap, which PIDs overlap?
intersect(combined_R2.1_Staf[[id_var]], combined_R2.2_Staf[[id_var]])

#3. Table overlap in R2.1 and R2.2
table(df1 = combined_R2.1_Staf[[id_var]] %in% combined_R2.2_Staf[[id_var]])

##RESULT: 34 staff in R2.1 overlaps with R2.2 while 27 only exist in R2.1

###################################################################################
####### REMOVE ALL OBJECTS IN WORKPLACE ########
rm(list=ls())

# JOINING OF R2.1 AND R.2.2 INTO ONE ROUND 2 DATASET

#####################################
#### Part 6 CONTINUE.  Combine datasets within the same round in wide form
#####################################
#without FINAL_NAME_CHI

## SIMPLE JOIN R2.1 and R2.2 dataset BY PID ### Remarks: no within-round var merging
setwd("C:/Users/OrielTsao/Desktop/COVID-19 RCHEs/DATA/3. Clean Data/R2")

combined_R2.1_Staf <- read_excel("combined_R2.1_Staf_1.xlsx",col_names = TRUE)
combined_R2.2_Staf <- read_excel("combined_R2.2_Staf_3.xlsx",col_names = TRUE)


##2. Make sure everything is character (avoid type issues when joining)
combined_R2.1_Staf <- combined_R2.1_Staf %>%
  mutate(across(everything(), as.character))

combined_R2.2_Staf <- combined_R2.2_Staf %>%
  mutate(across(everything(), as.character))

##3. Set ID variable for joining
round <- "round"
id_var <- "PID"
RCHEID <- "RCHEID"



##4. Join R2.1 and R2.2 side by side by PID (keep anyone who did at least one)
combined_R2_Staf <- full_join(combined_R2.1_Staf,
                              combined_R2.2_Staf,
                              by = c(round, id_var, RCHEID))

##5. Sort by PID
combined_R2_Staf <- combined_R2_Staf %>%
  arrange(.data[[id_var]])


##save combined_R2 Resident data into excel
setwd("C:/Users/OrielTsao/Desktop/COVID-19 RCHEs/DATA/3. Clean Data/R2")
write.xlsx(combined_R2_Staf, 
           file = "combined_R2_Staf.xlsx",
           colNames = TRUE,
           rowNames = FALSE)

################################################################################
####### REMOVE ALL OBJECTS IN WORKPLACE ########
rm(list=ls())

###ROUND 3###

#####################################
#### Part 3. Manually add the final variable names as the third header row in raw data
#####################################
#MANUALLY ADDED TO EXCEL

#####################################
#### Part 4. Load raw data, error repot, and all needed files
#####################################

setwd("C:/Users/OrielTsao/Desktop/COVID-19 RCHEs/DATA/1. Raw Data/R3/Qualtrics/20251212_finalvarname")

## 1. Read the two R2 survey files (no col names, because first 3 rows are special)
staff1_raw <- read_excel("Staff1_finalvar.xlsx", col_names = FALSE)
staff2_raw <- read_excel("Staff2_finalvar.xlsx", col_names = FALSE)
staff2.2_raw <- read_excel("Staff2.2_finalvar.xlsx", col_names = FALSE)


#####################################
#### Part 5. Correct raw data according to error repot
#####################################
#DOB_DATE
#R3
#E930-2-003: 07/08/1949 -> 27/08/1949
idx <- which(staff2_raw$`...21` == "E930-2-003" & staff2_raw$`...19` == 3) #`...21` = PID `...19` = round
staff2_raw$`...30`[idx] <- "27/08/1949" #`...30` = dob_date_1

#HARD CODE - CVDx_dates (found at Part 10G1 Check 1)
#R3
#E901-2-019: 
idx <- which(staff2.2_raw$`...20` == "E901-2-019" & staff2.2_raw$`...18` == 3) #`...20` = PID, `...18` = round
staff2.2_raw$`...287`[idx] <- "2022/01/17" # `...287` = CVd1_date_1
staff2.2_raw$`...315`[idx] <- "2022/02/07" # `...315` = CVd2_date_2

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

staff1_header <- get_header(staff1_raw)
staff2_header <- get_header(staff2_raw)
staff2.2_header <- get_header(staff2.2_raw)


##3. Only keep and set data colnames to statement 1 for cleaning participant data
clean_pdata <- function(df) {
  finalvar <- as.character(df[3,])
  df_woheader <- df[-(1:3), ]
  names(df_woheader) <- finalvar
  df_woheader
}

staff1_clean <- clean_pdata(staff1_raw)
staff2_clean <- clean_pdata(staff2_raw)
staff2.2_clean <- clean_pdata(staff2.2_raw)


##4 Prep 1 to join surveys within Round: convert everything to character 
#if error: names(resident3_clean)[duplicated(names(resident3_clean))]

staff1_clean <- staff1_clean %>% mutate(across(everything(), as.character))
staff2_clean <-staff2_clean %>% mutate(across(everything(), as.character))
staff2.2_clean <- staff2.2_clean %>% mutate(across(everything(), as.character))

## 4A. Include only Round 2 Participants
R3_staff1_clean <- staff1_clean %>% filter(round == '3')
R3_staff2_clean <- staff2_clean %>% filter(round == '3')
R3_staff2.2_clean <- staff2.2_clean %>% filter(round == '3')


##5 Prep 2 to join survey within Round: set participant ID
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

R3_staff1_clean <- merge_name_CHI(R3_staff1_clean)
R3_staff2_clean <- merge_name_CHI(R3_staff2_clean)



#list of all var with no prefix
noprefix_var <- c(id_var, RCHEID, round, name_CHI)

##6 Prep 3: prefix all final var names with dataset origin
## except for the ID variable so we can still join by ID correctly
R3_staff1_clean <- R3_staff1_clean %>%
  rename_with(~ paste0("Staff1.", .x), .cols = -all_of(noprefix_var))

R3_staff2_clean <- R3_staff2_clean %>%
  rename_with(~ paste0("Staff2.", .x), .cols = -all_of(noprefix_var))

R3_staff2.2_clean <- R3_staff2.2_clean %>%
  rename_with(~ paste0("Staff2.2.", .x), .cols = -all_of(c(id_var, RCHEID, round)))


##7 Join surveys within R2 (full join) by PID
#full join keeps everyone in the surveys
combined_R3 <- R3_staff1_clean %>%
  full_join(R3_staff2_clean, by = c(id_var, RCHEID, round, name_CHI)) %>%
  full_join(R3_staff2.2_clean, by = c(id_var, RCHEID, round))

##8 Sort by ID
combined_R3 <- combined_R3 %>%
  arrange(.data[[id_var]])

##9 Reorder colnames to round, RCHEID, PID, name_CHI
combined_R3 <- combined_R3 %>%
  select(round, RCHEID, PID, name_CHI, everything())

##save combined_R2.2 into excel
setwd("C:/Users/OrielTsao/Desktop/COVID-19 RCHEs/DATA/3. Clean Data/R3")
write.xlsx(combined_R3, 
           file = "combined_R3_Staf_1.xlsx",
           colNames = TRUE,
           rowNames = FALSE)

##QC
combined_R3 %>%
  count(PID) %>%     # count how many times each PID appears
  count(n)           # count how many PIDs have n duplicates

sum(duplicated(combined_R3[[id_var]]))

## Further processing of combined_R3 PID and name_CHI to ensure no PID duplicates as 
## a result of error in chinese name typing
setwd("C:/Users/OrielTsao/Desktop/COVID-19 RCHEs/DATA/3. Clean Data/R3")

combined_R3_2 <- read_excel("combined_R3_Staf_2.xlsx", col_names = TRUE)

## 1. Convert everything to character
combined_R3_2 <- combined_R3_2 %>%
  mutate(across(everything(), as.character))

## 2. merge together duplicated rows to one row (none of the duplicated rows overlap)
combined_R3_3 <- combined_R3_2 %>% 
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

## 3. Reorder colnames to round, RCHEID, PID, name_CHI
combined_R3_3 <- combined_R3_3 %>%
  select(round, RCHEID, PID, final_name_CHI, everything())

##save combined_R2.2 into excel
setwd("C:/Users/OrielTsao/Desktop/COVID-19 RCHEs/DATA/3. Clean Data/R3")
write.xlsx(combined_R3_3, 
           file = "combined_R3_Staf_3.xlsx",
           colNames = TRUE,
           rowNames = FALSE)

##QC
combined_R3_3 %>%
  count(PID) %>%     # count how many times each PID appears
  count(n)           # count how many PIDs have n duplicates

sum(duplicated(combined_R3_3[[id_var]]))

#################################################################################
#################################################################################
####### REMOVE ALL OBJECTS IN WORKPLACE ########
rm(list=ls())

###ALL ROUNDS

#####################################
#### Part 7. Combine datasets across rounds
#####################################
#WITHOUT FINAL_NAME_CHI

setwd("C:/Users/OrielTsao/Desktop/COVID-19 RCHEs/DATA/3. Clean Data/ALL ROUNDS/Staff")

## 1. Read the R2 survey files (no col names, because first 3 rows are special)
R1_raw <- read_excel("combined_R1_Staf_3.xlsx", col_names = T)
R2_raw <- read_excel("combined_R2_Staf.xlsx", col_names = T)
R3_raw <- read_excel("combined_R3_Staf_3.xlsx", col_names = T)

## 1. Read the R2 survey files (no col names, because first 3 rows are special)
R1_clean <- R1_raw %>% mutate(across(everything(), as.character))
R2_clean <- R2_raw %>% mutate(across(everything(), as.character))
R3_clean <- R3_raw %>% mutate(across(everything(), as.character))

#1B. Clean the final_name_CHI between R2.1 and R2.2
R2_clean <- R2_raw %>%
  mutate(across(everything(), as.character)) %>%
  mutate(final_name_CHI = coalesce(final_name_CHI.x, final_name_CHI.y)) %>%
  select(-final_name_CHI.x, -final_name_CHI.y)

##2.  Prep 2 to join survey within Round: set participant ID and merge name_CHI
round <- "round"
RCHEID <- "RCHEID"
id_var <- "PID"
final_name_CHI <- "final_name_CHI"

##7 Join surveys within R2 (full join) by PID
#full join keeps everyone in the surveys
ALLRound <- R1_clean %>%
  full_join(R2_clean, by = c(round, RCHEID, id_var, final_name_CHI)) %>%
  full_join(R3_clean, by = c(round, RCHEID, id_var, final_name_CHI)) 

##8 Sort by ID
ALLRound <- ALLRound %>% 
  arrange(.data[[id_var]], round)

##9. Reorder colnames to round, RCHEID, PID, name_CHI
ALLRound <- ALLRound %>%
  select(round, RCHEID, PID, final_name_CHI,everything())

##save AllRound_withoutspeclog into excel

setwd("C:/Users/OrielTsao/Desktop/COVID-19 RCHEs/DATA/10d/ALL ROUNDS/Staff")

write.xlsx(ALLRound, 
           file = "STAFF_ALLRound_withoutspeclog.xlsx",
           colNames = TRUE,
           rowNames = FALSE)

###
#QC FOR PART 7 - Counting staff PIDS without Staff (1) survey
######## REMOVE ALL OBJECTS IN WORKPLACE ########
rm(list=ls())

setwd("C:/Users/OrielTsao/Desktop/COVID-19 RCHEs/DATA/3. Clean Data/ALL ROUNDS/Staff")

## 1. Read the R2 survey files (no col names, because first 3 rows are special)
R1_raw <- read_excel("combined_R1_Staf_3.xlsx", col_names = T)
R2_raw <- read_excel("combined_R2_Staf.xlsx", col_names = T)
R3_raw <- read_excel("combined_R3_Staf_3.xlsx", col_names = T)

## 1. Read the R2 survey files (no col names, because first 3 rows are special)
R1_clean <- R1_raw %>% mutate(across(everything(), as.character))
R2_clean <- R2_raw %>% mutate(across(everything(), as.character))
R3_clean <- R3_raw %>% mutate(across(everything(), as.character))

##2.  Prep 2 to join survey within Round: set participant ID and merge name_CHI
round <- "round"
RCHEID <- "RCHEID"
id_var <- "PID"

##7 Join surveys within R2 (full join) by PID
#full join keeps everyone in the surveys
ALLRoundwoCHI <- R1_clean %>%
  full_join(R2_clean, by = c(round, RCHEID, id_var)) %>%
  full_join(R3_clean, by = c(round, RCHEID, id_var))

##8 Sort by ID
ALLRoundwoCHI <- ALLRoundwoCHI %>%
  arrange(.data[[id_var]], round)

##9. Reorder colnames to round, RCHEID, PID, name_CHI
ALLRoundwoCHI <- ALLRoundwoCHI %>%
  select(round, RCHEID, PID, everything())

####Count PIDs in each round (without Resident(1) survey)
#Count PID without Resident (1) in R2 and R3


try <- ALLRoundwoCHI %>%
  # Use explicit dplyr namespace to avoid recursion errors
  dplyr::select(!matches("^(Staff1)"))


try <- try %>%
  # Simplified filter: Keep if row has at least one non-NA
  # in columns OTHER than round, PID, and RCHEID
  dplyr::filter(rowSums(!is.na(dplyr::across(!c(round, PID, RCHEID)))) > 0)


ALLRound_woRes1 <- try

R1 <- ALLRound_woRes1 %>% filter(round == "1")
R2 <- ALLRound_woRes1 %>% filter(round == "2")
R3 <- ALLRound_woRes1 %>% filter(round == "3")

length(unique(R1$PID))
length(unique(R2$PID))
length(unique(R3$PID))

#####################################
#### Part 8. Re-position columns by category and (within category) by similarity
#####################################
#NOT APPLICABLE
#Inborn raw data format already group categories together by similarity

#####################################
#### Part 9.  Prior validation for separate files
#####################################
# DATA ENTRY VETTING conducted in Excel


#END of PART 1-9
####################################################################################
####################################################################################

#####################################
#### Part 10. Variable Cleaning 
#####################################

## Part 10A
##Part 10A1 Identify overlapping var-PIDs in R1 EVAX_STAFF and MINI 

####### REMOVE ALL OBJECTS IN WORKPLACE ########
rm(list=ls())

#1. Read df
setwd("C:/Users/OrielTsao/Desktop/COVID-19 RCHEs/DATA/3. Clean Data/ALL ROUNDS/Staff")
R1 <- read_excel("combined_R1_Staf_3.xlsx")

# 2. Define constant ID columns
constant <- c("round", "RCHEID", "PID", "final_name_CHI")

# 3. Subset STAFF and MINI datasets (column-wise)
R1_STAFF <- R1 %>%
  filter(
    if_any(matches("^STAFF\\."), ~ !is.na(.))
  ) %>%
  select(all_of(constant), matches("^STAFF\\."))

R1_MINI <- R1 %>%
  filter(
    if_any(matches("^StaffMINI\\."), ~ !is.na(.))
  ) %>%
  select(all_of(constant), matches("^StaffMINI\\."))


R1_Staff_PID <- R1_STAFF %>% pull(PID)
R1_MINI_PID  <- R1_MINI  %>% pull(PID)

overlap_PID_R1 <- tibble(PID = intersect(R1_Staff_PID, R1_MINI_PID))

##Conclusion: ALL MINI vars overlaps but straightforward hierarchy (MINI >> STAFF) so will fix in variable mapping

##################################################################################
### PART 10A2 Identify overlap var-PIDs in R2: R2.1 Staff Basic and R2.2 Qualtrics
####### REMOVE ALL OBJECTS IN WORKPLACE ########
rm(list=ls())

#1. Read df
setwd("C:/Users/OrielTsao/Desktop/COVID-19 RCHEs/DATA/3. Clean Data/ALL ROUNDS/Staff")
R2 <- read_excel("combined_R2_Staf.xlsx")

#1B. Clean the final_name_CHI between R2.1 and R2.2
R2 <- R2 %>%
  mutate(across(everything(), as.character)) %>%
  mutate(final_name_CHI = coalesce(final_name_CHI.x, final_name_CHI.y)) %>%
  select(-final_name_CHI.x, -final_name_CHI.y)

# 2. Define constant ID columns
constant <- c("round", "RCHEID", "PID", "final_name_CHI")

# 3. Subset STAFF and MINI datasets (column-wise)
R2.1_Staff <- R2 %>%
  filter(
    if_any(matches("^R2.1StaffBasic\\."), ~ !is.na(.))
  ) %>%
  select(all_of(constant), matches("^R2.1StaffBasic\\."))

R2.2_Staff1 <- R2 %>%
  filter(
    if_any(matches("^Staff1\\."), ~ !is.na(.))
  ) %>%
  select(all_of(constant), matches("^Staff1\\."))

R2.2_Staff2 <- R2 %>%
  filter(
    if_any(matches("^Staff2\\."), ~ !is.na(.))
  ) %>%
  select(all_of(constant), matches("^Staff2\\."))

R2.2_Staff2.2 <- R2 %>%
  filter(
    if_any(matches("^Staff2.2\\."), ~ !is.na(.))
  ) %>%
  select(all_of(constant), matches("^Staff2.2\\."))


R2.1_Staff_PID <- R2.1_Staff %>% pull(PID)

R2.2_Staff1_PID <- R2.2_Staff1 %>% pull(PID)

R2.2_Staff2_PID <- R2.2_Staff2 %>% pull(PID)

R2.2_Staff2.2_PID <- R2.2_Staff2.2 %>% pull(PID)

##overlapping PIDs
overlap_PID_R2.1_Staff1 <- tibble(PID = intersect(R2.1_Staff_PID, R2.2_Staff1_PID))
overlap_PID_R2.1_Staff2 <- tibble(PID = intersect(R2.1_Staff_PID, R2.2_Staff2_PID))
overlap_PID_R2.1_Staff2.2 <- tibble(PID = intersect(R2.1_Staff_PID, R2.2_Staff2.2_PID))

#(RESULTS: no overlap for Staff2 and Staff2.1 only 34 overlapping PID for Staff1)
#CONCLUSION: ignore 34 matching PIDs for Staff1 as no matching vars

##END OF PART 10A
# PART 10B, 10C, 10D - NOT APPLICABLE
# OVERLAPPING VARS/PID CAN BE RESOLVED DIRECTLY IN PART 10R

##################################################################################
######## REMOVE ALL OBJECTS IN WORKPLACE ########
rm(list=ls())

#Part 10D: Cross-Round FINAL Master Dataset Construction

#1. Read
setwd("C:/Users/OrielTsao/Desktop/COVID-19 RCHEs/DATA/10d/ALL ROUNDS/Staff")
ALL_Round_wospeclog <- read_excel("STAFF_ALLRound_withoutspeclog.xlsx", 
                                  col_names = TRUE,
                                  col_types = "text")
spec_log_raw <- read_excel("evax_specimenlog_dated20250718.xlsx", col_names = T)

setwd("C:/Users/OrielTsao/Desktop/COVID-19 RCHEs/DATA/Summary docs/")
consent_df <- read_excel("consent_archive_protected_dated05122025.xlsx", 
                         sheet = "Staff_dated20251205")

#2. Convert all to character
ALL_Round_wospeclog <- ALL_Round_wospeclog %>% mutate(across(everything(), as.character))
spec_log_clean <- spec_log_raw %>% mutate(across(everything(), as.character))
consent_df <- consent_df %>% mutate(across(everything(), as.character))

##3. Prep spec_log for joining with other data files
#Prep 1: join subid1,2,3 in spec_log to PID
spec_log_clean$PID <- paste(spec_log_clean$subid1, 
                            spec_log_clean$subid2, 
                            spec_log_clean$subid3, sep = "-")

#Prep 2: Change Subject ID in consent_df to PID
consent_df$PID <- consent_df$`Subject ID`

#Prep 3: Keep only Resident in blood_df
spec_log_clean <- spec_log_clean %>% filter(subid2 != 1)

#Prep 4: # Standardize PID format in both dataframes
spec_log_clean <- spec_log_clean %>%
  mutate(PID = str_trim(PID),               # 1. Remove leading/trailing spaces
         PID = str_replace_all(PID, "\\s", ""), # 2. Remove any internal spaces/tabs
         PID = toupper(PID),                # 3. Make all uppercase for consistency
         EVAX_Status = str_trim(EVAX_Status),              
         EVAX_Status = str_replace_all(EVAX_Status, "\\s", ""))

consent_df <- consent_df %>%
  mutate(PID = str_trim(PID), 
         PID = str_replace_all(PID, "\\s", ""), 
         PID = toupper(PID),
         `Study Round` = str_trim(`Study Round`), 
         `Study Round` = str_replace_all(`Study Round`, "\\s", ""), 
         `Study Round` = toupper(`Study Round`))

#Prep 5: # hard code comments from spec log
# R1 E905-2-013 (on366) to E905-2-023
spec_log_clean <- spec_log_clean %>%
  mutate(PID = ifelse(PID == "E905-2-013" & str_detect(labserial, "on366"), 
                      "E905-2-023", 
                      PID))

# R1 E928-2-001 (on1072) to E927-2-001
spec_log_clean <- spec_log_clean %>%
  mutate(PID = ifelse(PID == "E928-2-001" & str_detect(labserial, "on1072"), 
                      "E927-2-001", 
                      PID))

# R1 E928-2-004 (on1071) to E927-2-004
spec_log_clean <- spec_log_clean %>%
  mutate(PID = ifelse(PID == "E928-2-004" & str_detect(labserial, "on1071"), 
                      "E927-2-004", 
                      PID))

##QC (is all blood_df's PID inside consent_df's PID)
all(spec_log_clean$PID %in% consent_df$PID) #RESULT : TRUE

#Prep 6: transform into date format
consent_df <- consent_df %>%
  mutate(
    # 1. Capture the messy column (update the name to match your names(consent_df) output)
    raw_date = `Document date\r\n(dd/mm/yyyy)`,
    
    # 2. Convert based on format
    consent_date = case_when(
      # If it's a serial number (only digits)
      grepl("^[0-9]+$", raw_date) ~ excel_numeric_to_date(as.numeric(raw_date)),
      
      # If it's a DD/MM/YYYY string
      grepl("/", raw_date) ~ dmy(raw_date),
      
      # Otherwise, leave as NA
      TRUE ~ as.Date(NA)
    )
  )

spec_log_clean$cdate <- ymd(spec_log_clean$cdate)

spec_log_clean <- spec_log_clean %>% mutate(cdate = as.Date(cdate))
consent_df <- consent_df %>% 
  mutate(consent_date = as.Date(consent_date))


##4 QC R1-R3 spec_log blood data
# creat a column named round and RCHEID in spec_log
spec_log_clean <- spec_log_clean %>%
  mutate(round = case_when(
    is.na(EVAX_Status)            ~ 1,
    EVAX_Status == "Round1"       ~ 2,
    EVAX_Status == "Round2"       ~ 2,
    EVAX_Status == "Round3"       ~ 3,
    TRUE                          ~ NA_real_
  )) %>% # End of first mutate, then pipe
  mutate(RCHEID = substr(as.character(PID), 1, 4))

# Check if blood count matches Round total
R1_blood_data <- spec_log_clean %>% filter(round == 1)
R2_blood_data <- spec_log_clean %>% filter(round == 2)
R3_blood_data <- spec_log_clean %>% filter(round == 3)

consent_df_R1 <- consent_df %>% 
  filter(!(`Study Round` %in% c("2", "3")))
consent_df_R2 <- consent_df %>% 
  filter(!(`Study Round` %in% c("1", "3")))
consent_df_R3 <- consent_df %>% 
  filter(!(`Study Round` %in% c("2", "1")))

# QC R2 & R3 blood - all have consent
all(R1_blood_data$PID %in% consent_df_R1$PID) #RESULT : TRUE
all(R2_blood_data$PID %in% consent_df_R2$PID) #RESULT : TRUE
all(R3_blood_data$PID %in% consent_df_R3$PID) #RESULT : TRUE


#6. JOIN R1-R3 blood data
# create RCHEID column
PID <- "PID"
RCHEID <- "RCHEID"
round <- "round"

ALL_blood_data <- bind_rows(R1_blood_data, R2_blood_data, R3_blood_data)


#Sort by ID
ALL_blood_data <- ALL_blood_data %>%
  arrange(.data[[PID]])

#Reorder colnames to round, RCHEID, PID, name_CHI
ALL_blood_data <- ALL_blood_data %>%
  select(round, RCHEID, PID, everything())

ALL_blood_data <- ALL_blood_data %>%
  rename_with(~ paste0("blood.", .x), .cols = -all_of(c(PID, RCHEID, round)))

#convert to characters
ALL_blood_data <- ALL_blood_data %>% mutate(across(everything(), as.character))

#7. JOIN all R1-R3 survey data + resolved R1-R3 blood data
round <- "round"
RCHEID <- "RCHEID"
id_var <- "PID"
final_name_CHI <- "final_name_CHI"

##Full join to keep everyone in the surveys
ALLRound <- ALL_Round_wospeclog %>%
  full_join(ALL_blood_data, by = c("PID", "round"))

##8A. Make sure every column has RCHEID
ALLRound <- ALLRound %>%
  mutate(RCHEID = substr(PID, 1, 4))

ALLRound$RCHEID.x <- NULL
ALLRound$RCHEID.y <- NULL

##8B. Remove random NA in final_name_CHI
ALLRound <- ALLRound %>%
  mutate(final_name_CHI = str_remove_all(final_name_CHI, "NA"))

##9 Sort by ID
ALLRound <- ALLRound %>% 
  arrange(.data[[id_var]], round)

##10. Reorder colnames to round, RCHEID, PID, name_CHI
ALLRound <- ALLRound %>%
  select(round, RCHEID, PID, final_name_CHI, everything())

#11. Collapse multi rows for 1 PID (due to final_name_CHI)
ALLRound <- ALLRound %>% 
  mutate(across(everything(), as.character))


##save ALL_ROUND into excel
setwd("C:/Users/OrielTsao/Desktop/COVID-19 RCHEs/DATA/10d/ALL ROUNDS/Staff/")

write.xlsx(ALLRound, 
           file = "ALLRound_STAFF.xlsx",
           colNames = TRUE,
           rowNames = FALSE)

#END of PART 10D1
##QC if R1 blood cdate is after consent_date
#CONCLUSION: YES, except E105-2-001 (the missing consent)
#Step 2: Keep only blood PIDs that exist in consent_df
blood_df <- spec_log_clean %>% filter(round == 1)
finalwmissing_df <- blood_df %>%
  filter(PID %in% consent_df_R1$PID)

#Step 3:
# Join with blood data with consent data for these PID
# (Note: This will create multiple rows for PIDs with multiple blood draws)
#FOR SAME PID, SELECT 1 ROW FROM SPECIMEN LOG WITH CLOSEST DATE & AFTER CONSENT
finalwmissing_df <- finalwmissing_df %>%
  left_join(consent_df_R1, by = "PID")

# STEP 4: Filter for dates (SELECTING the blood data row NEAREST TO & AFTER consent, but KEEP the PID if requirement not met)
finalwmissing_df <- finalwmissing_df %>%
  group_by(PID) %>%
  slice_min(
    order_by = ifelse(cdate >= consent_date, cdate - consent_date, NA), 
    n = 1, 
    with_ties = FALSE
  ) %>%
  ungroup() %>%
  # NEW STEP: Convert cdate to NA if it's before the consent_date
  mutate(cdate = if_else(cdate < consent_date, as.Date(NA), cdate))

failed_matches <- finalwmissing_df %>% 
  filter(is.na(cdate))


############
#Part 10D QC
#Count PID 
R1 <- ALLRound %>% filter(round == "1")
R2 <- ALLRound %>% filter(round == "2")
R3 <- ALLRound %>% filter(round == "3")

length(unique(R1$PID)) # 260
length(unique(R2$PID)) #462
length(unique(R3$PID)) #524


####Count PIDs in each round (without Resident(1) survey)
# #Count PID without Resident (1) in R2 and R3
final_name_CHI <- "final_name_CHI"

#ALLRound_woRes1
# hi_R2 <- ALLRound_woCHIname %>% filter(round == "2")

try <- ALLRound %>%
  # Use explicit dplyr namespace to avoid recursion errors
  dplyr::select(!matches("^(Staff1)"))

try <- try %>%
  # Simplified filter: Keep if row has at least one non-NA
  # in columns OTHER than round, PID, and RCHEID
  dplyr::filter(rowSums(!is.na(dplyr::across(!c(round, PID, RCHEID,
                                                final_name_CHI)))) > 0)

setwd("C:/Users/OrielTsao/Desktop")

# write.xlsx(try,
#            file = "try.xlsx",
#            colNames = TRUE,
#            rowNames = FALSE)

ALLRound_woRes1 <- try

R1 <- ALLRound_woRes1 %>% filter(round == "1")
R2 <- ALLRound_woRes1 %>% filter(round == "2")
R3 <- ALLRound_woRes1 %>% filter(round == "3")

length(unique(R1$PID)) #260
length(unique(R2$PID)) #332
length(unique(R3$PID)) #308

#########
### Part 10E


