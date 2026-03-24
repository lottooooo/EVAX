#############
#PRINTING - line number
root    <- "C:/Users/OrielTsao/Desktop/COVID-19 RCHEs/data"
scripts <- file.path(root, "scripts")

lines <- readLines(file.path(scripts, "RCHE_Part1-10.R"))
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

writeLines(html_content, file.path(scripts, "RCHE_Part1-10.R.html"))
###########

####### REMOVE ALL OBJECTS IN WORKPLACE ########
rm(list=ls())

###LOAD all packages###
library(readxl)
library(dplyr)
library(stringr)
library(purrr)
library(openxlsx)

################################################################################
##ROUND 1 ###
####### REMOVE ALL OBJECTS IN WORKPLACE ########
rm(list=ls())

root            <- "C:/Users/OrielTsao/Desktop/COVID-19 RCHEs/data"
r1_qualtrics    <- file.path(root, "0_raw/R1/qualtrics")
r1_other        <- file.path(root, "0_raw/R1/other")
all_rounds_rche <- file.path(root, "1_clean/all_rounds/rche")

## 1. Read the R1 survey files
INSMAIN_raw <- read_excel(file.path(r1_qualtrics, "EVAX_INSMAIN_TEXT_finalvar.xlsx"), col_names = FALSE)
RCHE_raw    <- read_excel(file.path(r1_other,     "EVAX_RCHE.xlsx"),                  col_names = TRUE)

## 2. Correct to desired colnames as header
# INSMAIN: col_names = FALSE, rows 1-2 are header rows, row 1 of data is final var
rm_stat2 <- function(df) {
  df[-(1:2), ]
}

INSMAIN_clean <- rm_stat2(INSMAIN_raw)

header_row2 <- function(df) {
  colnames(df) <- as.character(unlist(df[1, ]))
  df <- df[-(1:2), ]
  return(df)
}

INSMAIN_clean <- header_row2(INSMAIN_clean)

## 3. Prep 1: convert everything to character
INSMAIN_clean <- INSMAIN_clean %>% mutate(across(everything(), as.character))
RCHE_clean    <- RCHE_raw      %>% mutate(across(everything(), as.character))

## 4. Prep 2: ensure RCHEID is in format "EXXX"
fullRCHEID <- function(df) {
  df$RCHEID <- paste0("E", df$RCHEID)
  return(df)
}

INSMAIN_clean <- fullRCHEID(INSMAIN_clean)
RCHE_clean    <- fullRCHEID(RCHE_clean)

## 5. Prep 3: prefix all final var names with dataset origin
RCHEID <- "RCHEID"

INSMAIN_clean <- INSMAIN_clean %>%
  rename_with(~ paste0("RCHEINSMAIN.", .x), .cols = -all_of(RCHEID))

RCHE_clean <- RCHE_clean %>%
  rename_with(~ paste0("RCHEBasic.", .x), .cols = -all_of(RCHEID))

## 6. Join within R1 (full join) by RCHEID
combined_R1_RCHE_1 <- INSMAIN_clean %>%
  full_join(RCHE_clean, by = RCHEID)

combined_R1_RCHE_1$round <- 1

## 7. Sort by RCHEID
combined_R1_RCHE_1 <- combined_R1_RCHE_1 %>%
  arrange(.data[[RCHEID]])

## 8. Reorder colnames to round, RCHEID
combined_R1_RCHE_1 <- combined_R1_RCHE_1 %>%
  select(round, RCHEID, everything())

## save combined_R1_RCHE_1 into excel
write.xlsx(combined_R1_RCHE_1,
           file     = file.path(all_rounds_rche, "combined_R1_RCHE_1.xlsx"),
           colNames = TRUE,
           rowNames = FALSE)

##QC - no duplicate RCHEID
combined_R1_RCHE_1 %>%
  count(RCHEID) %>%
  count(n)

sum(duplicated(combined_R1_RCHE_1[[RCHEID]]))
unique(combined_R1_RCHE_1$RCHEID[duplicated(combined_R1_RCHE_1$RCHEID)])

################################################################################
##ROUND 2.2 ###
####### REMOVE ALL OBJECTS IN WORKPLACE ########
rm(list=ls())

root            <- "C:/Users/OrielTsao/Desktop/COVID-19 RCHEs/data"
r2.2_qualtrics  <- file.path(root, "0_raw/R2/R2.2_qualtrics")
all_rounds_rche <- file.path(root, "1_clean/all_rounds/rche")

## 1. Read the survey file (no col names, first 3 rows are special)
## Note: R2.2 and R3 both use RCHE_finalvar.xlsx - filtered by round below
RCHE_raw <- read_excel(file.path(r2.2_qualtrics, "RCHE_finalvar.xlsx"), col_names = FALSE)

## 2. Pull out the 3 header rows
get_header <- function(df) {
  list(
    stmt1    = as.character(df[1, ]),
    stmt2    = as.character(df[2, ]),
    finalvar = as.character(df[3, ])
  )
}

RCHE_header <- get_header(RCHE_raw)

## 3. Set data colnames to final var
clean_pdata <- function(df) {
  finalvar    <- as.character(df[3, ])
  df_woheader <- df[-(1:3), ]
  names(df_woheader) <- finalvar
  df_woheader
}

RCHE_clean <- clean_pdata(RCHE_raw)

## 4. Prep 1: convert everything to character
RCHE_clean <- RCHE_clean %>% mutate(across(everything(), as.character))

## 4A. Include only Round 2 participants
R2_RCHE_clean <- RCHE_clean %>% filter(round == '2')

## 5. Prep 2: prefix all final var names with dataset origin
RCHEID       <- "RCHEID"
round        <- "round"
noprefix_var <- c(round, RCHEID)

combined_R2_RCHE_1 <- R2_RCHE_clean %>%
  rename_with(~ paste0("R2RCHE.", .x), .cols = -all_of(noprefix_var))

## 6. Sort by RCHEID
combined_R2_RCHE_1 <- combined_R2_RCHE_1 %>%
  arrange(.data[[RCHEID]])

## 7. Reorder colnames to round, RCHEID
combined_R2_RCHE_1 <- combined_R2_RCHE_1 %>%
  select(round, RCHEID, everything())

## save combined_R2.2_RCHE_1 into excel
write.xlsx(combined_R2_RCHE_1,
           file     = file.path(all_rounds_rche, "combined_R2.2_RCHE_1.xlsx"),
           colNames = TRUE,
           rowNames = FALSE)

##QC
combined_R2_RCHE_1 %>%
  count(RCHEID) %>%
  count(n)

################################################################################
##ROUND 3 ###
####### REMOVE ALL OBJECTS IN WORKPLACE ########
rm(list=ls())

root            <- "C:/Users/OrielTsao/Desktop/COVID-19 RCHEs/data"
r2.2_qualtrics  <- file.path(root, "0_raw/R2/R2.2_qualtrics") # same raw file as R2.2
all_rounds_rche <- file.path(root, "1_clean/all_rounds/rche")

## 1. Read the survey file (no col names, first 3 rows are special)
## Note: R2.2 and R3 both use RCHE_finalvar.xlsx - filtered by round below
RCHE_raw <- read_excel(file.path(r2.2_qualtrics, "RCHE_finalvar.xlsx"), col_names = FALSE)

## 2. Pull out the 3 header rows
get_header <- function(df) {
  list(
    stmt1    = as.character(df[1, ]),
    stmt2    = as.character(df[2, ]),
    finalvar = as.character(df[3, ])
  )
}

RCHE_header <- get_header(RCHE_raw)

## 3. Set data colnames to final var
clean_pdata <- function(df) {
  finalvar    <- as.character(df[3, ])
  df_woheader <- df[-(1:3), ]
  names(df_woheader) <- finalvar
  df_woheader
}

RCHE_clean <- clean_pdata(RCHE_raw)

## 4. Prep 1: convert everything to character
RCHE_clean <- RCHE_clean %>% mutate(across(everything(), as.character))

## 4A. Include only Round 3 participants
R3_RCHE_clean <- RCHE_clean %>% filter(round == '3')

## 5. Prep 2: prefix all final var names with dataset origin
RCHEID       <- "RCHEID"
round        <- "round"
noprefix_var <- c(round, RCHEID)

combined_R3_RCHE_1 <- R3_RCHE_clean %>%
  rename_with(~ paste0("R3RCHE.", .x), .cols = -all_of(noprefix_var))

## 6. Sort by RCHEID
combined_R3_RCHE_1 <- combined_R3_RCHE_1 %>%
  arrange(.data[[RCHEID]])

## 7. Reorder colnames to round, RCHEID
combined_R3_RCHE_1 <- combined_R3_RCHE_1 %>%
  select(round, RCHEID, everything())

## save combined_R3_RCHE_1 into excel
write.xlsx(combined_R3_RCHE_1,
           file     = file.path(all_rounds_rche, "combined_R3_RCHE_1.xlsx"),
           colNames = TRUE,
           rowNames = FALSE)

##QC
combined_R3_RCHE_1 %>%
  count(RCHEID) %>%
  count(n)

#END OF PART 1-9
################################################################################
####### REMOVE ALL OBJECTS IN WORKPLACE ########
rm(list=ls())

###PART 10D1: ALL ROUND joining combined_R1 to R3###
root            <- "C:/Users/OrielTsao/Desktop/COVID-19 RCHEs/data"
all_rounds_rche <- file.path(root, "1_clean/all_rounds/rche")
p10d_rche       <- file.path(root, "part10/10d/rche")

## 1. Read R1-R3 clean RCHE files
R1_raw <- read_excel(file.path(all_rounds_rche, "combined_R1_RCHE_1.xlsx"),   col_names = TRUE)
R2_raw <- read_excel(file.path(all_rounds_rche, "combined_R2.2_RCHE_1.xlsx"), col_names = TRUE)
R3_raw <- read_excel(file.path(all_rounds_rche, "combined_R3_RCHE_1.xlsx"),   col_names = TRUE)

## 2. Convert everything to character
R1_clean <- R1_raw %>% mutate(across(everything(), as.character))
R2_clean <- R2_raw %>% mutate(across(everything(), as.character))
R3_clean <- R3_raw %>% mutate(across(everything(), as.character))

## 3. Set ID variables
round  <- "round"
RCHEID <- "RCHEID"

## 4. Join all rounds (full join) by round and RCHEID
ALLRound <- R1_clean %>%
  full_join(R2_clean, by = c(round, RCHEID)) %>%
  full_join(R3_clean, by = c(round, RCHEID))

## 5. Create unique_RCHEID to map old RCHEID codes to new ones
ALLRound$unique_RCHEID <- ALLRound$RCHEID

ALLRound$unique_RCHEID[ALLRound$unique_RCHEID == "E201"] <- "E947"
ALLRound$unique_RCHEID[ALLRound$unique_RCHEID == "E003"] <- "E948"
ALLRound$unique_RCHEID[ALLRound$unique_RCHEID == "E005"] <- "E961"

unique_RCHEID <- "unique_RCHEID"

## 6. Sort by unique_RCHEID, RCHEID, round
ALLRound <- ALLRound %>%
  arrange(.data[[unique_RCHEID]], RCHEID, round)

## 7. Reorder colnames to round, RCHEID, unique_RCHEID
ALLRound <- ALLRound %>%
  select(round, RCHEID, unique_RCHEID, everything())

## save RCHE_ALLRound into excel
write.xlsx(ALLRound,
           file     = file.path(p10d_rche, "RCHE_ALLRound.xlsx"),
           colNames = TRUE,
           rowNames = FALSE)

#END of Part 10D
