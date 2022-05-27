# Update Bargaining Unit list

This repo contains `scripts/update-baragaining-unit-list.R`, which uses the `googlesheets4` and `boxr` pacakge to:

  1) Get an updated baragining unit list from Box (which management updates monthly)

  2) Run some data checks and append to previous bargaining unit lists
  
  3) Write out current bargaining unit list into our main Google Sheet
  
 
## Requirements

You will need a `.env` file in the root directory with some secrets for accssing our Box and Google acccounts. This file will be gitignored by default.


  
