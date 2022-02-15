library(tidyverse)
library(googlesheets4)
library(boxr)
library(assertr)
library(dotenv)

# --- Set up auth -----

# TODO: Look into service app creds, or use oob=T to avoid manually opening a
# browser below
googlesheets4::gs4_auth()

# Store current date for use in columns later on
current_date = Sys.Date()


# When using GH actions, env vars won't be in .env file
# and will instead be loaded in as a repository secret.
# So we safely use load_dot_env for local development
load_dot_env_safely <- purrr::possibly(load_dot_env,
                                       otherwise = ".env file was not found and therefore not loaded"
)

# For some reason the service app auth route isn't working
# box_config_json <- Sys.getenv("box_config_json")
# boxr::box_auth_service(token_text = box_config_json)

box_auth(client_id = Sys.getenv("BOX_CLIENT_ID"),
         client_secret = Sys.getenv("BOX_CLIENT_SECRET"),
         interactive = F)


# --- Read in data -----
current_exec_unit_df = boxr::box_read_excel(
    file_id = "904453237921"
  ) %>% 
  janitor::clean_names() %>% 
  rename(urban_email = email_primary_work,
         center = cost_center) %>% 
  tidylog::mutate(full_name = paste(first_name, last_name, sep = " "),
                  urban_email = str_to_lower(urban_email),
                  will_change_if_supervisee = 
                    case_when(
                      str_detect(full_name, "\\*\\*") ~ 1,
                      TRUE ~ 0
                    ),
                  needs_to_sign_nda = 
                    case_when(
                      str_detect(full_name, "\\*") & will_change_if_supervisee ==0 ~ 1,
                      TRUE ~ 0
                    )
  ) %>% 
  tidylog::filter(
    !str_detect(first_name, "The person holding this position")
  ) %>% 
  as_tibble() %>% 
  # For some reason Exec keeps forgetting Emberlins email, so we add it ourselves
  tidylog::mutate(urban_email = if_else(first_name == "Emberlin" & last_name == "Leja", 
                               "eleja@urban.org", 
                               urban_email))


testthat::test_that("No blank Urban emails in Exec's list",
                    testthat::expect_equal(
                      current_exec_unit_df %>% 
                        filter(is.na(urban_email)) %>% 
                        nrow(), 0))
                            

previous_unit_df = googlesheets4::read_sheet(
  ss = "https://docs.google.com/spreadsheets/d/1uc_872Vky8668uH181eldfaFlM7b2yBf7TWxN-2Pop0/edit#gid=249044171") %>% 
  janitor::clean_names() %>% 
  mutate(urban_email = str_to_lower(urban_email))


# --- Transform data -----

# Get ppl still in unit from last time
ppl_still_in_unit = current_exec_unit_df %>% 
  tidylog::inner_join(previous_unit_df %>% 
              # We want updated center full name and positions ni case they change from
              # Exec's updated list
              select(-center, -full_name, -position, -first_name, -last_name),
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

# Update ppl_newly_added tab
read_sheet(
    ss = "https://docs.google.com/spreadsheets/d/1uc_872Vky8668uH181eldfaFlM7b2yBf7TWxN-2Pop0/edit#gid=249044171",
    sheet = "ppl_newly_added") %>% 
  bind_rows(ppl_newly_added) %>% 
  write_sheet(
    ss = "https://docs.google.com/spreadsheets/d/1uc_872Vky8668uH181eldfaFlM7b2yBf7TWxN-2Pop0/edit#gid=249044171",
    sheet = "ppl_newly_added"
  )

# Update ppl_removed tab
read_sheet(
  ss = "https://docs.google.com/spreadsheets/d/1uc_872Vky8668uH181eldfaFlM7b2yBf7TWxN-2Pop0/edit#gid=249044171",
  sheet = "ppl_removed") %>% 
  bind_rows(ppl_removed) %>% 
  write_sheet(
    ss = "https://docs.google.com/spreadsheets/d/1uc_872Vky8668uH181eldfaFlM7b2yBf7TWxN-2Pop0/edit#gid=249044171",
    sheet = "ppl_removed"
  )


# Resize column widths of all sheets
sheet_names = c("full_bargaining_unit", "ppl_newly_added", "ppl_removed")
sheet_names %>% map(
  .f = ~range_autofit(
    ss = "https://docs.google.com/spreadsheets/d/1uc_872Vky8668uH181eldfaFlM7b2yBf7TWxN-2Pop0/edit#gid=249044171",
    sheet = .x
  )
)


