library(tidyverse)
library(googlesheets4)
library(boxr)
library(assertr)

# --- Set up auth -----

# TODO: Look into service app creds, or use oob=T to avoid manually opening a
# browser below
googlesheets4::gs4_auth()

# Store current date for use in columns later on
current_date = Sys.Date()


# --- Read in data -----

# TODO: Update this below chunk to read in directly from Box location where management uploads Baragaining List
current_exec_unit_df = googlesheets4::read_sheet(
  ss = "https://docs.google.com/spreadsheets/d/1To2ZdRfLwb1RhNwNjddK1KScy9mBtdCHzOQ1rIdoMg8/edit#gid=2131000715") %>% 
  janitor::clean_names() %>% 
  rename(urban_email = email_primary_work,
         center = cost_center) %>% 
  mutate(full_name = paste(first_name, last_name, sep = " "),
         urban_email = str_to_lower(urban_email) ) %>% 
  # Remove last two rows which have postscript notes
  head(-2)

  
previous_unit_df = googlesheets4::read_sheet(
  ss = "https://docs.google.com/spreadsheets/d/1uc_872Vky8668uH181eldfaFlM7b2yBf7TWxN-2Pop0/edit#gid=249044171") %>% 
  janitor::clean_names() %>% 
  mutate(urban_email = str_to_lower(urban_email))


# --- Transform data -----

# Get ppl still in unit from last time
ppl_still_in_unit = current_exec_unit_df %>% 
  inner_join(previous_unit_df %>% 
              # We want updated center full name and positions ni case they change from
              # Exec's updated list
              select(-center, -full_name, -position),
            by = "urban_email")

# Get ppl newly added
ppl_newly_added = current_exec_unit_df %>% 
  anti_join(previous_unit_df %>% 
               select(-center),
             by = "urban_email") %>% 
  mutate(date_newly_added = current_date)

# For full updated_unit_df, merge above two together, ppl_newly_added will have 
# NAs for many of the columns we've added, but this is intentional!
updated_unit_df = ppl_still_in_unit %>% 
  bind_rows(ppl_newly_added) %>% 
  arrange(date_newly_added, first_name)

# Get list of ppl removed who were in unit previously
ppl_removed = previous_unit_df %>% 
  anti_join(current_exec_unit_df,
            by = "urban_email")  %>% 
  mutate(date_removed = current_date)

# --- Run data checks -----
nrow_previous = previous_unit_df %>% nrow()
nrow_ppl_still_in = ppl_still_in_unit %>% nrow()
nrow_ppl_removed = ppl_removed %>% nrow()
nrow_ppl_added = ppl_newly_added %>% nrow()
nrow_updated_unit = updated_unit_df %>% nrow()

stopifnot(nrow_previous == (nrow_ppl_still_in + nrow_ppl_removed))
stopifnot(nrow_updated_unit == (nrow_ppl_still_in + nrow_ppl_added))

# --- Write out data -----

# All into different sheets which are overwritten
updated_unit_df %>% sheet_write(
  ss = "https://docs.google.com/spreadsheets/d/1uc_872Vky8668uH181eldfaFlM7b2yBf7TWxN-2Pop0/edit#gid=249044171",
  sheet = "full_bargaining_unit")

ppl_newly_added %>% sheet_write(
  ss = "https://docs.google.com/spreadsheets/d/1uc_872Vky8668uH181eldfaFlM7b2yBf7TWxN-2Pop0/edit#gid=249044171",
  sheet = "ppl_newly_added")

ppl_removed %>% sheet_write(
  ss = "https://docs.google.com/spreadsheets/d/1uc_872Vky8668uH181eldfaFlM7b2yBf7TWxN-2Pop0/edit#gid=249044171",
  sheet = "ppl_removed")

# Resize column widths of all sheets
sheet_names = c("full_bargaining_unit", "ppl_newly_added", "ppl_removed")
sheet_names %>% map(
  .f = ~range_autofit(
    ss = "https://docs.google.com/spreadsheets/d/1uc_872Vky8668uH181eldfaFlM7b2yBf7TWxN-2Pop0/edit#gid=249044171",
    sheet = .x
  )
)


