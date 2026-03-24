#############
#PRINTING - line number
root    <- "C:/Users/OrielTsao/Desktop/COVID-19 RCHEs/DATA"
scripts <- file.path(root, "scripts")
lines <- readLines(file.path(scripts, "Staff_Part1-10D1.R"))
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
writeLines(html_content, file.path(scripts, "Staff_Part1-10D1.R.html"))
###########


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
#### Part 4. Load raw data, error report, and all needed files
#####################################
root         <- "C:/Users/OrielTsao/Desktop/COVID-19 RCHEs/DATA"
r1_qualtrics <- file.path(root, "0_raw/R1/qualtrics")
r1_other     <- file.path(root, "0_raw/R1/other")
r1_clean     <- file.path(root, "1_clean/R1")

## 1. Read the R1 survey files
staff_raw     <- read_excel(file.path(r1_qualtrics, "EVAX_STAFF.xlsx"),               col_names = TRUE)
staffMINI_raw <- read_excel(file.path(r1_other,     "MINI_Staff_dated20221228.xlsx"),  col_names = FALSE)

#####################################
#### Part 5. Correct raw data according to error report
#####################################
#NOT APPLICABLE

#####################################
#### Part 6.  Combine datasets within the same round in wide form
#####################################

## 2. Remove statement2 from header
## EVAX_Staff: col_names = TRUE so row 1 is already colname, row 1 of data is statement 2
rm_stat2 <- function(df) {
  df_wostat2 <- df[-(1), ]
  df_wostat2
}

staff_clean <- rm_stat2(staff_raw)

## MINI: col_names = FALSE so row 2 is header
header_row2 <- function(df) {
  colnames(df) <- as.character(unlist(df[2, ]))
  df <- df[-(1:2), ]
  return(df)
}

staffMINI_clean <- header_row2(staffMINI_raw)

## 3. Prep 1: convert everything to character
staff_clean     <- staff_clean     %>% mutate(across(everything(), as.character))
staffMINI_clean <- staffMINI_clean %>% mutate(across(everything(), as.character))

## 4. Prep 2: make sure core joining variables are the same
staffMINI_clean <- staffMINI_clean %>%
  rename(PID = sid) %>%
  rename(name_CHI = cname)

## 5. Prep 3: Convert vactype (R1 MINI) to CVd1_type, CVd2_type, etc.
staffMINI_clean <- staffMINI_clean %>%
  mutate(
    CVd1_type = case_when(
      vactype == 1 & vacnum >= 1 ~ "Sinovac",
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
      vactype == 1 & vacnum >= 2 ~ "Sinovac",
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
      vactype == 1 & vacnum >= 3 ~ "Sinovac",
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
      vactype == 1 & vacnum >= 4 ~ "Sinovac",
      vactype == 2 & vacnum >= 4 ~ "BioNTech",
      vactype == 4 ~ "BioNTech",
      vactype == 6 ~ "Sinovac",
      vactype == 7 ~ "BioNTech",
      vactype == 9 ~ "Sinovac",
      TRUE ~ NA_character_
    )
  )

#QC check prep 3
staffMINI_try <- staffMINI_clean %>%
  select(PID, starts_with("CVd") & ends_with("type"))

## 6. Prep 4: prefix all final var names with dataset origin
id_var   <- "PID"
RCHEID   <- "RCHEID"
name_CHI <- "name_CHI"

staff_clean <- staff_clean %>%
  rename_with(~ paste0("STAFF.", .x), .cols = -all_of(c(id_var, RCHEID, name_CHI)))

staffMINI_clean <- staffMINI_clean %>%
  rename_with(~ paste0("StaffMINI.", .x), .cols = -all_of(c(id_var, name_CHI)))

## 7. Join surveys within R1 (full join) by PID
combined_R1_Staf_1 <- staff_clean %>%
  full_join(staffMINI_clean, by = c(id_var, name_CHI))

## 8. Add new column called round
combined_R1_Staf_1$round <- 1

## 9. Sort by ID
combined_R1_Staf_1 <- combined_R1_Staf_1 %>%
  arrange(.data[[id_var]])

## 10. Reorder colnames to round, RCHEID, PID, name_CHI
combined_R1_Staf_1 <- combined_R1_Staf_1 %>%
  select(round, RCHEID, PID, name_CHI, everything())

## save combined_R1_Staf_1 into excel
write.xlsx(combined_R1_Staf_1,
           file      = file.path(r1_clean, "combined_R1_Staf_1.xlsx"),
           colNames  = TRUE,
           rowNames  = FALSE)

##QC
combined_R1_Staf_1 %>%
  count(PID) %>%
  count(n)

sum(duplicated(combined_R1_Staf_1[[id_var]]))

## Further processing of PID and chinese name to ensure no PID duplicates
combined_R1_Staf_2 <- read_excel(file.path(r1_clean, "combined_R1_Staf_2.xlsx"), col_names = TRUE)

## 1. Convert everything to character
combined_R1_Staf_2 <- combined_R1_Staf_2 %>%
  mutate(across(everything(), as.character))

## 2. Merge duplicated rows to one row (first non-NA value per column)
combined_R1_Staf_3 <- combined_R1_Staf_2 %>%
  select(-name_CHI) %>%
  mutate(across(everything(), ~na_if(.x, ""))) %>%
  group_by(PID) %>%
  summarise(across(everything(), ~ first(na.omit(.x))))

## 3. QC - ensure no duplicates
combined_R1_Staf_3 %>%
  count(PID) %>%
  count(n)

## 4. Add new column called round
combined_R1_Staf_3$round <- 1

## 5. Reorder colnames to round, RCHEID, PID, final_name_CHI
combined_R1_Staf_3 <- combined_R1_Staf_3 %>%
  select(round, RCHEID, PID, final_name_CHI, everything())

## save combined_R1_Staf_3 into excel
write.xlsx(combined_R1_Staf_3,
           file     = file.path(all_rounds_staff, "combined_R1_Staf_3.xlsx"),
           colNames = TRUE,
           rowNames = FALSE)

################################################################################
####### REMOVE ALL OBJECTS IN WORKPLACE ########
rm(list=ls())

##ROUND 2.1 ###
#####################################
#### Part 3. Add the final variable names as the third header row in raw data
#####################################
#MANUALLY ADDED FINAL VAR TO EXCEL

#####################################
#### Part 4. Load raw data, error report, and all needed files
#####################################
root           <- "C:/Users/OrielTsao/Desktop/COVID-19 RCHEs/DATA"
r2.1_qualtrics <- file.path(root, "0_raw/R2/R2.1_qualtrics")
r2_clean       <- file.path(root, "1_clean/R2")

## 1. Read the R2.1 survey files (no col names, because first 3 rows are special)
residentstaff_raw <- read_excel(file.path(r2.1_qualtrics, "R2.1_Staff_finalvar.xlsx"), col_names = FALSE)

#####################################
#### Part 5. Correct raw data according to error report
#####################################
#NOT APPLICABLE

#####################################
#### Part 6.  Combine datasets within the same round in wide form
#####################################

## 2. Pull out the 3 header rows from a Qualtrics file to be reconstructed later
get_header <- function(df) {
  list(
    stmt1    = as.character(df[1, ]),  # row 1: old var name
    stmt2    = as.character(df[2, ]),  # row 2: question text
    finalvar = as.character(df[3, ])   # row 3: final var name
  )
}

residentstaff_header <- get_header(residentstaff_raw)

## 3. Only keep and set data colnames to final var for cleaning participant data
clean_pdata <- function(df) {
  finalvar    <- as.character(df[3, ])
  df_woheader <- df[-(1:3), ]
  names(df_woheader) <- finalvar
  df_woheader
}

residentstaff_clean <- clean_pdata(residentstaff_raw)

## 4. Prep 1: convert everything to character
residentstaff_clean <- residentstaff_clean %>% mutate(across(everything(), as.character))

## 5. Prep 2: set participant ID and merge name_CHI
id_var         <- "PID"
RCHEID         <- "RCHEID"
name_CHI       <- "name_CHI"
final_name_CHI <- "final_name_CHI"
lastname       <- "name_CHI_1"
firstname      <- "name_CHI_2"

merge_name_CHI <- function(df) {
  df %>%
    mutate(final_name_CHI = paste(name_CHI_1, name_CHI_2, sep = "")) %>%
    select(-name_CHI_1, -name_CHI_2)
}

residentstaff_clean <- merge_name_CHI(residentstaff_clean)

## 6. Prep 3: prefix all final var names with dataset origin
residentstaff_clean <- residentstaff_clean %>%
  rename_with(~ paste0("R2.1StaffBasic.", .x), .cols = -all_of(c(id_var, RCHEID, final_name_CHI)))

## 7. Sort by ID
residentstaff_clean <- residentstaff_clean %>%
  arrange(.data[[id_var]])

## 8. Add new column called round
residentstaff_clean$round <- 2

## 9. Reorder colnames to round, RCHEID, PID, final_name_CHI
residentstaff_clean <- residentstaff_clean %>%
  select(round, RCHEID, PID, final_name_CHI, everything())

## save combined_R2.1_Staf_1 into excel
write.xlsx(residentstaff_clean,
           file      = file.path(r2_clean, "combined_R2.1_Staf_1.xlsx"),
           colNames  = TRUE,
           rowNames  = FALSE)

##QC
residentstaff_clean %>%
  count(PID) %>%
  count(n)

sum(duplicated(residentstaff_clean[[id_var]]))
#RESULTS: No duplicates hence final_name_CHI instead of name_CHI

################################################################################
####### REMOVE ALL OBJECTS IN WORKPLACE ########
rm(list=ls())

##ROUND 2.2 ###
#####################################
#### Part 3. Manually add the final variable names as the third header row in raw data
#####################################
#MANUALLY ADDED TO EXCEL

#####################################
#### Part 4. Load raw data, error report, and all needed files
#####################################
root           <- "C:/Users/OrielTsao/Desktop/COVID-19 RCHEs/DATA"
r2.2_qualtrics <- file.path(root, "0_raw/R2/R2.2_qualtrics")
r2_clean       <- file.path(root, "1_clean/R2")

## 1. Read the R2.2 survey files (no col names, because first 3 rows are special)
staff1_raw   <- read_excel(file.path(r2.2_qualtrics, "Staff1_finalvar.xlsx"),   col_names = FALSE)
staff2_raw   <- read_excel(file.path(r2.2_qualtrics, "Staff2_finalvar.xlsx"),   col_names = FALSE)
staff2.2_raw <- read_excel(file.path(r2.2_qualtrics, "Staff2.2_finalvar.xlsx"), col_names = FALSE)

#####################################
#### Part 5. Correct raw data according to error report
#####################################
#HARD CODE - dob_date_1
#R2
#E103-2-002: 09/09/1962 -> 29/09/1962
idx <- which(staff2_raw$`...21` == "E103-2-002" & staff2_raw$`...19` == 2) #`...21` = PID, `...19` = round
staff2_raw$`...30`[idx] <- "29/09/1962" # `...30` = dob_date_1

#E920-2-001: 16/03/1996 -> 16/03/1966
idx <- which(staff2_raw$`...21` == "E920-2-001" & staff2_raw$`...19` == 2)
staff2_raw$`...30`[idx] <- "16/03/1966"

#E947-2-002: 12/12/1995 -> 22/12/1995
idx <- which(staff2_raw$`...21` == "E947-2-002" & staff2_raw$`...19` == 2) #`...21` = PID, `...19` = round
staff2_raw$`...30`[idx] <- "22/12/1995" # `...30` = dob_date_1

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
    stmt1    = as.character(df[1, ]),
    stmt2    = as.character(df[2, ]),
    finalvar = as.character(df[3, ])
  )
}

staff1_header   <- get_header(staff1_raw)
staff2_header   <- get_header(staff2_raw)
staff2.2_header <- get_header(staff2.2_raw)

## 3. Only keep and set data colnames to final var for cleaning participant data
clean_pdata <- function(df) {
  finalvar    <- as.character(df[3, ])
  df_woheader <- df[-(1:3), ]
  names(df_woheader) <- finalvar
  df_woheader
}

staff1_clean   <- clean_pdata(staff1_raw)
staff2_clean   <- clean_pdata(staff2_raw)
staff2.2_clean <- clean_pdata(staff2.2_raw)

## 4. Prep 1: convert everything to character
staff1_clean   <- staff1_clean   %>% mutate(across(everything(), as.character))
staff2_clean   <- staff2_clean   %>% mutate(across(everything(), as.character))
staff2.2_clean <- staff2.2_clean %>% mutate(across(everything(), as.character))

## 4A. Include only Round 2 Participants
R2_staff1_clean   <- staff1_clean   %>% filter(round == '2')
R2_staff2_clean   <- staff2_clean   %>% filter(round == '2')
R2_staff2.2_clean <- staff2.2_clean %>% filter(round == '2')

## 5. Prep 2: set participant ID and merge name_CHI
id_var    <- "PID"
RCHEID    <- "RCHEID"
round     <- "round"
name_CHI  <- "name_CHI"
lastname  <- "name_CHI_1"
firstname <- "name_CHI_2"

merge_name_CHI <- function(df) {
  df %>%
    mutate(name_CHI = paste(name_CHI_1, name_CHI_2, sep = "")) %>%
    select(-name_CHI_1, -name_CHI_2)
}

R2_staff1_clean <- merge_name_CHI(R2_staff1_clean)
R2_staff2_clean <- merge_name_CHI(R2_staff2_clean)

noprefix_var <- c(id_var, RCHEID, round, name_CHI)

## 6. Prep 3: prefix all final var names with dataset origin
R2_staff1_clean <- R2_staff1_clean %>%
  rename_with(~ paste0("Staff1.", .x), .cols = -all_of(noprefix_var))

R2_staff2_clean <- R2_staff2_clean %>%
  rename_with(~ paste0("Staff2.", .x), .cols = -all_of(noprefix_var))

R2_staff2.2_clean <- R2_staff2.2_clean %>%
  rename_with(~ paste0("Staff2.2.", .x), .cols = -all_of(c(id_var, RCHEID, round)))

## 7. Join surveys within R2.2 (full join) by PID
combined_R2.2 <- R2_staff1_clean %>%
  full_join(R2_staff2_clean,   by = c(id_var, RCHEID, round, name_CHI)) %>%
  full_join(R2_staff2.2_clean, by = c(id_var, RCHEID, round))

## 8. Sort by ID
combined_R2.2 <- combined_R2.2 %>%
  arrange(.data[[id_var]])

## 9. Reorder colnames to round, RCHEID, PID, name_CHI
combined_R2.2 <- combined_R2.2 %>%
  select(round, RCHEID, PID, name_CHI, everything())

## save combined_R2.2_Staf_1 into excel
write.xlsx(combined_R2.2,
           file      = file.path(r2_clean, "combined_R2.2_Staf_1.xlsx"),
           colNames  = TRUE,
           rowNames  = FALSE)

##QC
combined_R2.2 %>%
  count(PID) %>%
  count(n)

sum(duplicated(combined_R2.2[[id_var]]))

## Further processing of combined_R2.2 PID and name_CHI to ensure no PID duplicates
combined_R2.2_2 <- read_excel(file.path(r2_clean, "combined_R2.2_Staf_2.xlsx"), col_names = TRUE)

## 1. Convert everything to character
combined_R2.2_2 <- combined_R2.2_2 %>%
  mutate(across(everything(), as.character))

## 2. Merge duplicated rows to one row
combined_R2.2_3 <- combined_R2.2_2 %>%
  select(-name_CHI) %>%
  mutate(across(everything(), ~na_if(.x, ""))) %>%
  group_by(PID) %>%
  summarise(across(everything(), ~ first(na.omit(.x))))

## 3. Reorder colnames to round, RCHEID, PID, final_name_CHI
combined_R2.2_3 <- combined_R2.2_3 %>%
  select(round, RCHEID, PID, final_name_CHI, everything())

## save combined_R2.2_Staf_3 into excel
write.xlsx(combined_R2.2_3,
           file      = file.path(r2_clean, "combined_R2.2_Staf_3.xlsx"),
           colNames  = TRUE,
           rowNames  = FALSE)

###ROUND 2.1 & 2.2 QC####
####### REMOVE ALL OBJECTS IN WORKPLACE ########
rm(list=ls())

root     <- "C:/Users/OrielTsao/Desktop/COVID-19 RCHEs/DATA"
r2_clean <- file.path(root, "1_clean/R2")

combined_R2.1_Staf <- read_excel(file.path(r2_clean, "combined_R2.1_Staf_1.xlsx"), col_names = TRUE)
combined_R2.2_Staf <- read_excel(file.path(r2_clean, "combined_R2.2_Staf_3.xlsx"), col_names = TRUE)

#1. Check presence of overlap
id_var <- "PID"
any(combined_R2.1_Staf[[id_var]] %in% combined_R2.2_Staf[[id_var]])

#2. Which PIDs overlap?
intersect(combined_R2.1_Staf[[id_var]], combined_R2.2_Staf[[id_var]])

#3. Table overlap in R2.1 and R2.2
table(df1 = combined_R2.1_Staf[[id_var]] %in% combined_R2.2_Staf[[id_var]])

##RESULT: 34 staff in R2.1 overlaps with R2.2 while 27 only exist in R2.1

################################################################################
####### REMOVE ALL OBJECTS IN WORKPLACE ########
rm(list=ls())

# JOINING OF R2.1 AND R2.2 INTO ONE ROUND 2 DATASET
#####################################
#### Part 6 CONTINUE.  Combine datasets within the same round in wide form
#####################################
root     <- "C:/Users/OrielTsao/Desktop/COVID-19 RCHEs/DATA"
r2_clean <- file.path(root, "1_clean/R2")

combined_R2.1_Staf <- read_excel(file.path(r2_clean, "combined_R2.1_Staf_1.xlsx"), col_names = TRUE)
combined_R2.2_Staf <- read_excel(file.path(r2_clean, "combined_R2.2_Staf_3.xlsx"), col_names = TRUE)

## 1. Make sure everything is character
combined_R2.1_Staf <- combined_R2.1_Staf %>% mutate(across(everything(), as.character))
combined_R2.2_Staf <- combined_R2.2_Staf %>% mutate(across(everything(), as.character))

## 2. Set ID variables for joining
round  <- "round"
id_var <- "PID"
RCHEID <- "RCHEID"

## 3. Join R2.1 and R2.2 side by side by PID (keep anyone who did at least one)
combined_R2_Staf <- full_join(combined_R2.1_Staf,
                              combined_R2.2_Staf,
                              by = c(round, id_var, RCHEID))

## 4. Sort by PID
combined_R2_Staf <- combined_R2_Staf %>%
  arrange(.data[[id_var]])

## save combined_R2_Staf into excel
write.xlsx(combined_R2_Staf,
           file     = file.path(all_rounds_staff, "combined_R2_Staf.xlsx"),
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
#### Part 4. Load raw data, error report, and all needed files
#####################################
root         <- "C:/Users/OrielTsao/Desktop/COVID-19 RCHEs/DATA"
r3_qualtrics <- file.path(root, "0_raw/R3/qualtrics")
r3_clean     <- file.path(root, "1_clean/R3")
all_rounds_staff <- file.path(root, "1_clean/all_rounds/staff")

## 1. Read the R3 survey files (no col names, because first 3 rows are special)
staff1_raw   <- read_excel(file.path(r3_qualtrics, "Staff1_finalvar.xlsx"),   col_names = FALSE)
staff2_raw   <- read_excel(file.path(r3_qualtrics, "Staff2_finalvar.xlsx"),   col_names = FALSE)
staff2.2_raw <- read_excel(file.path(r3_qualtrics, "Staff2.2_finalvar.xlsx"), col_names = FALSE)

#####################################
#### Part 5. Correct raw data according to error report
#####################################
#DOB_DATE
#R3
#E930-2-003: 07/08/1949 -> 27/08/1949
idx <- which(staff2_raw$`...21` == "E930-2-003" & staff2_raw$`...19` == 3) #`...21` = PID, `...19` = round
staff2_raw$`...30`[idx] <- "27/08/1949" # `...30` = dob_date_1

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
    stmt1    = as.character(df[1, ]),
    stmt2    = as.character(df[2, ]),
    finalvar = as.character(df[3, ])
  )
}

staff1_header   <- get_header(staff1_raw)
staff2_header   <- get_header(staff2_raw)
staff2.2_header <- get_header(staff2.2_raw)

## 3. Only keep and set data colnames to final var for cleaning participant data
clean_pdata <- function(df) {
  finalvar    <- as.character(df[3, ])
  df_woheader <- df[-(1:3), ]
  names(df_woheader) <- finalvar
  df_woheader
}

staff1_clean   <- clean_pdata(staff1_raw)
staff2_clean   <- clean_pdata(staff2_raw)
staff2.2_clean <- clean_pdata(staff2.2_raw)

## 4. Prep 1: convert everything to character
staff1_clean   <- staff1_clean   %>% mutate(across(everything(), as.character))
staff2_clean   <- staff2_clean   %>% mutate(across(everything(), as.character))
staff2.2_clean <- staff2.2_clean %>% mutate(across(everything(), as.character))

## 4A. Include only Round 3 Participants
R3_staff1_clean   <- staff1_clean   %>% filter(round == '3')
R3_staff2_clean   <- staff2_clean   %>% filter(round == '3')
R3_staff2.2_clean <- staff2.2_clean %>% filter(round == '3')

## 5. Prep 2: set participant ID and merge name_CHI
id_var    <- "PID"
RCHEID    <- "RCHEID"
round     <- "round"
name_CHI  <- "name_CHI"
lastname  <- "name_CHI_1"
firstname <- "name_CHI_2"

merge_name_CHI <- function(df) {
  df %>%
    mutate(name_CHI = paste(name_CHI_1, name_CHI_2, sep = "")) %>%
    select(-name_CHI_1, -name_CHI_2)
}

R3_staff1_clean <- merge_name_CHI(R3_staff1_clean)
R3_staff2_clean <- merge_name_CHI(R3_staff2_clean)

noprefix_var <- c(id_var, RCHEID, round, name_CHI)

## 6. Prep 3: prefix all final var names with dataset origin
R3_staff1_clean <- R3_staff1_clean %>%
  rename_with(~ paste0("Staff1.", .x), .cols = -all_of(noprefix_var))

R3_staff2_clean <- R3_staff2_clean %>%
  rename_with(~ paste0("Staff2.", .x), .cols = -all_of(noprefix_var))

R3_staff2.2_clean <- R3_staff2.2_clean %>%
  rename_with(~ paste0("Staff2.2.", .x), .cols = -all_of(c(id_var, RCHEID, round)))

## 7. Join surveys within R3 (full join) by PID
combined_R3 <- R3_staff1_clean %>%
  full_join(R3_staff2_clean,   by = c(id_var, RCHEID, round, name_CHI)) %>%
  full_join(R3_staff2.2_clean, by = c(id_var, RCHEID, round))

## 8. Sort by ID
combined_R3 <- combined_R3 %>%
  arrange(.data[[id_var]])

## 9. Reorder colnames to round, RCHEID, PID, name_CHI
combined_R3 <- combined_R3 %>%
  select(round, RCHEID, PID, name_CHI, everything())

## save combined_R3_Staf_1 into excel
write.xlsx(combined_R3,
           file      = file.path(r3_clean, "combined_R3_Staf_1.xlsx"),
           colNames  = TRUE,
           rowNames  = FALSE)

##QC
combined_R3 %>%
  count(PID) %>%
  count(n)

sum(duplicated(combined_R3[[id_var]]))

## Further processing of combined_R3 PID and name_CHI to ensure no PID duplicates
combined_R3_2 <- read_excel(file.path(r3_clean, "combined_R3_Staf_2.xlsx"), col_names = TRUE)

## 1. Convert everything to character
combined_R3_2 <- combined_R3_2 %>%
  mutate(across(everything(), as.character))

## 2. Merge duplicated rows to one row
combined_R3_3 <- combined_R3_2 %>%
  select(-name_CHI) %>%
  mutate(across(everything(), ~na_if(.x, ""))) %>%
  group_by(PID) %>%
  summarise(across(everything(), ~ first(na.omit(.x))))

## 3. Reorder colnames to round, RCHEID, PID, final_name_CHI
combined_R3_3 <- combined_R3_3 %>%
  select(round, RCHEID, PID, final_name_CHI, everything())

## save combined_R3_Staf_3 into excel
write.xlsx(combined_R3_3,
           file     = file.path(all_rounds_staff, "combined_R3_Staf_3.xlsx"),
           colNames = TRUE,
           rowNames = FALSE)

##QC
combined_R3_3 %>%
  count(PID) %>%
  count(n)

sum(duplicated(combined_R3_3[[id_var]]))

################################################################################
####### REMOVE ALL OBJECTS IN WORKPLACE ########
rm(list=ls())

###ALL ROUNDS
#####################################
#### Part 7. Combine datasets across rounds
#####################################
root             <- "C:/Users/OrielTsao/Desktop/COVID-19 RCHEs/DATA"
all_rounds_staff <- file.path(root, "1_clean/all_rounds/staff")
p10d_staff       <- file.path(root, "part10/Part10D1/staff")

## 1. Read R1-R3 clean staff files
R1_raw <- read_excel(file.path(all_rounds_staff, "combined_R1_Staf_3.xlsx"), col_names = TRUE)
R2_raw <- read_excel(file.path(all_rounds_staff, "combined_R2_Staf.xlsx"),   col_names = TRUE)
R3_raw <- read_excel(file.path(all_rounds_staff, "combined_R3_Staf_3.xlsx"), col_names = TRUE)

## 2. Convert everything to character
R1_clean <- R1_raw %>% mutate(across(everything(), as.character))
R3_clean <- R3_raw %>% mutate(across(everything(), as.character))

## 2B. Clean the final_name_CHI columns created by R2.1 and R2.2 join
R2_clean <- R2_raw %>%
  mutate(across(everything(), as.character)) %>%
  mutate(final_name_CHI = coalesce(final_name_CHI.x, final_name_CHI.y)) %>%
  select(-final_name_CHI.x, -final_name_CHI.y)

## 3. Set ID variables
round          <- "round"
RCHEID         <- "RCHEID"
id_var         <- "PID"
final_name_CHI <- "final_name_CHI"

## 4. Join all rounds (full join)
ALLRound <- R1_clean %>%
  full_join(R2_clean, by = c(round, RCHEID, id_var, final_name_CHI)) %>%
  full_join(R3_clean, by = c(round, RCHEID, id_var, final_name_CHI))

## 5. Sort by ID and round
ALLRound <- ALLRound %>%
  arrange(.data[[id_var]], round)

## 6. Reorder colnames to round, RCHEID, PID, final_name_CHI
ALLRound <- ALLRound %>%
  select(round, RCHEID, PID, final_name_CHI, everything())

## save STAFF_ALLRound_withoutspeclog into excel
write.xlsx(ALLRound,
           file      = file.path(p10d_staff, "STAFF_ALLRound_withoutspeclog.xlsx"),
           colNames  = TRUE,
           rowNames  = FALSE)

###
# QC FOR PART 7 - Counting staff PIDs without Staff1 survey
####### REMOVE ALL OBJECTS IN WORKPLACE ########
rm(list=ls())

root             <- "C:/Users/OrielTsao/Desktop/COVID-19 RCHEs/DATA"
all_rounds_staff <- file.path(root, "1_clean/all_rounds/staff")

## 1. Read R1-R3 clean staff files
R1_raw <- read_excel(file.path(all_rounds_staff, "combined_R1_Staf_3.xlsx"), col_names = TRUE)
R2_raw <- read_excel(file.path(all_rounds_staff, "combined_R2_Staf.xlsx"),   col_names = TRUE)
R3_raw <- read_excel(file.path(all_rounds_staff, "combined_R3_Staf_3.xlsx"), col_names = TRUE)

## 2. Convert everything to character
R1_clean <- R1_raw %>% mutate(across(everything(), as.character))
R2_clean <- R2_raw %>% mutate(across(everything(), as.character))
R3_clean <- R3_raw %>% mutate(across(everything(), as.character))

## 3. Set ID variables
round  <- "round"
RCHEID <- "RCHEID"
id_var <- "PID"

## 4. Join all rounds without name_CHI
ALLRoundwoCHI <- R1_clean %>%
  full_join(R2_clean, by = c(round, RCHEID, id_var)) %>%
  full_join(R3_clean, by = c(round, RCHEID, id_var))

## 5. Sort and reorder
ALLRoundwoCHI <- ALLRoundwoCHI %>%
  arrange(.data[[id_var]], round) %>%
  select(round, RCHEID, PID, everything())

## Count PIDs without Staff1 survey
try <- ALLRoundwoCHI %>%
  dplyr::select(!matches("^(Staff1)")) %>%
  dplyr::filter(rowSums(!is.na(dplyr::across(!c(round, PID, RCHEID)))) > 0)

ALLRound_woStaf1 <- try

R1 <- ALLRound_woStaf1 %>% filter(round == "1")
R2 <- ALLRound_woStaf1 %>% filter(round == "2")
R3 <- ALLRound_woStaf1 %>% filter(round == "3")

length(unique(R1$PID))
length(unique(R2$PID))
length(unique(R3$PID))

#####################################
#### Part 8. Re-position columns by category and (within category) by similarity
#####################################
#NOT APPLICABLE

#####################################
#### Part 9.  Prior validation for separate files
#####################################
# DATA ENTRY VETTING conducted in Excel

#END of PART 1-9
################################################################################
################################################################################

#####################################
#### Part 10. Variable Cleaning
#####################################

## Part 10A1: Identify overlapping var-PIDs in R1 EVAX_STAFF and MINI
####### REMOVE ALL OBJECTS IN WORKPLACE ########
rm(list=ls())

root             <- "C:/Users/OrielTsao/Desktop/COVID-19 RCHEs/DATA"
all_rounds_staff <- file.path(root, "1_clean/all_rounds/staff")

## 1. Read R1
R1 <- read_excel(file.path(all_rounds_staff, "combined_R1_Staf_3.xlsx"))

## 2. Define constant ID columns
constant <- c("round", "RCHEID", "PID", "final_name_CHI")

## 3. Subset STAFF and MINI datasets (column-wise)
R1_STAFF <- R1 %>%
  filter(if_any(matches("^STAFF\\."),     ~ !is.na(.))) %>%
  select(all_of(constant), matches("^STAFF\\."))

R1_MINI <- R1 %>%
  filter(if_any(matches("^StaffMINI\\."), ~ !is.na(.))) %>%
  select(all_of(constant), matches("^StaffMINI\\."))

R1_Staff_PID <- R1_STAFF %>% pull(PID)
R1_MINI_PID  <- R1_MINI  %>% pull(PID)

overlap_PID_R1 <- tibble(PID = intersect(R1_Staff_PID, R1_MINI_PID))

##Conclusion: ALL MINI vars overlap but straightforward hierarchy (MINI >> STAFF) so will fix in variable mapping

################################################################################
## Part 10A2: Identify overlap var-PIDs in R2: R2.1 Staff Basic and R2.2 Qualtrics
####### REMOVE ALL OBJECTS IN WORKPLACE ########
rm(list=ls())

root             <- "C:/Users/OrielTsao/Desktop/COVID-19 RCHEs/DATA"
all_rounds_staff <- file.path(root, "1_clean/all_rounds/staff")

## 1. Read R2
R2 <- read_excel(file.path(all_rounds_staff, "combined_R2_Staf.xlsx"))

## 1B. Clean the final_name_CHI between R2.1 and R2.2
R2 <- R2 %>%
  mutate(across(everything(), as.character)) %>%
  mutate(final_name_CHI = coalesce(final_name_CHI.x, final_name_CHI.y)) %>%
  select(-final_name_CHI.x, -final_name_CHI.y)

## 2. Define constant ID columns
constant <- c("round", "RCHEID", "PID", "final_name_CHI")

## 3. Subset each staff dataset (column-wise)
R2.1_Staff <- R2 %>%
  filter(if_any(matches("^R2.1StaffBasic\\."), ~ !is.na(.))) %>%
  select(all_of(constant), matches("^R2.1StaffBasic\\."))

R2.2_Staff1 <- R2 %>%
  filter(if_any(matches("^Staff1\\."),   ~ !is.na(.))) %>%
  select(all_of(constant), matches("^Staff1\\."))

R2.2_Staff2 <- R2 %>%
  filter(if_any(matches("^Staff2\\."),   ~ !is.na(.))) %>%
  select(all_of(constant), matches("^Staff2\\."))

R2.2_Staff2.2 <- R2 %>%
  filter(if_any(matches("^Staff2.2\\."), ~ !is.na(.))) %>%
  select(all_of(constant), matches("^Staff2.2\\."))

R2.1_Staff_PID    <- R2.1_Staff    %>% pull(PID)
R2.2_Staff1_PID   <- R2.2_Staff1   %>% pull(PID)
R2.2_Staff2_PID   <- R2.2_Staff2   %>% pull(PID)
R2.2_Staff2.2_PID <- R2.2_Staff2.2 %>% pull(PID)

## Overlapping PIDs
overlap_PID_R2.1_Staff1   <- tibble(PID = intersect(R2.1_Staff_PID, R2.2_Staff1_PID))
overlap_PID_R2.1_Staff2   <- tibble(PID = intersect(R2.1_Staff_PID, R2.2_Staff2_PID))
overlap_PID_R2.1_Staff2.2 <- tibble(PID = intersect(R2.1_Staff_PID, R2.2_Staff2.2_PID))

#RESULTS: no overlap for Staff2 and Staff2.2; only 34 overlapping PIDs for Staff1
#CONCLUSION: ignore 34 matching PIDs for Staff1 as no matching vars

##END OF PART 10A
# PART 10B, 10C - NOT APPLICABLE
# OVERLAPPING VARS/PID CAN BE RESOLVED DIRECTLY IN PART 10R

################################################################################
####### REMOVE ALL OBJECTS IN WORKPLACE ########
rm(list=ls())

## Part 10D1: Cross-Round FINAL Master Dataset Construction
root         <- "C:/Users/OrielTsao/Desktop/COVID-19 RCHEs/DATA"
p10d_staff   <- file.path(root, "part10/Part10D1/staff")
summary_docs <- file.path(root, "Summary docs")

## 1. Read files
ALL_Round_wospeclog <- read_excel(file.path(p10d_staff, "STAFF_ALLRound_withoutspeclog.xlsx"),
                                  col_names = TRUE,
                                  col_types = "text")
spec_log_raw        <- read_excel(file.path(p10d_staff, "evax_specimenlog_dated20250718.xlsx"),
                                  col_names = TRUE)
consent_df          <- read_excel(file.path(summary_docs, "consent_archive_protected_dated05122025.xlsx"),
                                  sheet = "Staff_dated20251205")

## 2. Convert all to character
ALL_Round_wospeclog <- ALL_Round_wospeclog %>% mutate(across(everything(), as.character))
spec_log_clean      <- spec_log_raw        %>% mutate(across(everything(), as.character))
consent_df          <- consent_df          %>% mutate(across(everything(), as.character))

## 3. Prep spec_log for joining
# Prep 1: join subid1, subid2, subid3 to PID
spec_log_clean$PID <- paste(spec_log_clean$subid1,
                            spec_log_clean$subid2,
                            spec_log_clean$subid3, sep = "-")

# Prep 2: Change Subject ID in consent_df to PID
consent_df$PID <- consent_df$`Subject ID`

# Prep 3: Keep only Staff in spec_log (subid2 != 1)
spec_log_clean <- spec_log_clean %>% filter(subid2 != 1)

# Prep 4: Standardize PID format
spec_log_clean <- spec_log_clean %>%
  mutate(PID         = str_trim(PID),
         PID         = str_replace_all(PID, "\\s", ""),
         PID         = toupper(PID),
         EVAX_Status = str_trim(EVAX_Status),
         EVAX_Status = str_replace_all(EVAX_Status, "\\s", ""))

consent_df <- consent_df %>%
  mutate(PID           = str_trim(PID),
         PID           = str_replace_all(PID, "\\s", ""),
         PID           = toupper(PID),
         `Study Round` = str_trim(`Study Round`),
         `Study Round` = str_replace_all(`Study Round`, "\\s", ""),
         `Study Round` = toupper(`Study Round`))

# Prep 5: Hard code PID corrections from spec log comments
spec_log_clean <- spec_log_clean %>%
  mutate(PID = ifelse(PID == "E905-2-013" & str_detect(labserial, "on366"),  "E905-2-023", PID),
         PID = ifelse(PID == "E928-2-001" & str_detect(labserial, "on1072"), "E927-2-001", PID),
         PID = ifelse(PID == "E928-2-004" & str_detect(labserial, "on1071"), "E927-2-004", PID))

##QC: all spec_log PIDs inside consent_df
all(spec_log_clean$PID %in% consent_df$PID) #RESULT: TRUE

# Prep 6: Transform into date format
consent_df <- consent_df %>%
  mutate(
    raw_date     = `Document date\r\n(dd/mm/yyyy)`,
    consent_date = case_when(
      grepl("^[0-9]+$", raw_date) ~ excel_numeric_to_date(as.numeric(raw_date)),
      grepl("/",         raw_date) ~ dmy(raw_date),
      TRUE                        ~ as.Date(NA)
    )
  )

spec_log_clean <- spec_log_clean %>% mutate(cdate = as.Date(ymd(cdate)))
consent_df     <- consent_df     %>% mutate(consent_date = as.Date(consent_date))

## 4. Assign round and RCHEID to spec_log
spec_log_clean <- spec_log_clean %>%
  mutate(round = case_when(
    is.na(EVAX_Status)        ~ 1,
    EVAX_Status == "Round1"   ~ 2,
    EVAX_Status == "Round2"   ~ 2,
    EVAX_Status == "Round3"   ~ 3,
    TRUE                      ~ NA_real_
  )) %>%
  mutate(RCHEID = substr(as.character(PID), 1, 4))

R1_blood_data <- spec_log_clean %>% filter(round == 1)
R2_blood_data <- spec_log_clean %>% filter(round == 2)
R3_blood_data <- spec_log_clean %>% filter(round == 3)

consent_df_R1 <- consent_df %>% filter(!(`Study Round` %in% c("2", "3")))
consent_df_R2 <- consent_df %>% filter(!(`Study Round` %in% c("1", "3")))
consent_df_R3 <- consent_df %>% filter(!(`Study Round` %in% c("2", "1")))

# QC: all blood PIDs have consent
all(R1_blood_data$PID %in% consent_df_R1$PID) #RESULT: TRUE
all(R2_blood_data$PID %in% consent_df_R2$PID) #RESULT: TRUE
all(R3_blood_data$PID %in% consent_df_R3$PID) #RESULT: TRUE

## 5. Join R1-R3 blood data and add prefix
PID    <- "PID"
RCHEID <- "RCHEID"
round  <- "round"

ALL_blood_data <- bind_rows(R1_blood_data, R2_blood_data, R3_blood_data) %>%
  arrange(.data[[PID]]) %>%
  select(round, RCHEID, PID, everything()) %>%
  rename_with(~ paste0("blood.", .x), .cols = -all_of(c(PID, RCHEID, round))) %>%
  mutate(across(everything(), as.character))

## 6. Join all R1-R3 survey data + blood data
id_var         <- "PID"
final_name_CHI <- "final_name_CHI"

ALLRound <- ALL_Round_wospeclog %>%
  full_join(ALL_blood_data, by = c("PID", "round"))

## 7A. Ensure RCHEID is complete
ALLRound <- ALLRound %>%
  mutate(RCHEID = substr(PID, 1, 4))
ALLRound$RCHEID.x <- NULL
ALLRound$RCHEID.y <- NULL

## 7B. Remove stray NA in final_name_CHI
ALLRound <- ALLRound %>%
  mutate(final_name_CHI = str_remove_all(final_name_CHI, "NA"))

## 8. Sort, reorder and convert to character
ALLRound <- ALLRound %>%
  arrange(.data[[id_var]], round) %>%
  select(round, RCHEID, PID, final_name_CHI, everything()) %>%
  mutate(across(everything(), as.character))

## save ALLRound_STAFF into excel
write.xlsx(ALLRound,
           file      = file.path(p10d_staff, "ALLRound_STAFF.xlsx"),
           colNames  = TRUE,
           rowNames  = FALSE)

#END of PART 10D
## QC: check R1 blood cdate is after consent_date
# CONCLUSION: YES, except E105-2-001 (missing consent)
blood_df <- spec_log_clean %>% filter(round == 1)

finalwmissing_df <- blood_df %>%
  filter(PID %in% consent_df_R1$PID) %>%
  left_join(consent_df_R1, by = "PID") %>%
  group_by(PID) %>%
  slice_min(
    order_by  = ifelse(cdate >= consent_date, cdate - consent_date, NA),
    n         = 1,
    with_ties = FALSE
  ) %>%
  ungroup() %>%
  mutate(cdate = if_else(cdate < consent_date, as.Date(NA), cdate))

failed_matches <- finalwmissing_df %>% filter(is.na(cdate))

## Part 10D QC - Count PIDs per round
R1 <- ALLRound %>% filter(round == "1")
R2 <- ALLRound %>% filter(round == "2")
R3 <- ALLRound %>% filter(round == "3")

length(unique(R1$PID)) # 260
length(unique(R2$PID)) # 462
length(unique(R3$PID)) # 524

## Count PIDs without Staff1 survey
try <- ALLRound %>%
  dplyr::select(!matches("^(Staff1)")) %>%
  dplyr::filter(rowSums(!is.na(dplyr::across(!c(round, PID, RCHEID, final_name_CHI)))) > 0)

ALLRound_woStaf1 <- try

R1 <- ALLRound_woStaf1 %>% filter(round == "1")
R2 <- ALLRound_woStaf1 %>% filter(round == "2")
R3 <- ALLRound_woStaf1 %>% filter(round == "3")

length(unique(R1$PID)) # 260
length(unique(R2$PID)) # 332
length(unique(R3$PID)) # 308

### END OF STAFF PART 1-10D1
