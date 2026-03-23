library(dplyr)
library(ggplot2)
library(readxl)
library(janitor)
library(openxlsx)
library(lubridate)

# Load and prepare data
setwd("C:/Users/mmu7388/OneDrive - MassMutual/Desktop/FAST Files/MJE Materiality Analysis")

read_and_clean_csv <- function(file_path) {
  read.csv(file_path, stringsAsFactors = FALSE) %>%
    clean_names() %>%
    rename_with(toupper)
}
DATA <- read_and_clean_csv("D1_EDAP_GL_DATA.csv")
CONS_DATA <- read_excel("D2_SAP_CONS_DATA.xlsx")
FX_accounts <- read_excel("H2_FX_ACCOUNTS_MD.xlsx") %>% 
  mutate(`G/L account` = as.numeric(`G/L account`))

################################################################################
## Non-Consolidated Data preparation
#Populate User name based on Posted By if Parked by is empty
#if only 1 year is loaded, then the bindrows function should be excluded
GL_DATA <- DATA %>% 
  rename(PARKED_BY = USER_WHOPARKED_DOCUMENT, POSTED_BY = USER_NAME, FISCAL_YEAR = I_FISCAL_YEAR) %>%
  #Make sure that the $ values are all numerics
  mutate(
    PARKED_BY = ifelse(PARKED_BY == "", POSTED_BY, PARKED_BY),
    R_3_DOC_CURR = as.numeric(R_3_DOC_CURR),
    R_3_LOCAL_CURR = as.numeric(R_3_LOCAL_CURR),
    R_3_GROUP_CURR = as.numeric(R_3_GROUP_CURR)
  )
################################################################################
#Extracting the FX related line items based on the G/L accounts provided 
FX_Items <- GL_DATA %>% 
  filter(GENERAL_LEDGER_ACCOUNT %in% FX_accounts$`G/L account`) %>%
  group_by(FISCAL_YEAR, FISCAL_PERIOD, COMPANY_CODE, ACCOUNTING_DOCUMENT_NUMBER,
           DOCUMENT_HEADER_TEXT, REFERENCE_DOCUMENT_NUMBER,GENERAL_LEDGER_ACCOUNT,
           CURRENCY_KEY,USER = PARKED_BY) %>% 
  summarise(DOC_CURR = sum(R_3_DOC_CURR))

#The below filter is a check to see if the items that are marked as FX based on
#the FX G/L account list are including "FX" in their name or not
FX_check <- GL_DATA %>% filter(grepl("FX", DOCUMENT_HEADER_TEXT, ignore.case = TRUE))
################################################################################
#create the report by grouping and summrizing the lines of the same MJE 
REPORT_DATA <- GL_DATA %>%
  filter(POSTING_KEY == 40) %>% #filter only for the positive/debit values to 
  #not have zero sum of the documnets and be able to acuqire the MJE value.
  group_by(FISCAL_YEAR, FISCAL_PERIOD, POSTING_DATE_DOCUMENT,ENTRY_DATE,
           COMPANY_CODE, ACCOUNTING_DOCUMENT_NUMBER,
           DOCUMENT_HEADER_TEXT, REFERENCE_DOCUMENT_NUMBER, CURRENCY_KEY,
           USER = PARKED_BY) %>%
  summarise(
    DOC_VALUE = sum(R_3_DOC_CURR, na.rm = TRUE),
    LOC_VALUE = sum(R_3_LOCAL_CURR, na.rm = TRUE),
    GRU_VALUE = sum(R_3_GROUP_CURR, na.rm = TRUE),
    .groups = "drop" #grouping and summarizing of the values to leave only 
    # unique document numbers from the initial dataset that includes Doc Line Items
  )
#bring the User details (name, division, department) based on the additional datasets
USERS <- read_excel("H3_USER_ADDR_table.xlsx") %>% 
  clean_names() %>% rename_with(toupper)
# USER_ADDR_table data is extracted from SAP 
EMPLOYEE_PER_DEPARTMENT <- read_excel("H1_ID_TO_DEPARTMENT.xlsx") %>% 
  clean_names() %>% 
  rename_with(toupper)
# ID_to_Department.xlsx is the data collected from the predecessor and includes
# the mapping of user ID to SBU and division. As it is lacking it should be 
# updated accordingly 
#create the days buckets that shows the lag between Posting and Entry date
breaks <- c(-Inf, -20, -15, -10, -5, 0, 5, 10, 15, 20, 25, 30, 35, 40, 45, 50, Inf)
labels <- c("< -20",  "-20 to -15", "-15 to -10", "-10 to -5", "-5 to 0",
  "0 to 5", "5 to 10", "10 to 15", "15 to 20", "20 to 25",
  "25 to 30", "30 to 35", "35 to 40", "40 to 45", "45 to 50", "50 <")
#Join the data with the users to have in the dataset the department information
REPORT_DATA <- REPORT_DATA %>%
  left_join(USERS, by = c("USER" = "USER_NAME")) %>%
  left_join(EMPLOYEE_PER_DEPARTMENT, by = c("USER" = "EMPLOYEE_MM_ID")) %>%
  mutate(FULL_NAME = ifelse(is.na(FULL_NAME), "Left the Company", FULL_NAME),
         MJE_ID = paste(COMPANY_CODE, ACCOUNTING_DOCUMENT_NUMBER, FISCAL_YEAR, sep = "_")) %>%
  select(MJE_ID,COMPANY_CODE, FISCAL_YEAR, FISCAL_PERIOD, POSTING_DATE_DOCUMENT,
         ENTRY_DATE, ACCOUNTING_DOCUMENT_NUMBER,
         REFERENCE_DOCUMENT_NUMBER, DOCUMENT_HEADER_TEXT, CURRENCY_KEY,
         DOC_VALUE, LOC_VALUE, GRU_VALUE, USER, FULL_NAME, DEPARTMENT, SBU, DIV) %>%
  mutate(
    # Coerce to Date safely from common string formats - even though in our case is only one
    POSTING_DATE_DOCUMENT = as.Date(
      POSTING_DATE_DOCUMENT, tryFormats = c("%Y-%m-%d", "%m/%d/%Y", "%d.%m.%Y")
    ),
    ENTRY_DATE = as.Date(
      ENTRY_DATE, tryFormats = c("%Y-%m-%d", "%m/%d/%Y", "%d.%m.%Y")
    ),
    # Compute month-end for the POSTING_DATE_DOCUMENT's month
    POSTING_MONTH_END = ceiling_date(POSTING_DATE_DOCUMENT, "month") - days(1),
    # Signed difference: ENTRY_DATE - POSTING_MONTH_END (negative = before, positive = after)
    DAYS_LAG = as.integer(ENTRY_DATE - POSTING_MONTH_END),
    # Comment flag
    POSTING_COMMENT = ifelse(
      POSTING_DATE_DOCUMENT > ENTRY_DATE &
        format(POSTING_DATE_DOCUMENT, "%Y-%m") != format(ENTRY_DATE, "%Y-%m"),
      "Future Postings",
      "Current Period/MEC Posting"
    ),
    # Buckets (cut handles NA automatically)
    DAYS_BUCKETS = cut(
      DAYS_LAG,
      breaks = breaks,
      labels = labels,
      right = TRUE,           # intervals are (a, b]; e.g., -5 to 0 is (-5, 0]
      include.lowest = TRUE
    )
  ) %>%
  # Optional: ordered factor for consistent reporting/charts
  mutate(
    DAYS_BUCKETS = factor(DAYS_BUCKETS, levels = labels, ordered = TRUE)
  )
# Classify the entries based on type (for FX and Allocations)
REPORT_DATA <- REPORT_DATA %>%
  mutate(TYPE = case_when(
    # for FX entries we are using a double check if it is part of the FX G/L dataset
    # and if the document header of the entry contaons the word "FX"
    ACCOUNTING_DOCUMENT_NUMBER %in% FX_Items$ACCOUNTING_DOCUMENT_NUMBER ~ "FX Entry",
    grepl("FX", DOCUMENT_HEADER_TEXT, ignore.case = TRUE) ~ "FX Entry",
    # for the allocation entries the below rule includes the entries related to
    # "Unallocated" activities/transactions. The accuracy of this needs to be 
    # verified
    grepl("Alloc", DOCUMENT_HEADER_TEXT, ignore.case = TRUE) &
      !grepl("unalloc", DOCUMENT_HEADER_TEXT, ignore.case = TRUE) ~ "Allocation Entry",
    TRUE ~ "Other"  # default value if none of the conditions match
  )) %>%
  #Frequency classification - it may need adjustment
  mutate(FREQUENCY = case_when(
    startsWith(REFERENCE_DOCUMENT_NUMBER, "Y") ~ "Yearly",
    startsWith(REFERENCE_DOCUMENT_NUMBER, "Q") ~ "Quarterly",
    startsWith(REFERENCE_DOCUMENT_NUMBER, "M") ~ "Monthly",
    TRUE ~ "Non-Reversing"
  )) %>%
  #create the dollar backets classificaiton basedo Group Crcy Value
  mutate(VALUE_BUCKET = case_when(
    GRU_VALUE == 0 ~ "Zero",
    GRU_VALUE > 0 & GRU_VALUE <= 100 ~ "Below $100",
    GRU_VALUE > 100 & GRU_VALUE <= 500 ~ "$101-$500",
    GRU_VALUE > 500 & GRU_VALUE <= 1000 ~ "$501-$1,000",
    GRU_VALUE > 1000 & GRU_VALUE <= 5000 ~ "$1,001-$5,000",
    GRU_VALUE > 5000 & GRU_VALUE <= 10000 ~ "$5,001-$10,000",
    GRU_VALUE > 10000 & GRU_VALUE <= 20000 ~ "$10,001-$20,000",
    GRU_VALUE > 20000 ~ "Above $20,000",
    TRUE ~ "Undefined"
  )) %>%
  mutate(VALUE_BUCKET = factor(VALUE_BUCKET, levels = c(
    "Zero", "Below $100", "$101-$500", "$501-$1,000",
    "$1,001-$5,000", "$5,001-$10,000", "$10,001-$20,000",
    "Above $20,000", "Undefined"
  )))

# --- Quarter-level analytics (GL) ---
REPORT_DATA <- REPORT_DATA %>%
  mutate(
    # Quarter label from POSTING_DATE_DOCUMENT (calendar quarters)
    QUARTER = paste0("Q", quarter(POSTING_DATE_DOCUMENT), " ", year(POSTING_DATE_DOCUMENT)),
    
    # Last day of the quarter for the posting date
    QUARTER_END = ceiling_date(POSTING_DATE_DOCUMENT, "quarter") - days(1),
    
    # Signed difference: ENTRY_DATE - QUARTER_END
    ENTRY_VS_QUARTER_END_DAYS   = as.integer(ENTRY_DATE - QUARTER_END),
    
    # Integer month difference vs quarter end (Apr vs Mar = 1; Jun vs Mar = 3)
    ENTRY_VS_QUARTER_END_MONTHS = (year(ENTRY_DATE) - year(QUARTER_END)) * 12 +
      (month(ENTRY_DATE) - month(QUARTER_END)),
    
    # Quarter-level comment
    QUARTER_POSTING_COMMENT = ifelse(
      ENTRY_DATE > QUARTER_END, "Posted After Quarter End", "Within Quarter"
    ),
    
    # Quarter buckets (same 5-day ranges as month buckets)
    QTR_DAYS_BUCKETS = cut(
      ENTRY_VS_QUARTER_END_DAYS,
      breaks = breaks,
      labels = labels,
      right = TRUE,
      include.lowest = TRUE
    )
  ) %>%
  mutate(
    QTR_DAYS_BUCKETS = factor(QTR_DAYS_BUCKETS, levels = labels, ordered = TRUE)
  )

REPORT_DATA <- REPORT_DATA %>%
  select(
    MJE_ID, COMPANY_CODE, FISCAL_YEAR, FISCAL_PERIOD,
    ACCOUNTING_DOCUMENT_NUMBER, REFERENCE_DOCUMENT_NUMBER, DOCUMENT_HEADER_TEXT,
    CURRENCY_KEY, DOC_VALUE, LOC_VALUE, GRU_VALUE, VALUE_BUCKET,
    POSTING_DATE_DOCUMENT, ENTRY_DATE, POSTING_MONTH_END,
    TYPE, FREQUENCY,
    DAYS_LAG, POSTING_COMMENT, DAYS_BUCKETS,                 # month metrics
    QUARTER, QUARTER_END, ENTRY_VS_QUARTER_END_DAYS,        # quarter metrics
    ENTRY_VS_QUARTER_END_MONTHS, QUARTER_POSTING_COMMENT,   # quarter metrics
    QTR_DAYS_BUCKETS,                                       # quarter buckets
    USER, FULL_NAME, DEPARTMENT, SBU, DIV
  )
EXPORT_DATA_GL <- REPORT_DATA %>% filter(FISCAL_YEAR == 2025)
write.csv(EXPORT_DATA_GL,"mje_analysis_gl_entries.csv")

################################################################################


## Consolidated Data
#Classify the entries based on type
CONS_REPORT <- CONS_DATA %>% 
    filter(`Trans. Currency`> 0) %>% # filter only for the positive/debit values 
  # to not havezero sum of the documnets and be able to acuqire the MJE value.
   mutate(TYPE = case_when( # there was no indicaiton for the cases that 
    #there is text overlap e.g. "interco elim" is classified as what?
      grepl("tax", Text, ignore.case = TRUE) ~ "Tax Entry",
      grepl("equity", Text, ignore.case = TRUE) ~ "Equity Entry",
      grepl("interco", Text, ignore.case = TRUE) &
        !grepl("Intercontinetal", Text, ignore.case = TRUE) ~ "Intercompany Entry",
      grepl("elim", Text, ignore.case = TRUE) &
        !grepl("TP elim", Text, ignore.case = TRUE) ~ "Elimination Entry",
      grepl("TP elim", Text, ignore.case = TRUE) ~ "TP Elimination Entry",
      grepl("P99",`Cons unit`,ignore.case = TRUE) ~ "Core Adjustment Entry",
          TRUE ~ "Other" # default value if none of the conditions match
      )) %>% 
      group_by(`Year`,`Period`,`DocumentNo`,
           `Crcy`,`Text`,`Entry Dte`,`User Name`,TYPE) %>%
            summarise(DOC_VALUE = sum(`Trans. Currency`, na.rm = TRUE),
                      LOC_VALUE = sum(`Local currency`, na.rm = TRUE),
                      GRU_VALUE = sum(`Group currency`, na.rm = TRUE),
            .groups = "drop" #grouping and summarizing of the values to leave only 
    # unique document numbers from the initial dataset that includes Doc Line Items
  ) %>% 
  #create the dollar backets classificaiton basedo Group Crcy Value
      #create the dollar backets classificaiton basedo Group Crcy Value
      mutate(VALUE_BUCKET = case_when(
        GRU_VALUE == 0 ~ "Zero",
        GRU_VALUE > 0 & GRU_VALUE <= 100 ~ "Below $100",
        GRU_VALUE > 100 & GRU_VALUE <= 500 ~ "$101-$500",
        GRU_VALUE > 500 & GRU_VALUE <= 1000 ~ "$501-$1,000",
        GRU_VALUE > 1000 & GRU_VALUE <= 5000 ~ "$1,001-$5,000",
        GRU_VALUE > 5000 & GRU_VALUE <= 10000 ~ "$5,001-$10,000",
        GRU_VALUE > 10000 & GRU_VALUE <= 20000 ~ "$10,001-$20,000",
        GRU_VALUE > 20000 ~ "Above $20,000",
        TRUE ~ "Undefined"
      )) %>%
      mutate(VALUE_BUCKET = factor(VALUE_BUCKET, levels = c(
        "Zero", "Below $100", "$101-$500", "$501-$1,000",
        "$1,001-$5,000", "$5,001-$10,000", "$10,001-$20,000",
        "Above $20,000", "Undefined"
      )))
# --- Days lag-level analytics (CONS) ---
CONS_REPORT <- CONS_REPORT %>%
  left_join(USERS, by = c("User Name" = "USER_NAME")) %>%
  left_join(EMPLOYEE_PER_DEPARTMENT, by = c("User Name" = "EMPLOYEE_MM_ID")) %>%
  mutate(
    `Entry Dte` = as.Date(
      `Entry Dte`, tryFormats = c("%Y-%m-%d", "%m/%d/%Y", "%d.%m.%Y")
    ),
      POSTING_MONTH_END = ceiling_date(`Entry Dte`, "month") - days(1),    
    DAYS_LAG = as.integer(`Entry Dte` - POSTING_MONTH_END),
                                       DAYS_BUCKETS = cut(
                                       DAYS_LAG,
                                       breaks = breaks,
                                       labels = labels,
                                       right = TRUE,
                                       include.lowest = TRUE
                                      )) 
# --- Quarter-level analytics (CONS) ---
CONS_REPORT <- CONS_REPORT %>%
  mutate(
    # Coerce safely to numeric; handle NAs if any
    Year_num   = suppressWarnings(as.integer(`Year`)),
    Period_num = suppressWarnings(as.integer(`Period`)),
    # Build a posting period date from Year + Period (first day of month)
    POSTING_PERIOD_DATE = as.Date(paste0(Year_num, "-", sprintf("%02d", `Period_num`), "-01")),
    # Quarter label from posting period
    QUARTER = paste0("Q", quarter(POSTING_PERIOD_DATE), " ", year(POSTING_PERIOD_DATE)),
    # Last day of the quarter for the posting period
    QUARTER_END = ceiling_date(POSTING_PERIOD_DATE, "quarter") - days(1),
    # Differences vs quarter end, based on actual entry date
    ENTRY_VS_QUARTER_END_DAYS   = as.integer(`Entry Dte` - QUARTER_END),
    ENTRY_VS_QUARTER_END_MONTHS = (year(`Entry Dte`) - year(QUARTER_END)) * 12 +
      (month(`Entry Dte`) - month(QUARTER_END)),
    # Quarter-level comment
    QUARTER_POSTING_COMMENT = ifelse(
      `Entry Dte` > QUARTER_END, "Posted After Quarter End", "Within Quarter"
    ),
    # Quarter buckets (same 5-day ranges)
    QTR_DAYS_BUCKETS = cut(
      ENTRY_VS_QUARTER_END_DAYS,
      breaks = breaks,
      labels = labels,
      right = TRUE,
      include.lowest = TRUE
    )
  ) %>%
  mutate(
    QTR_DAYS_BUCKETS = factor(QTR_DAYS_BUCKETS, levels = labels, ordered = TRUE)
  ) %>%
  select(`Year`, `Period`, `DocumentNo`,
    `Text`, `Entry Dte`, `Crcy`,
    DOC_VALUE, LOC_VALUE, GRU_VALUE,
    POSTING_MONTH_END, DAYS_LAG, DAYS_BUCKETS,               # month metrics
    QUARTER, QUARTER_END, ENTRY_VS_QUARTER_END_DAYS,         # quarter metrics
    ENTRY_VS_QUARTER_END_MONTHS, QUARTER_POSTING_COMMENT,    # quarter metrics
    QTR_DAYS_BUCKETS,                                        # quarter buckets
    `User Name`, TYPE, VALUE_BUCKET,
    FULL_NAME, DEPARTMENT, SBU, DIV
  )
EXPORT_DATA_GR <- CONS_REPORT %>% filter(Year == 2025)
write.csv(EXPORT_DATA_GR,"mje_analysis_cons_entries_2025.csv")

