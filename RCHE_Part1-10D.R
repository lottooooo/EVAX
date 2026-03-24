#############
#PRINTING - line number
root    <- "C:/Users/OrielTsao/Desktop/COVID-19 RCHEs/DATA"
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

#####################################
#### Part 1. Coding consensus
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

################################################################################
##ROUND 1 ###
####### REMOVE ALL OBJECTS IN WORKPLACE ########
rm(list=ls())

#####################################
#### Part 3. Manually add the final variable names as the third header row in raw data
#####################################
#MANUALLY ADDED TO EXCEL

#####################################
#### Part 4. Load raw data, error report, and all needed files
#####################################
root            <- "C:/Users/OrielTsao/Desktop/COVID-19 RCHEs/DATA"
r1_qualtrics    <- file.path(root, "0_raw/R1/qualtrics")
r1_other        <- file.path(root, "0_raw/R1/other")
all_rounds_rche <- file.path(root, "1_clean/all_rounds/rche")

## 1. Read the R1 survey files
INSMAIN_raw <- read_excel(file.path(r1_qualtrics, "EVAX_INSMAIN_TEXT_finalvar.xlsx"), col_names = FALSE)
RCHE_raw    <- read_excel(file.path(r1_other,     "EVAX_RCHE.xlsx"),                  col_names = TRUE)

#####################################
#### Part 5. Correct raw data according to error report
#####################################
#NOT APPLICABLE

#####################################
#### Part 6. Combine datasets within the same round in wide form
#####################################

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
RCHEID <- "RCHE
