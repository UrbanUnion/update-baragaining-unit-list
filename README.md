# Update Bargaining Unit list

This repo contains `scripts/update-baragaining-unit-list.R`, which uses the `googlesheets4` and `boxr` pacakge to:

  1) Get an updated bargaining unit list from Box (which management updates monthly). Right now this list is called "All_Active_Employees_-_Bargaining_Unit_current.xlsx" and has a filed id called 931542030491. That fileid may change if Exec changes that filename of the and that fileid will then need to be changed in `scripts/update_bargaining_unit_list.R`. 

  2) Run some data checks and append to previous bargaining unit lists
  
  3) Write out current bargaining unit list into our main Google Sheet
  
 
## Requirements

You will need a `.env` file in the root directory with some secrets for accssing our Box and Google acccounts. This file will be gitignored by default.


  
