#############
#PRINTING - line number
root    <- "C:/Users/OrielTsao/Desktop/COVID-19 RCHEs/DATA"
scripts <- file.path(root, "scripts")
lines <- readLines(file.path(scripts, "Resident_Part10A-D.R"))
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
writeLines(html_content, file.path(scripts, "Resident_Part10A-D.R.html"))
###########

####### REMOVE ALL OBJECTS IN WORKPLACE ########
rm(list=ls())

###LOAD all packages###
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
### PART 10A: Identify overlapping var-PIDs between R1 datasets

### PART 10A1: Overlap between Qualtrics surveys
## Namely between EVAX_INS and EVAX_Main
####### REMOVE ALL OBJECTS IN WORKPLACE ########
rm(list=ls())

root         <- "C:/Users/OrielTsao/Desktop/COVID-19 RCHEs/DATA"
r1_qualtrics <- file.path(root, "0_raw/R1/qualtrics")
p10a1        <- file.path(root, "part10/10a/10A1")

## 1A. Read Qualtrics R1 files
residentINS_raw      <- read_excel(file.path(r1_qualtrics, "EVAX_Institution.xlsx"), col_names = TRUE)
residentMAINIADL_raw <- read_excel(file.path(r1_qualtrics, "EVAX_Main_IADL.xlsx"),   col_names = TRUE)
residentVISVH_raw    <- read_excel(file.path(r1_qualtrics, "EVAX_VIS_VH.xlsx"),       col_names = TRUE)

## 2. Remove statement2 from header (col_names = TRUE so row 1 is already colname)
rm_stat2 <- function(df) {
  df[-(1), ]
}

residentINS_clean      <- rm_stat2(residentINS_raw)
residentMAINIADL_clean <- rm_stat2(residentMAINIADL_raw)
residentVISVH_clean    <- rm_stat2(residentVISVH_raw)

## EVAX_INS and EVAX_MAIN
# 1. Only include PIDs from EVAX_MAIN in new df
MAIN_residentINS_clean_1 <- residentINS_clean %>%
  filter(PID %in% residentMAINIADL_clean$PID)

# 2. Only include matching varnames in new INS df + manually add matching var from Resident_R2 Variable Matching to R1.xlsx
varlist_INS <- read_excel(file.path(p10a1, "varlist_INS.xlsx"), sheet = "MAIN", col_names = FALSE) %>%
  pull(1) %>%
  as.character() %>%
  unique()

MAIN_residentINS_clean_2 <- MAIN_residentINS_clean_1 %>%
  select(
    any_of(names(residentMAINIADL_clean)),
    any_of(varlist_INS)
  )

## 3. Filter MAIN so it only includes PIDs that are in INS
MAIN_residentMAINIADL_clean_1 <- residentMAINIADL_clean %>%
  filter(PID %in% residentINS_clean$PID)

## 4. Only include matching varnames in new MAIN df
varlist_INS <- read_excel(file.path(p10a1, "varlist_INS.xlsx"), sheet = "MAIN", col_names = FALSE) %>%
  pull(1) %>%
  as.character() %>%
  unique()

MAIN_residentMAINIADL_clean_2 <- MAIN_residentMAINIADL_clean_1 %>%
  select(
    any_of(names(residentINS_clean)),
    any_of(varlist_INS)
  )

## Save MAIN_residentINS_clean_2 and MAIN_residentMAINIADL_clean_2 for manual comparison
write_xlsx(MAIN_residentINS_clean_2,      file.path(p10a1, "MAIN_residentINS_clean_2.xlsx"))
write_xlsx(MAIN_residentMAINIADL_clean_2, file.path(p10a1, "MAIN_residentMAINIADL_clean_2.xlsx"))

## Further checking which varnames are not empty/missing/unknown values in EVAX_INS
allowed <- c("", "Unknown", "不清楚", "不清楚/暫未發現")

cols_with_other_values <- names(MAIN_residentINS_clean_2)[
  map_lgl(MAIN_residentINS_clean_2, ~ any(!(.x %in% allowed) & !is.na(.x)))
]
cols_with_other_values

# List the PIDs that have values not in ALLOWED for each variable in cols_with_other_values
cols_filtered <- cols_with_other_values[-(1:16)]

invalid_pid_list <- map(cols_filtered, function(colname) {
  MAIN_residentINS_clean_2 %>%
    filter(
      !(as.character(.data[[colname]]) %in% allowed) &
        !is.na(.data[[colname]])
    ) %>%
    pull(PID) %>%
    unique()
})

names(invalid_pid_list) <- cols_filtered
invalid_pid_list

## Create new DF comparing cols_filtered variables in both INS and MAIN by PID
# 1. All PIDs that have any non-ALLOWED value in INS for any of the selected columns
pids_to_keep <- invalid_pid_list %>%
  unlist() %>%
  unique()

## 2. Build MAIN side columns (suffix _MAIN)
main_side <- MAIN_residentMAINIADL_clean_2 %>%
  filter(PID %in% pids_to_keep) %>%
  select(RCHEID, PID, name_CHI, all_of(cols_filtered)) %>%
  rename_with(~ paste0(., "_MAIN"), all_of(cols_filtered))

## 3. Build INS side (suffix _INS)
ins_side <- MAIN_residentINS_clean_2 %>%
  filter(PID %in% pids_to_keep) %>%
  select(RCHEID, PID, name_CHI, all_of(cols_filtered)) %>%
  rename_with(~ paste0(., "_INS"), all_of(cols_filtered))

## 4. Join to one DF
MAIN_residentMAINIADL_clean_3 <- main_side %>%
  full_join(ins_side, by = c("RCHEID", "PID"))

## 5. Reorder cols into MAIN/INS pairs
ordered_cols <- c(
  "RCHEID",
  "PID",
  as.vector(rbind(paste0(cols_filtered, "_MAIN"), paste0(cols_filtered, "_INS")))
)

MAIN_residentMAINIADL_clean_3 <- MAIN_residentMAINIADL_clean_3 %>%
  select(any_of(ordered_cols))

## Save for manual comparison
write_xlsx(MAIN_residentMAINIADL_clean_3, file.path(p10a1, "MAIN_residentMAINIADL_clean_3.xlsx"))

##CONCLUSION: 99 PIDs with 74 vars overlapping between INS and MAIN

################################################################################
####### REMOVE ALL OBJECTS IN WORKPLACE ########
rm(list=ls())

### Part 10A2: SM vs Qualtrics
root           <- "C:/Users/OrielTsao/Desktop/COVID-19 RCHEs/DATA"
r1_qualtrics   <- file.path(root, "0_raw/R1/qualtrics")
r1_surveymonkey <- file.path(root, "0_raw/R1/surveymonkey")
r1_other       <- file.path(root, "0_raw/R1/other")

## 1A. Qualtrics
residentINS_raw      <- read_excel(file.path(r1_qualtrics, "EVAX_Institution.xlsx"),  col_names = TRUE)
residentMAINIADL_raw <- read_excel(file.path(r1_qualtrics, "EVAX_Main_IADL.xlsx"),    col_names = TRUE)
residentVISVH_raw    <- read_excel(file.path(r1_qualtrics, "EVAX_VIS_VH.xlsx"),        col_names = TRUE)
residentMC_raw       <- read_excel(file.path(r1_qualtrics, "EVAX_MiniCog.xlsx"),       col_names = TRUE)

## 1B. SurveyMonkey
residentSM_raw <- read_excel(file.path(r1_surveymonkey, "EVAX_SMTEXT.xlsx"), col_names = FALSE)

## 1C. Other datasets: EVAX_MINI
residentMINI_raw <- read_excel(file.path(r1_other, "MINI_Resident_dated20221228.xlsx"), col_names = FALSE)

## 2. Correct to desired colnames as header
# Qualtrics: col_names = TRUE so row 1 is already colname, remove statement 2
rm_stat2 <- function(df) {
  df[-(1), ]
}

residentINS_clean      <- rm_stat2(residentINS_raw)
residentMAINIADL_clean <- rm_stat2(residentMAINIADL_raw)
residentVISVH_clean    <- rm_stat2(residentVISVH_raw)
residentMC_clean       <- rm_stat2(residentMC_raw)

# SurveyMonkey: row 3 is header
header_row3 <- function(df) {
  colnames(df) <- as.character(unlist(df[3, ]))
  df <- df[-(1:3), ]
  return(df)
}

residentSM_clean <- header_row3(residentSM_raw)

# MINI: row 2 is header
header_row2 <- function(df) {
  colnames(df) <- as.character(unlist(df[2, ]))
  df <- df[-(1:2), ]
  return(df)
}

residentMINI_clean <- header_row2(residentMINI_raw)

## 3. Prep 1: convert everything to character
residentINS_clean      <- residentINS_clean      %>% mutate(across(everything(), as.character))
residentMAINIADL_clean <- residentMAINIADL_clean %>% mutate(across(everything(), as.character))
residentVISVH_clean    <- residentVISVH_clean    %>% mutate(across(everything(), as.character))
residentMC_clean       <- residentMC_clean       %>% mutate(across(everything(), as.character))
residentSM_clean       <- residentSM_clean       %>% mutate(across(everything(), as.character))
residentMINI_clean     <- residentMINI_clean     %>% mutate(across(everything(), as.character))

## 4. Make sure core joining variables are the same
fullPID <- function(df) {
  df$PID <- paste0(df$RCHEID, "-1-", df$PID)
  return(df)
}

residentSM_clean <- fullPID(residentSM_clean)

# Function: overlap of column names between two dfs
overlap_vars <- function(sm_df, other_df, other_name = "OTHER") {
  sm_vars    <- names(sm_df)    %>% as.character()
  other_vars <- names(other_df) %>% as.character()

  shared     <- intersect(sm_vars, other_vars)
  sm_only    <- setdiff(sm_vars, other_vars)
  other_only <- setdiff(other_vars, sm_vars)

  list(
    other     = other_name,
    n_sm      = length(sm_vars),
    n_other   = length(other_vars),
    n_shared  = length(shared),
    shared    = sort(shared),
    sm_only   = sort(sm_only),
    other_only = sort(other_only)
  )
}

# Run for each dataset
ov_INS  <- overlap_vars(residentSM_clean, residentINS_clean,      "INS")
ov_MAIN <- overlap_vars(residentSM_clean, residentMAINIADL_clean, "MAIN_IADL")
ov_VIS  <- overlap_vars(residentSM_clean, residentVISVH_clean,    "VISVH")
ov_MC   <- overlap_vars(residentSM_clean, residentMC_clean,       "MC")
ov_MINI <- overlap_vars(residentSM_clean, residentMINI_clean,     "MINI")

# View shared vars
ov_INS$n_shared;  ov_INS$shared  # 189 vars overlap
ov_MAIN$n_shared; ov_MAIN$shared # 144 vars overlap
ov_VIS$n_shared;  ov_VIS$shared  # 81 vars overlap
ov_MC$n_shared;   ov_MC$shared   # 23 vars overlap
ov_MINI$n_shared; ov_MINI$shared # 7 vars overlap

#END OF PART 10A
################################################################################
####### REMOVE ALL OBJECTS IN WORKPLACE ########
rm(list=ls())

### Part 10B1: Within-Round Harmonisation of R1 INS & MAIN
## WITHIN DECISION MATRIX (only parent)
## Requires: overlap_R1_wide, R1 Overlay map (overlapping vars & within_decision_matrix)

root    <- "C:/Users/OrielTsao/Desktop/COVID-19 RCHEs/DATA"
r1_clean <- file.path(root, "1_clean/R1")
p10b1   <- file.path(root, "part10/10b/Part10B1")

## 1. Read R1 clean dataset and metadata
R1_wide      <- read_excel(file.path(r1_clean, "combined_R1_Res_3.xlsx"))
overlap_PIDs <- read_excel(file.path(p10b1,    "MAIN_residentMAINIADL_clean_finalcompare.xlsx"))
var_map      <- read_excel(file.path(p10b1,    "R1_overlay_map_23122025.xlsx"), sheet = "Overlapping_vars")
within_code  <- read_excel(file.path(p10b1,    "R1_overlay_map_23122025.xlsx"), sheet = "within_decision_matrix")

## Step 1: Filter overlay map to parent vars only
## Create new R1_wide df that only contains overlapping PIDs between INS and MAIN
overlap_R1_wide <- R1_wide %>%
  filter(PID %in% overlap_PIDs$PID)

parent_var_map <- var_map %>% filter(Concept %in% c("LTI", "HOS_SYMP", "LCOV"))

## Step 2: Standardise column names to include _MAIN and _INS in parent_var_map
# Helper: split "a; b; c" into c("a","b","c"), safely
split_semicol <- function(x) {
  if (is.na(x) || trimws(x) == "") return(character(0))
  str_split(x, "\\s*;\\s*", simplify = FALSE)[[1]] |> trimws()
}

# Build a per-parent-concept lookup table
parent_cols <- parent_var_map %>%
  transmute(
    concept             = Concept,
    parent_main         = first_main,
    parent_ins          = first_ins,
    breakdown_base_main = map(breakdown_main, split_semicol),
    breakdown_base_ins  = map(breakdown_ins,  split_semicol)
  ) %>%
  mutate(
    breakdown_main = map(breakdown_base_main, ~ paste0("ResidentMAINIADL.", .x)),
    breakdown_ins  = map(breakdown_base_ins,  ~ paste0("ResidentINS.", .x))
  )

# Rename colnames in parent_cols
parent_name_xwalk <- c(
  "LTI_MAIN"      = "ResidentMAINIADL.LTI",
  "LTI_INS"       = "ResidentINS.LTI",
  "HOS_SYMP_MAIN" = "ResidentMAINIADL.HOS_SYMP",
  "HOS_SYMP_INS"  = "ResidentINS.HOS_SYMP",
  "LCOV_MAIN"     = "ResidentMAINIADL.LCOV",
  "LCOV_INS"      = "ResidentINS.LCOV"
)

parent_cols <- parent_cols %>%
  mutate(
    parent_main = dplyr::recode(parent_main, !!!parent_name_xwalk),
    parent_ins  = dplyr::recode(parent_ins,  !!!parent_name_xwalk)
  )

## Step 3: Compute Parent_class and breakdown_class in overlap_R1_wide
blank_vals   <- c("", NA)
unknown_vals <- c("Unknown", "不清楚", "不詳", "不知道")
pos_vals     <- c("有", "是", "Yes", "Y", "1")
neg_vals     <- c("無", "無病徵", "否", "No", "N", "0")

classify_parent <- function(x) {
  x <- trimws(as.character(x))
  dplyr::case_when(
    is.na(x) | x %in% blank_vals   ~ "Blank",
    x %in% unknown_vals            ~ "Unknown",
    x %in% pos_vals                ~ "Valid Positive",
    x %in% neg_vals                ~ "Valid Negative",
    TRUE                           ~ "Invalid"
  )
}

is_breakdown_positive <- function(x) {
  x <- trimws(as.character(x))
  !(is.na(x) | x == "" | x %in% unknown_vals)
}

df <- overlap_R1_wide

for (i in seq_len(nrow(parent_cols))) {
  concept <- parent_cols$concept[[i]]
  p_main  <- parent_cols$parent_main[[i]]
  p_ins   <- parent_cols$parent_ins[[i]]
  b_main  <- intersect(parent_cols$breakdown_main[[i]], names(df))
  b_ins   <- intersect(parent_cols$breakdown_ins[[i]],  names(df))

  if (!p_main %in% names(df)) stop("Missing parent MAIN column: ", p_main)
  if (!p_ins  %in% names(df)) stop("Missing parent INS column: ",  p_ins)

  df <- df %>%
    mutate(
      !!paste0(concept, "_parent_class_MAIN") := classify_parent(.data[[p_main]]),
      !!paste0(concept, "_parent_class_INS")  := classify_parent(.data[[p_ins]])
    )

  if (length(b_main) > 0) {
    df <- df %>%
      mutate(!!paste0(concept, "_breakdown_signal_MAIN") := if_else(
        if_any(all_of(b_main), is_breakdown_positive), "Valid Positive", "Blank"
      ))
  } else {
    df[[paste0(concept, "_breakdown_signal_MAIN")]] <- "Blank"
  }

  if (length(b_ins) > 0) {
    df <- df %>%
      mutate(!!paste0(concept, "_breakdown_signal_INS") := if_else(
        if_any(all_of(b_ins), is_breakdown_positive), "Valid Positive", "Blank"
      ))
  } else {
    df[[paste0(concept, "_breakdown_signal_INS")]] <- "Blank"
  }
}

overlap_R1_wide <- df

## Quick check for new cols added for each parent concept
names(overlap_R1_wide)[grepl("^LTI_|^HOS_SYMP_|^LCOV_", names(overlap_R1_wide))]

## Step 4: Apply within decision matrix
df <- overlap_R1_wide

for (i in seq_len(nrow(parent_cols))) {

  concept     <- parent_cols$concept[[i]]
  pclass_main <- paste0(concept, "_parent_class_MAIN")
  bsig_main   <- paste0(concept, "_breakdown_signal_MAIN")
  pclass_ins  <- paste0(concept, "_parent_class_INS")
  bsig_ins    <- paste0(concept, "_breakdown_signal_INS")

  main_keys <- tibble(
    Source           = "MAIN",
    Parent_class     = df[[pclass_main]],
    Breakdown_signal = df[[bsig_main]]
  )

  main_res <- main_keys %>%
    left_join(within_code, by = c("Source", "Parent_class", "Breakdown_signal"))

  df[[paste0(concept, "_Final_parent_output_MAIN")]]  <- main_res$Final_parent_output
  df[[paste0(concept, "_Within_state_MAIN")]]         <- main_res$Within_state
  df[[paste0(concept, "_outcome_type_source_MAIN")]]  <- main_res$outcome_type_source
  df[[paste0(concept, "_parent_final_source_MAIN")]]  <- main_res$parent_final_source

  ins_keys <- tibble(
    Source           = "INS",
    Parent_class     = df[[pclass_ins]],
    Breakdown_signal = df[[bsig_ins]]
  )

  ins_res <- ins_keys %>%
    left_join(within_code, by = c("Source", "Parent_class", "Breakdown_signal"))

  df[[paste0(concept, "_Final_parent_output_INS")]]   <- ins_res$Final_parent_output
  df[[paste0(concept, "_Within_state_INS")]]          <- ins_res$Within_state
  df[[paste0(concept, "_outcome_type_source_INS")]]   <- ins_res$outcome_type_source
  df[[paste0(concept, "_parent_final_source_INS")]]   <- ins_res$parent_final_source

  n_na_main <- sum(is.na(main_res$Within_state))
  n_na_ins  <- sum(is.na(ins_res$Within_state))

  if (n_na_main > 0) warning(concept, " MAIN: ", n_na_main, " rows did not match within_decision_matrix.")
  if (n_na_ins  > 0) warning(concept, " INS: ",  n_na_ins,  " rows did not match within_decision_matrix.")
}

overlap_R1_wide <- df

## Quick check
check <- overlap_R1_wide %>%
  select(PID,
         LTI_parent_class_MAIN, LTI_breakdown_signal_MAIN,
         LTI_Final_parent_output_MAIN, LTI_Within_state_MAIN,
         LTI_parent_class_INS,  LTI_breakdown_signal_INS,
         LTI_Final_parent_output_INS,  LTI_Within_state_INS,
         HOS_SYMP_parent_class_MAIN, HOS_SYMP_breakdown_signal_MAIN,
         HOS_SYMP_Final_parent_output_MAIN, HOS_SYMP_Within_state_MAIN,
         HOS_SYMP_parent_class_INS,  HOS_SYMP_breakdown_signal_INS,
         HOS_SYMP_Final_parent_output_INS,  HOS_SYMP_Within_state_INS,
         LCOV_parent_class_MAIN, LCOV_breakdown_signal_MAIN,
         LCOV_Final_parent_output_MAIN, LCOV_Within_state_MAIN,
         LCOV_parent_class_INS,  LCOV_breakdown_signal_INS,
         LCOV_Final_parent_output_INS,  LCOV_Within_state_INS)

check <- check %>%
  mutate(
    LTI_parent_same_MAIN      = (LTI_parent_class_MAIN      == LTI_Final_parent_output_MAIN),
    HOS_SYMP_parent_same_MAIN = (HOS_SYMP_parent_class_MAIN == HOS_SYMP_Final_parent_output_MAIN),
    LCOV_parent_same_MAIN     = (LCOV_parent_class_MAIN      == LCOV_Final_parent_output_MAIN),
    LTI_parent_same_INS       = (LTI_parent_class_INS        == LTI_Final_parent_output_INS),
    HOS_SYMP_parent_same_INS  = (HOS_SYMP_parent_class_INS   == HOS_SYMP_Final_parent_output_INS),
    LCOV_parent_same_INS      = (LCOV_parent_class_INS        == LCOV_Final_parent_output_INS)
  )

sum(check$LTI_parent_same_MAIN      == FALSE, na.rm = TRUE)
sum(check$LTI_parent_same_INS       == FALSE, na.rm = TRUE)
sum(check$HOS_SYMP_parent_same_MAIN == FALSE, na.rm = TRUE)
sum(check$HOS_SYMP_parent_same_INS  == FALSE, na.rm = TRUE) # 1 FALSE E914-1-023
sum(check$LCOV_parent_same_MAIN     == FALSE, na.rm = TRUE)
sum(check$LCOV_parent_same_INS      == FALSE, na.rm = TRUE) # 1 FALSE E936-1-005

## Step 5: Create final parent value col
canon_parent_value <- function(x) {
  x <- trimws(as.character(x))
  dplyr::case_when(
    is.na(x) | x == "" ~ "",
    x %in% unknown_vals ~ "Unknown",
    x %in% pos_vals     ~ "有",
    x %in% neg_vals     ~ "無",
    TRUE                ~ x
  )
}

df <- overlap_R1_wide

for (i in seq_len(nrow(parent_cols))) {

  concept        <- parent_cols$concept[[i]]
  p_main         <- parent_cols$parent_main[[i]]
  p_ins          <- parent_cols$parent_ins[[i]]
  final_out_main <- paste0(concept, "_Final_parent_output_MAIN")
  final_out_ins  <- paste0(concept, "_Final_parent_output_INS")
  src_main       <- paste0(concept, "_parent_final_source_MAIN")
  src_ins        <- paste0(concept, "_parent_final_source_INS")

  df <- df %>%
    mutate(
      !!paste0(concept, "_parent_final_value_MAIN") := case_when(
        !is.na(.data[[final_out_main]]) & .data[[final_out_main]] == "Blank" ~ "",
        .data[[src_main]] %in% c("DERIVED", "DERIVED_FROM_BREAKDOWN", "DERIVED_FROM_BREAKDOWN_TO_PARENT", "DERIVED_TO_PARENT") ~ "有",
        .data[[src_main]] %in% c("PARENT_SELF", "USE_PARENT") ~ canon_parent_value(.data[[p_main]]),
        TRUE ~ canon_parent_value(.data[[p_main]])
      ),
      !!paste0(concept, "_parent_final_value_INS") := case_when(
        !is.na(.data[[final_out_ins]]) & .data[[final_out_ins]] == "Blank" ~ "",
        .data[[src_ins]] %in% c("DERIVED", "DERIVED_FROM_BREAKDOWN", "DERIVED_FROM_BREAKDOWN_TO_PARENT", "DERIVED_TO_PARENT") ~ "有",
        .data[[src_ins]] %in% c("PARENT_SELF", "USE_PARENT") ~ canon_parent_value(.data[[p_ins]]),
        TRUE ~ canon_parent_value(.data[[p_ins]])
      )
    )
}

overlap_R1_wide <- df

## QC
overlap_R1_wide %>%
  transmute(PID,
            parent_raw   = canon_parent_value(.data[[parent_cols$parent_main[parent_cols$concept=="LTI"][1]]]),
            parent_final = LTI_parent_final_value_MAIN,
            changed      = parent_raw != parent_final) %>%
  count(changed, useNA = "ifany")

overlap_R1_wide %>%
  transmute(PID,
            parent_raw   = canon_parent_value(.data[[parent_cols$parent_ins[parent_cols$concept=="LTI"][1]]]),
            parent_final = LTI_parent_final_value_INS,
            changed      = parent_raw != parent_final) %>%
  count(changed, useNA = "ifany")

overlap_R1_wide %>%
  transmute(PID,
            parent_raw   = canon_parent_value(.data[[parent_cols$parent_main[parent_cols$concept=="HOS_SYMP"][1]]]),
            parent_final = HOS_SYMP_parent_final_value_MAIN,
            changed      = parent_raw != parent_final) %>%
  count(changed, useNA = "ifany")

overlap_R1_wide %>%
  transmute(PID,
            parent_raw   = canon_parent_value(.data[[parent_cols$parent_ins[parent_cols$concept=="HOS_SYMP"][1]]]),
            parent_final = HOS_SYMP_parent_final_value_INS,
            changed      = parent_raw != parent_final) %>%
  count(changed, useNA = "ifany") # 1 TRUE - changed

overlap_R1_wide %>%
  transmute(PID,
            parent_raw   = canon_parent_value(.data[[parent_cols$parent_main[parent_cols$concept=="LCOV"][1]]]),
            parent_final = LCOV_parent_final_value_MAIN,
            changed      = parent_raw != parent_final) %>%
  count(changed, useNA = "ifany")

overlap_R1_wide %>%
  transmute(PID,
            parent_raw   = canon_parent_value(.data[[parent_cols$parent_ins[parent_cols$concept=="LCOV"][1]]]),
            parent_final = LCOV_parent_final_value_INS,
            changed      = parent_raw != parent_final) %>%
  count(changed, useNA = "ifany") # 1 TRUE - changed

## Save resolved within df
write_xlsx(overlap_R1_wide, file.path(p10b1, "overlap_R1_wide.xlsx"))

################################################################################
####### REMOVE ALL OBJECTS IN WORKPLACE ########
rm(list=ls())

### Part 10B2: Between Decision Matrix (ALL roles - parent, breakdown, single)
## Requires: overlap_R1_wide, R1_overlay_map (overlapping_vars & between_decision_matrix)

root   <- "C:/Users/OrielTsao/Desktop/COVID-19 RCHEs/DATA"
p10b1  <- file.path(root, "part10/10b/Part10B1")
p10b2  <- file.path(root, "part10/10b/Part10B2")

## 1. Read inputs
overlap_R1_wide <- read_excel(file.path(p10b1, "overlap_R1_wide.xlsx"))
var_map         <- read_excel(file.path(p10b2, "R1_overlay_map_23122025.xlsx"), sheet = "Overlapping_vars")
between_code    <- read_excel(file.path(p10b2, "R1_overlay_map_23122025.xlsx"), sheet = "between_decision_matrix")

## 2. Role mapping
between_map <- var_map %>%
  filter(!is.na(first_main), !is.na(first_ins)) %>%
  mutate(
    hierarchy_type = trimws(as.character(hierarchy_type)),
    role = case_when(
      hierarchy_type == "hierarchy_A" ~ "Parent",
      hierarchy_type == "hierarchy_B" ~ "Breakdown",
      hierarchy_type == "hierarchy_C" ~ "Single"
    )
  )

## 3. Build column names to pull values from overlap_R1_wide
to_main_raw <- function(x) paste0("ResidentMAINIADL.", sub("_MAIN$", "", as.character(x)))
to_ins_raw  <- function(x) paste0("ResidentINS.",     sub("_INS$",  "", as.character(x)))

parent_set <- c("LTI", "HOS_SYMP", "LCOV")

between_map <- between_map %>%
  mutate(
    MAIN_var = case_when(
      role == "Parent" & Concept %in% parent_set ~ paste0(Concept, "_parent_final_value_MAIN"),
      TRUE ~ to_main_raw(first_main)
    ),
    INS_var = case_when(
      role == "Parent" & Concept %in% parent_set ~ paste0(Concept, "_parent_final_value_INS"),
      TRUE ~ to_ins_raw(first_ins)
    )
  ) %>%
  transmute(concept = Concept, role, MAIN_var, INS_var)

## QC - n vars in which roles
between_map %>% count(role)

## Step 1: Extract between "long" working table (PID x concept)
extract_between_one <- function(df, concept, role, MAIN_var, INS_var) {
  df %>%
    transmute(
      PID,
      RCHEID,
      final_name_CHI,
      concept    = concept,
      role       = role,
      MAIN_var   = MAIN_var,
      INS_var    = INS_var,
      MAIN_value = .data[[MAIN_var]],
      INS_value  = .data[[INS_var]]
    )
}

between_long <- pmap_dfr(between_map, ~ extract_between_one(overlap_R1_wide, ..1, ..2, ..3, ..4))

## Step 2: Classify MAIN/INS values into between classes
blank_vals   <- c("", NA)
unknown_vals <- c("Unknown", "不清楚", "不詳", "不知道")

pos_vals_parent <- c("有", "是", "Yes", "Y", "1")
neg_vals_parent <- c("無", "無病徵", "否", "No", "沒有", "N", "0")

to_upper_trim <- function(x) toupper(trimws(as.character(x)))

classify_parent_between <- function(x) {
  x <- to_upper_trim(x)
  dplyr::case_when(
    is.na(x) | x == ""                    ~ "BLANK",
    x %in% to_upper_trim(unknown_vals)    ~ "UNKNOWN",
    x %in% to_upper_trim(pos_vals_parent) ~ "POSITIVE VALID",
    x %in% to_upper_trim(neg_vals_parent) ~ "NEGATIVE VALID",
    TRUE                                  ~ "INVALID"
  )
}

classify_breakdown_between <- function(x) {
  x <- to_upper_trim(x)
  dplyr::case_when(
    is.na(x) | x == ""                ~ "BLANK",
    x %in% to_upper_trim(unknown_vals) ~ "UNKNOWN",
    TRUE                               ~ "POSITIVE VALID"
  )
}

between_long <- between_long %>%
  mutate(
    MAIN_class = case_when(
      toupper(role) == "BREAKDOWN" ~ classify_breakdown_between(MAIN_value),
      TRUE                         ~ classify_parent_between(MAIN_value)
    ),
    INS_class = case_when(
      toupper(role) == "BREAKDOWN" ~ classify_breakdown_between(INS_value),
      TRUE                         ~ classify_parent_between(INS_value)
    )
  )

## Step 3: Apply between decision matrix
between_lookup <- between_code %>%
  mutate(
    Role       = toupper(trimws(as.character(Role))),
    MAIN_class = toupper(trimws(as.character(MAIN_class))),
    INS_class  = toupper(trimws(as.character(INS_class)))
  )

between_res <- between_long %>%
  mutate(
    Role       = toupper(role),
    MAIN_class = toupper(MAIN_class),
    INS_class  = toupper(INS_class)
  ) %>%
  left_join(between_lookup, by = c("Role" = "Role", "MAIN_class", "INS_class"))

## QC - check unmatched
between_res %>%
  filter(is.na(final_source)) %>%
  count(Role, MAIN_class, INS_class, sort = TRUE) #RESULT: ALL matched

## Step 4: Build final chosen value for between matrix
between_res <- between_res %>%
  mutate(
    final_value_between = case_when(
      final_source == "MAIN" ~ MAIN_value,
      final_source == "INS"  ~ INS_value,
      final_source == "BOTH" ~ MAIN_value,
      TRUE ~ NA
    )
  )

## Step 5: Handle "needs conflict logic? = yes" rows
resolve_between_conflict <- function(df) {
  df %>%
    mutate(
      final_source         = toupper(trimws(as.character(final_source))),
      needs_conflict_logic = toupper(trimws(as.character(`Needs conflict logic?`))),
      Rule                 = trimws(as.character(Rule)),

      final_value_between = case_when(
        Rule %in% c("B5", "C5")  ~ "NA",
        final_source == "MAIN"   ~ MAIN_value,
        final_source == "INS"    ~ INS_value,
        final_source == "BOTH"   ~ MAIN_value,
        TRUE ~ NA
      ),

      conflict_note = case_when(
        needs_conflict_logic == "YES" & Rule %in% c("A8","B2","C2")          ~ "Valid disagreement MAIN vs INS (direction resolved by matrix)",
        needs_conflict_logic == "YES" & Rule %in% c("A3","A6","B4","C4")     ~ "One side has value; other side blank/unknown (direction resolved by matrix)",
        needs_conflict_logic == "YES"                                         ~ "Conflict case (resolved by matrix)",
        TRUE ~ NA_character_
      )
    )
}

between_res <- resolve_between_conflict(between_res)

## QC - no unresolved final values
between_res %>%
  filter(is.na(final_value_between)) %>%
  count(Role, MAIN_class, INS_class, sort = TRUE)

## Step 6: Pivot between_res (long) to wide df
final_between_wide <- between_res %>%
  select(PID, RCHEID, final_name_CHI, concept, final_value_between) %>%
  group_by(PID, RCHEID, final_name_CHI, concept) %>%
  summarise(final_value_between = dplyr::first(final_value_between), .groups = "drop") %>%
  pivot_wider(
    names_from   = concept,
    values_from  = final_value_between,
    names_prefix = "final_"
  )

write_xlsx(final_between_wide, file.path(p10b2, "final_between_wide.xlsx"))

################################################################################
####### REMOVE ALL OBJECTS IN WORKPLACE ########
rm(list=ls())

## Part 10B3: Joining final resolved df for INS/MAIN back into the OG dataset

root     <- "C:/Users/OrielTsao/Desktop/COVID-19 RCHEs/DATA"
r1_clean <- file.path(root, "1_clean/R1")
p10b2    <- file.path(root, "part10/10b/Part10B2")
p10b3    <- file.path(root, "part10/10b/Part10B3")

R1_wide            <- read_excel(file.path(r1_clean, "combined_R1_Res_3.xlsx"))
final_between_wide <- read_excel(file.path(p10b2,    "final_between_wide.xlsx"))
var_map            <- read_excel(file.path(p10b3,    "R1_overlay_map_23122025.xlsx"), sheet = "Overlapping_vars")

## Step 1: Join final_between_wide back to R1
final_between_keep <- final_between_wide %>%
  select(-final_name_CHI) %>%
  select(PID, dplyr::starts_with("final_"))

R1_full <- R1_wide %>%
  dplyr::left_join(final_between_keep, by = "PID")

## Step 2: Build concept-column crosswalk from var_map
to_main_raw <- function(x) paste0("ResidentMAINIADL.", sub("_MAIN$", "", as.character(x)))
to_ins_raw  <- function(x) paste0("ResidentINS.",     sub("_INS$",  "", as.character(x)))

xwalk <- var_map %>%
  dplyr::filter(!is.na(first_main), !is.na(first_ins)) %>%
  dplyr::transmute(
    concept  = Concept,
    main_col = to_main_raw(first_main),
    ins_col  = to_ins_raw(first_ins)
  ) %>%
  dplyr::distinct(concept, .keep_all = TRUE)

## Step 3: Create single "final merged" column per concept
blank_to_na <- function(x) {
  x <- trimws(as.character(x))
  dplyr::na_if(x, "")
}

df <- R1_full

for (i in seq_len(nrow(xwalk))) {
  concept   <- xwalk$concept[[i]]
  main_col  <- xwalk$main_col[[i]]
  ins_col   <- xwalk$ins_col[[i]]
  final_col <- paste0("final_", concept)

  if (!final_col %in% names(df)) next
  if (!main_col  %in% names(df)) next
  if (!ins_col   %in% names(df)) next

  df[[final_col]] <- dplyr::coalesce(
    blank_to_na(df[[final_col]]),
    blank_to_na(df[[main_col]]),
    blank_to_na(df[[ins_col]])
  )
}

R1_full <- df

## QC
# 1) PID uniqueness preserved
stopifnot(dplyr::n_distinct(R1_full$PID) == dplyr::n_distinct(R1_wide$PID))
R1_full %>% count(PID) %>% filter(n > 1)

# 2) PID set unchanged
setequal(R1_full$PID, R1_wide$PID)
setdiff(R1_wide$PID, R1_full$PID)
setdiff(R1_full$PID, R1_wide$PID)

# 3) Raw MAIN/INS cols not overwritten
cols_check <- c("ResidentMAINIADL.LTI", "ResidentINS.LTI",
                "ResidentMAINIADL.HOS_SYMP", "ResidentINS.HOS_SYMP",
                "ResidentMAINIADL.LCOV", "ResidentINS.LCOV")
all.equal(R1_full[cols_check], R1_wide[cols_check])

# 4) Every concept in xwalk got a final column
expected_final <- paste0("final_", xwalk$concept)
setdiff(expected_final, names(R1_full))

## Save final resolved INS/MAIN R1 df
write_xlsx(R1_full, file.path(p10b3, "R1_full.xlsx"))

#END OF PART 10B
################################################################################
####### REMOVE ALL OBJECTS IN WORKPLACE ########
rm(list=ls())

### Part 10C: Within-Round Harmonisation: SM vs Qualtrics (R1 only)
## Objective: Build SM overlay map and create unified FIN_<concept> columns
## Hierarchy: ResidentMINI > ResidentSM > final_<concept> > ResidentMAINIADL >
##            ResidentINS > ResidentVISVH > ResidentMC

root  <- "C:/Users/OrielTsao/Desktop/COVID-19 RCHEs/DATA"
p10b3 <- file.path(root, "part10/10b/Part10B3")
p10c  <- file.path(root, "part10/10c")

## 0. Load inputs
R1_full <- read_excel(file.path(p10b3, "R1_full.xlsx"))

## 1. Helpers
exclude_sm <- c("respondentID","ResponseID","StartDate","EndDate","RecordedDate",
                "CollectorID","startdate","enddate","ipaddress","email",
                "first","last","custom1","dataentry","DT")

blank_to_na <- function(x) dplyr::na_if(trimws(as.character(x)), "")

pick_first_nonblank <- function(df, cols) {
  cols <- cols[cols %in% names(df)]
  if (length(cols) == 0) return(rep(NA_character_, nrow(df)))

  mat <- sapply(cols, function(cc) blank_to_na(df[[cc]]))
  if (is.null(dim(mat))) mat <- matrix(mat, ncol = 1)

  apply(mat, 1, function(row) {
    v <- row[!is.na(row)]
    if (length(v) == 0) NA_character_ else v[1]
  })
}

get_concepts_from_prefix <- function(df, prefix_dot) {
  cols <- names(df)[startsWith(names(df), prefix_dot)]
  sub(paste0("^", gsub("\\.", "\\\\.", prefix_dot)), "", cols)
}

## 2. Phase 0: Build SM overlay map (exclude ResidentADD2.*)
sm_cols        <- names(R1_full)[startsWith(names(R1_full), "ResidentSM.")]
sm_concepts    <- sub("^ResidentSM\\.", "", sm_cols)
sm_concepts_all <- setdiff(sm_concepts, exclude_sm)

priority_prefix <- c(
  "ResidentMINI",
  "ResidentSM",
  "final",
  "ResidentMAINIADL",
  "ResidentINS",
  "ResidentVISVH",
  "ResidentMC"
)

order_by_priority <- function(cols, priority_prefix) {
  ordered <- unlist(lapply(priority_prefix, function(pfx) {
    if (pfx == "final") {
      cols[startsWith(cols, "final_")]
    } else {
      cols[startsWith(cols, paste0(pfx, "."))]
    }
  }))
  remaining <- setdiff(cols, ordered)
  c(ordered, remaining)
}

concept_sources <- lapply(sm_concepts_all, function(concept) {
  cols_dot <- grep(
    paste0("\\.", gsub("([\\W])", "\\\\\\1", concept), "$"),
    names(R1_full),
    value = TRUE
  )
  cols_dot   <- cols_dot[!startsWith(cols_dot, "ResidentADD2.")]
  col_final  <- paste0("final_", concept)
  cols_final <- if (col_final %in% names(R1_full)) col_final else character(0)
  c(cols_dot, cols_final)
})
names(concept_sources) <- sm_concepts_all

sm_overlay_map <- tibble(concept = sm_concepts_all) %>%
  mutate(
    sm_col           = paste0("ResidentSM.", concept),
    out_col          = paste0("FIN_", concept),
    cols_all         = map(concept, ~ concept_sources[[.x]]),
    cols_ordered     = map(cols_all, order_by_priority, priority_prefix = priority_prefix),
    n_sources        = map_int(cols_all, length),
    sources          = map(cols_all, ~ {
      s <- ifelse(startsWith(.x, "final_"), "final_", sub("^([^\\.]+)\\..*$", "\\1", .x))
      unique(sort(s))
    }),
    overlaps_other   = map_lgl(sources, ~ any(.x != "ResidentSM")),
    first_choice_col = map_chr(cols_ordered, ~ ifelse(length(.x) > 0, .x[1], NA_character_)),
    ordered_cols_str = map_chr(cols_ordered, ~ paste(.x, collapse = "; ")),
    sources_str      = map_chr(sources, ~ paste(.x, collapse = "; "))
  ) %>%
  select(concept, sm_col, out_col, overlaps_other, n_sources, sources_str, first_choice_col, ordered_cols_str)

write_xlsx(sm_overlay_map, file.path(p10c, "SM_overlay_map.xlsx"))

## 3. Phase 1: Build FIN_<concept> for all SM concepts
df <- R1_full

concepts_to_make_fin <- sm_concepts_all

for (concept in concepts_to_make_fin) {

  mini_col  <- paste0("ResidentMINI.", concept)
  sm_col    <- paste0("ResidentSM.", concept)
  old_final <- paste0("final_", concept)
  main_col  <- paste0("ResidentMAINIADL.", concept)
  ins_col   <- paste0("ResidentINS.", concept)
  vis_col   <- paste0("ResidentVISVH.", concept)
  mc_col    <- paste0("ResidentMC.", concept)
  out_col   <- paste0("FIN_", concept)
  src_col   <- paste0(out_col, "_source")

  df[[out_col]] <- pick_first_nonblank(df, c(mini_col, sm_col, old_final, main_col, ins_col, vis_col, mc_col))
  df[[src_col]] <- NA_character_

  if (mini_col %in% names(df)) {
    hit <- !is.na(blank_to_na(df[[mini_col]])) & (blank_to_na(df[[out_col]]) == blank_to_na(df[[mini_col]]))
    df[[src_col]][hit] <- mini_col
  }
  if (sm_col %in% names(df)) {
    hit <- is.na(df[[src_col]]) & !is.na(blank_to_na(df[[sm_col]])) & (blank_to_na(df[[out_col]]) == blank_to_na(df[[sm_col]]))
    df[[src_col]][hit] <- sm_col
  }
  if (old_final %in% names(df)) {
    hit <- is.na(df[[src_col]]) & !is.na(blank_to_na(df[[old_final]])) & (blank_to_na(df[[out_col]]) == blank_to_na(df[[old_final]]))
    df[[src_col]][hit] <- old_final
  }
  if (main_col %in% names(df)) {
    hit <- is.na(df[[src_col]]) & !is.na(blank_to_na(df[[main_col]])) & (blank_to_na(df[[out_col]]) == blank_to_na(df[[main_col]]))
    df[[src_col]][hit] <- main_col
  }
  if (ins_col %in% names(df)) {
    hit <- is.na(df[[src_col]]) & !is.na(blank_to_na(df[[ins_col]])) & (blank_to_na(df[[out_col]]) == blank_to_na(df[[ins_col]]))
    df[[src_col]][hit] <- ins_col
  }
  if (vis_col %in% names(df)) {
    hit <- is.na(df[[src_col]]) & !is.na(blank_to_na(df[[vis_col]])) & (blank_to_na(df[[out_col]]) == blank_to_na(df[[vis_col]]))
    df[[src_col]][hit] <- vis_col
  }
  if (mc_col %in% names(df)) {
    hit <- is.na(df[[src_col]]) & !is.na(blank_to_na(df[[mc_col]])) & (blank_to_na(df[[out_col]]) == blank_to_na(df[[mc_col]]))
    df[[src_col]][hit] <- mc_col
  }

  hit <- is.na(df[[src_col]]) & !is.na(blank_to_na(df[[out_col]]))
  df[[src_col]][hit] <- "UNKNOWN_SOURCE"
}

R1_full_final <- df

## Save FINAL DF (all overlapping vars-pids resolved)
write_xlsx(R1_full_final, file.path(p10c, "R1_full_final.xlsx"))

#END OF PART 10C
################################################################################
####### REMOVE ALL OBJECTS IN WORKPLACE ########
rm(list=ls())

### Part 10D1: Joining All Rounds [R1, R2, R3] with Specimen Log
root         <- "C:/Users/OrielTsao/Desktop/COVID-19 RCHEs/DATA"
p10c         <- file.path(root, "part10/10c")
r2_clean     <- file.path(root, "1_clean/R2")
r3_clean     <- file.path(root, "1_clean/R3")
p10d_res     <- file.path(root, "part10/10d/resident")
summary_docs <- file.path(root, "Summary docs")

## 1. Read files directly from where they are saved
R1_raw       <- read_excel(file.path(p10c,     "R1_full_final.xlsx"),              col_names = TRUE)
R2_raw       <- read_excel(file.path(r2_clean,  "combined_R2_Res_3.xlsx"),          col_names = TRUE)
R3_raw       <- read_excel(file.path(r3_clean,  "combined_R3_Res_3.xlsx"),          col_names = TRUE)
spec_log_raw <- read_excel(file.path(p10d_res,  "evax_specimenlog_dated20250718.xlsx"), col_names = TRUE)
consent_df   <- read_excel(file.path(summary_docs, "consent_archive_protected_dated05122025.xlsx"),
                           sheet = "Resident_dated20251205")

## 2. Convert all to character
R1_clean       <- R1_raw       %>% mutate(across(everything(), as.character))
R2_clean       <- R2_raw       %>% mutate(across(everything(), as.character))
R3_clean       <- R3_raw       %>% mutate(across(everything(), as.character))
spec_log_clean <- spec_log_raw %>% mutate(across(everything(), as.character))
consent_df     <- consent_df   %>% mutate(across(everything(), as.character))

## 3. Prep spec_log for joining
# Prep 1: join subid1, subid2, subid3 to PID
spec_log_clean$PID <- paste(spec_log_clean$subid1,
                            spec_log_clean$subid2,
                            spec_log_clean$subid3, sep = "-")

# Prep 2: Change Subject ID in consent_df to PID
consent_df$PID <- consent_df$`Subject ID`

# Prep 3: Keep only Resident in spec_log
spec_log_clean <- spec_log_clean %>% filter(subid2 != 2)

# Prep 4: Remove E101-1-003 from R1 resident as no consent
spec_log_clean <- spec_log_clean %>% filter(PID != "E101-1-003")

# Prep 5: Standardize PID format
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

## QC: all spec_log PIDs inside consent_df
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

## 4. Filter blood data by round and match to consent dates
blood_df <- spec_log_clean %>%
  filter(!(EVAX_Status %in% c("Round2", "Round3")))

consent_df_R1 <- consent_df %>% filter(!(`Study Round` %in% c("2", "3")))
consent_df_R2 <- consent_df %>% filter(!(`Study Round` %in% c("1", "3")))
consent_df_R3 <- consent_df %>% filter(!(`Study Round` %in% c("2", "1")))

# Keep only blood PIDs that exist in consent_df
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

# NA in cdate denoted as 9999-12-31
finalwmissing_df <- finalwmissing_df %>%
  mutate(cdate = if_else(is.na(cdate), as.Date("9999-12-31"), cdate))

## QC: finalwmissing contains all PIDs from specimen_log
uniqueblood <- blood_df %>% distinct(PID, .keep_all = TRUE)
identical(sort(uniqueblood$PID), sort(finalwmissing_df$PID)) #IDENTICAL = TRUE

## Create R1 blood data
R1_blood_data <- finalwmissing_df %>% select(subid1:PID)

## 5. Join R1 blood data with R2 and R3
# Prep 1: create RCHEID column
spec_log_clean$RCHEID  <- spec_log_clean$subid1
R1_blood_data$RCHEID   <- R1_blood_data$subid1

# Prep 2: create round column in spec_log
spec_log_clean <- spec_log_clean %>%
  mutate(round = case_when(
    str_starts(as.character(cdate), "2022") ~ "1",
    EVAX_Status == "Round2"                 ~ "2",
    EVAX_Status == "Round3"                 ~ "3",
    TRUE                                    ~ "1"
  ))

R1_blood_data <- R1_blood_data %>%
  mutate(round = case_when(
    str_starts(as.character(cdate), "2022") ~ "1",
    EVAX_Status == "Round2"                 ~ "2",
    EVAX_Status == "Round3"                 ~ "3",
    TRUE                                    ~ "1"
  ))

# QC R2 & R3 blood - all have consent
R2_blood_data <- spec_log_clean %>% filter(EVAX_Status == "Round2")
R3_blood_data <- spec_log_clean %>% filter(EVAX_Status == "Round3")

all(R2_blood_data$PID %in% consent_df_R2$PID) #RESULT: TRUE
all(R3_blood_data$PID %in% consent_df_R3$PID) #RESULT: TRUE

## 6. Join R1-R3 blood data
PID    <- "PID"
RCHEID <- "RCHEID"
round  <- "round"

ALL_blood_data <- bind_rows(R1_blood_data, R2_blood_data, R3_blood_data) %>%
  arrange(.data[[PID]]) %>%
  select(round, RCHEID, PID, everything()) %>%
  rename_with(~ paste0("blood.", .x), .cols = -all_of(c(PID, RCHEID, round)))

## 7. Join all R1-R3 survey data + blood data
id_var         <- "PID"
final_name_CHI <- "final_name_CHI"

ALLRound <- R1_clean %>%
  full_join(R2_clean,        by = c(round, RCHEID, id_var, final_name_CHI)) %>%
  full_join(R3_clean,        by = c(round, RCHEID, id_var, final_name_CHI)) %>%
  full_join(ALL_blood_data,  by = c("PID", "round"))

## 8. Clean up RCHEID
ALLRound <- ALLRound %>%
  mutate(RCHEID = substr(PID, 1, 4))
ALLRound$RCHEID.x <- NULL
ALLRound$RCHEID.y <- NULL

## 9. Sort, reorder, convert to character
ALLRound <- ALLRound %>%
  arrange(.data[[id_var]], round) %>%
  select(round, RCHEID, PID, final_name_CHI, everything()) %>%
  mutate(across(everything(), as.character))

## 10. Remove PID ENA-1-NA
ALLRound <- ALLRound %>%
  filter(PID != "ENA-1-NA")

## Save outputs
write.xlsx(ALLRound,
           file     = file.path(p10d_res, "ALLRound_Resident.xlsx"),
           colNames = TRUE,
           rowNames = FALSE)

write.xlsx(ALL_blood_data,
           file     = file.path(p10d_res, "ALL_blood_data.xlsx"),
           colNames = TRUE,
           rowNames = FALSE)

#END of PART 10D

## Part 10D QC - Count PIDs per round
R1 <- ALLRound %>% filter(round == "1")
R2 <- ALLRound %>% filter(round == "2")
R3 <- ALLRound %>% filter(round == "3")

length(unique(R1$PID)) # 1189
length(unique(R2$PID)) # 1112
length(unique(R3$PID)) # 1076

## Count PIDs without Resident1 survey
try <- ALLRound %>%
  dplyr::select(!matches("^(Resident1)")) %>%
  dplyr::filter(rowSums(!is.na(dplyr::across(!c(round, PID, RCHEID, final_name_CHI)))) > 0)

ALLRound_woRes1 <- try

R1 <- ALLRound_woRes1 %>% filter(round == "1")
R2 <- ALLRound_woRes1 %>% filter(round == "2")
R3 <- ALLRound_woRes1 %>% filter(round == "3")

length(unique(R1$PID)) # 1189
length(unique(R2$PID)) # 724
length(unique(R3$PID)) # 699

##END of RESIDENT PART10A-D1
