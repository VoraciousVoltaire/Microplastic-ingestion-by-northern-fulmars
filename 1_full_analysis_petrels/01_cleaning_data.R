## ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
## Mapping the global distribution of seabird populations
## R script to clean and prepare files (Seabird Tracking Database format) prior to kernel analysis 
## Ana Carneiro May 2018, adapted by Beth Clark Mar 2020 
## ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

################ LOADING PACKAGES ###################

rm(list=ls())

#If there are errors, can try installing these package versions:
#install.packages("devtools")
#require(devtools)
#install_version("sp", version = "1.3-2", repos = "http://cran.us.r-project.org")
#install_version("rgdal", version = "1.4-8", repos = "http://cran.us.r-project.org")
#newer versions of sp and rgdal don't work with the custom projection see:
#https://github.com/gdauby/ConR/issues/5
#https://github.com/BirdLifeInternational/track2kba/issues/29

#install.packages("geosphere"); install.packages("adehabitatHR"); 
#install.packages("rgeos"); install.packages("stringr"); nstall.packages("trip");
library(sp) #1.3-2
library(rgdal)  #1.4-8
library(geosphere) #1.5-10
library(adehabitatHR) 
library(rgeos) 
library(stringr)
library(trip)
lu=function (x=x) length(unique(x))

sessionInfo()
#R version 4.1.2 (2021-11-01)
#Platform: x86_64-w64-mingw32/x64 (64-bit)
#Running under: Windows 10 x64 (build 19045)

#Matrix products: default

#locale:
#[1] LC_COLLATE=English_United Kingdom.1252 
#[2] LC_CTYPE=English_United Kingdom.1252   
#[3] LC_MONETARY=English_United Kingdom.1252
#[4] LC_NUMERIC=C                           
#[5] LC_TIME=English_United Kingdom.1252    

#attached base packages:
#[1] stats     graphics  grDevices utils     datasets  methods  
#[7] base     

#other attached packages:
#[1] trip_1.8.5          stringr_1.4.0       rgeos_0.5-9        
#[4] adehabitatHR_0.4.19 adehabitatLT_0.3.25 CircStats_0.2-6    
#[7] boot_1.3-28         MASS_7.3-54         adehabitatMA_0.3.14
#[10] ade4_1.7-19         deldir_1.0-6        geosphere_1.5-14   
#[13] rgdal_1.4-8         sp_1.5-0           

#loaded via a namespace (and not attached):
#[1] tidyselect_1.1.2      terra_1.5-21          purrr_0.3.4          
#[4] splines_4.1.2         lattice_0.20-45       spatstat.utils_2.3-1 
#[7] vctrs_0.3.8           generics_0.1.2        mgcv_1.8-38          
#[10] utf8_1.2.2            rlang_1.0.6           spatstat.data_2.2-0  
#[13] pillar_1.7.0          glue_1.6.2            DBI_1.1.2            
#[16] crsmeta_0.3.0         lifecycle_1.0.3       spatstat.core_2.4-2  
#[19] raster_3.1-5          codetools_0.2-18      traipse_0.2.5        
#[22] fansi_1.0.2           reproj_0.4.2          Rcpp_1.0.8           
#[25] tensor_1.5            abind_1.4-5           proj4_1.0-11         
#[28] stringi_1.7.6         dplyr_1.0.8           spatstat.sparse_2.1-1
#[31] polyclip_1.10-0       grid_4.1.2            cli_3.3.0            
#[34] tools_4.1.2           magrittr_2.0.2        goftest_1.2-3        
#[37] tibble_3.1.6          crayon_1.5.0          pkgconfig_2.0.3      
#[40] ellipsis_0.3.2        spatstat.random_2.2-0 Matrix_1.3-4         
#[43] assertthat_0.2.1      rstudioapi_0.13       R6_2.5.1             
#[46] rpart_4.1-15          spatstat.geom_2.4-0   nlme_3.1-153         
#[49] compiler_4.1.2  

######### GENERAL DIRECTORIES AND FILES ##############

## set up input and output folders
dir <- "outputs/01_cleaning_data/"
dir_eq <- paste0(dir,"equinox/")
dir_maps <- paste0(dir_eq,"maps/")

#if running for the first time, create directories for outputs
# dir.create("outputs/")
# dir.create(dir) 
# dir.create(dir_eq) 
# dir.create(dir_maps)
# dir.create(paste0(dir,"equinox_filtered/"))
# dir.create(paste0(dir,"maps/"))

## PROJECTIONS
#Read in land file for visualisation:
#Natural Earth land 1:10m polygons version 5.1.1 
#downloaded from www.naturalearthdata.com/
land <- rgdal::readOGR(dsn = "input_data/baselayer", layer = "ne_10m_land")

#Read in a list of the names of the target species for the study
species_list <- read.csv("input_data/Species_list_IUCN.csv")

equinoxes <- read.csv("input_data/equinoxes.csv")
head(equinoxes)
equinoxes$mar <- as.POSIXct(equinoxes$mar, format = "%d/%m/%Y %H:%M:%S", tz = "GMT")
equinoxes$sep <- as.POSIXct(equinoxes$sep, format = "%d/%m/%Y %H:%M:%S", tz = "GMT")

#mark the start and end of the periods to filter out (it is asymmetrical)
equinoxes$mar_start <- equinoxes$mar - (21*24*60*60) #-21 days
equinoxes$mar_end <- equinoxes$mar + (7*24*60*60)    #+7 days
equinoxes$sep_start <- equinoxes$sep - (7*24*60*60)
equinoxes$sep_end <- equinoxes$sep + (21*24*60*60)

## DIRECTION OF THE ORIGINAL SPECIES FILES (AS DOWNLOADED FROM THE SEABIRD TRACKING DATABASE)
datasets <- "input_data/tracking_data/"

files <- list.files(datasets, pattern = "csv");files

skipped_age <- data.frame()
skipped_species <- data.frame()

################# LOADING SPP DATA ##################

#loop through tracking data files

for(dataset_number in 1:length(files)){ 
  print(paste(dataset_number,files[dataset_number]))
  
  #read in the dataset
  df <- read.csv(paste0(datasets,files[dataset_number])) 
  sci_name <- df$scientific_name[1];sci_name
  head(df)
  
  #remove rows with NA for lat or lon
  df <- df[!is.na(df$latitude),]
  df <- df[!is.na(df$longitude),]
  summary(df)
  
  #remove data with impossible lat/lons
  df <- subset(df, latitude < 90 & latitude > -90)
  df <- subset(df, longitude < 180 & longitude > -180)
  
  #dataset specific corrections
  if(files[dataset_number] == "Dataset_973_2019-05-30.csv"){
    df <- subset(df,  longitude > -50)
  }#this is well outside the range of the data but not in equinox period
  if(files[dataset_number] == "Procellaria parkinsoni_New Zealand_GLS_2005-2006.csv"){
    df <- subset(df, date_gmt != "2006-12-01" & date_gmt != "2006-01-20" & date_gmt != "2006-01-30")
  } #these 3 dates were outside the range of the rest of the data and had the same lat/lon for different birds
  if(files[dataset_number] == "Dataset_1585_2020-07-16.csv"){
    df <- subset(df,  longitude > -2 & latitude > 26)
  }#this is well outside the range of the data but not in equinox period
  
  #Check the scientific name is in the list of chosen species
  if(df$scientific_name[1] %in% species_list$scientific_name){
    
    #create a bespoke equal areas projections
    mean_loc <- geosphere::geomean(cbind(df$longitude,df$latitude))
    DgProj <- sp::CRS(paste0("+proj=laea +lon_0=",mean_loc[1],
                         " +lat_0=",mean_loc[2]))
    #remove non-adults
    df <- subset(df, age != "immature" & age != "juvenile")
    print(table(df$age))
    
    if(nrow(df) != 0){
      
      ###### CHECKING DATA AND CREATING DTIME COLUMN in timestamp format ######
      df$bird_id <- factor(df$bird_id)
      df$track_id <- factor(df$track_id)
      df$time_gmt <- ifelse(is.na(df$time_gmt),"00:00:00",df$time_gmt)
      df$dtime <- as.POSIXct(strptime(paste(df$date_gmt, df$time_gmt, sep=" "), 
                                      "%Y-%m-%d %H:%M:%S "),"GMT") 
      df <- df[!is.na(df$dtime),]
      ## PLOTTING TO CHECK RESULTS 
      par(mfrow=c(1,1))
      plot(latitude~longitude, data=df, type="n", asp=1, main="", frame = T, xlab="", ylab="")
      plot(land, col='lightgrey', add=T)
      points(latitude~longitude, data=df, pch=16, cex=0.5, col="blue")
      points(lat_colony~lon_colony, data=df, pch=18, cex=2, col="red")
      
      ############# DATA CLEANING: SPEED FILTER FOR PTT DATA #############
      
      devices <- unique(df$device)
      devices
      
      if("PTT" %in% devices | "GPS" %in% devices){
        
        #If the tag is a PTT
        if("PTT" %in% devices){
          
          ## REMOVE LOCATIONS WITH > 90 KM/H
          x2 <- data.frame()
          x3 <- data.frame()
          id <- unique(as.factor(df$track_id))
          for(i in 1:nlevels(id)){
            a <- subset(df, track_id == id[i])
            if(a$device[1]=="PTT" & nrow(a) > 5){
              
              # Order the rows by ID, then by time
              b <- a[order(a$dtime), ]
              # Remove completely-duplicated rows
              b <- b[!duplicated(b),]
              b$dtime <- trip::adjust.duplicateTimes(b$dtime, b$track_id)
              # Change times to hours since first fix
              b$hours <- as.numeric(difftime(b$dtime, min(b$dtime),units = "hours"))
              x2 <- rbind(x2, as.data.frame(b))} else {
                x3 <- rbind(x3, as.data.frame(a))
              }
          }
          x1 <- x2
          
          ## APPLY MCCONNELL SPEED FILTER IN TRIP PACKAGE TO REMOVE ERRONEOUS FIXES
          x2 <- data.frame(lat = x1$latitude, lon = x1$longitude, DateTime = x1$dtime, id = x1$track_id)
          ## CREATE COORDINATE VARIABLE
          sp::coordinates(x2) <- c("lon","lat")
          ## CREATE TRIP OBJECT
          tr <- trip::trip(x2, c("DateTime","id"))
          ## MCCONNELL SPEED FILTER; ignore coordinates warning as data are lonlat
          x1$Filter <- trip::speedfilter(tr, max.speed = 90)
          ## REMOVE FILTERED COORDINATES
          x1 <- subset(x1, x1$Filter==TRUE)
          x1$hours <- NULL
          x1$Filter <- NULL
          
          ## COMBINE PTT FILTERED FILE BACK INTO DF FILE (with GLS and GPS data)
          df <- rbind(x1,x3)
          
        }
        ################## LINEAR INTERPOLATION PTT AND GPS DATA #################
        x4 <- df
        
        sp::coordinates(x4) <- ~longitude+latitude
        sp::proj4string(x4) <- sp::CRS(sp::proj4string(land))
        
        ## changing  to equal area projection
        x4_laea <- sp::spTransform(x4, DgProj)
        x4 <- as.data.frame(x4_laea)
        ## INTERPOLATION
        x5 <- data.frame()
        x6 <- data.frame()
        dset_id <- unique(as.factor(x4$dataset_id))
        x4$id_stage <- paste0(x4$bird_id, "_", x4$track_id)   
        
        for(i in 1:nlevels(dset_id)){
          print(dset_id[i])
          tracks <- x4[x4$dataset_id==dset_id[i],]
          tracks$device <- factor(tracks$device)
          if(tracks$device[1]!="GLS"){
            tracks$id_stage <- factor(tracks$id_stage)
            tracks$track_time <- as.double(tracks$dtime)            
            
            tracks$birdid_time <- paste0(tracks$bird_id,tracks$track_time)
            
            #remove duplicates and NAs
            tracks <- tracks[!duplicated(tracks$birdid_time),]
            
            tracks <- tracks[!is.na(tracks$track_time),]
            
            tracks$id_stage <- as.factor(as.character(tracks$id_stage))
            
            #sort by bird then time
            #tracks <- dplyr::arrange(tracks, bird_id, track_time)
            
            traj <- adehabitatLT::as.ltraj(xy=data.frame(tracks$longitude, tracks$latitude), 
                                           date=as.POSIXct(tracks$track_time, origin="1970/01/01", tz="GMT"), 
                                           id=tracks$id_stage, typeII = TRUE)
            
            ## Rediscretization every 12 hours (43200 seconds)
            tr <- adehabitatLT::redisltraj(traj, 43200, type="time")
            ## Convert output into a data frame
            tracks.intpol <- data.frame()
            for (l in 1:length(unique(tracks$id_stage))){
              # print(tracks$id_stage[l])
              out <- tr[[l]]
              out$ID <- as.character(attributes(tr[[l]])[4])				
              tracks.intpol <- rbind(tracks.intpol, out)
            } 
            ### re-insert into the dataframe
            tracks.intpol$dataset_id <- tracks$dataset_id[match(tracks.intpol$ID,tracks$id_stage)]
            tracks.intpol$scientific_name <- tracks$scientific_name[match(tracks.intpol$ID,tracks$id_stage)]
            tracks.intpol$common_name <- tracks$common_name[match(tracks.intpol$ID,tracks$id_stage)]
            tracks.intpol$site_name <- tracks$site_name[match(tracks.intpol$ID,tracks$id_stage)]
            tracks.intpol$colony_name <- tracks$colony_name[match(tracks.intpol$ID,tracks$id_stage)]
            tracks.intpol$lat_colony <- tracks$lat_colony[match(tracks.intpol$ID,tracks$id_stage)]
            tracks.intpol$lon_colony <- tracks$lon_colony[match(tracks.intpol$ID,tracks$id_stage)]
            tracks.intpol$device <- tracks$device[match(tracks.intpol$ID,tracks$id_stage)]
            tracks.intpol$bird_id <- tracks$bird_id[match(tracks.intpol$ID,tracks$id_stage)]
            tracks.intpol$track_id <- tracks$track_id[match(tracks.intpol$ID,tracks$id_stage)]
            tracks.intpol$original_track_id <- tracks$original_track_id[match(tracks.intpol$ID,tracks$id_stage)]
            tracks.intpol$age<-tracks$age[match(tracks.intpol$ID,tracks$id_stage)]
            tracks.intpol$sex<-tracks$sex[match(tracks.intpol$ID,tracks$id_stage)]
            tracks.intpol$breed_stage <- tracks$breed_stage[match(tracks.intpol$ID,tracks$id_stage)]
            tracks.intpol$breed_status <- tracks$breed_status[match(tracks.intpol$ID,tracks$id_stage)]
            tracks.intpol$track_time <- as.double(tracks.intpol$date)
            tracks.intpol <- tracks.intpol[order(tracks.intpol$ID, tracks.intpol$track_time),]
            tracks.intpol$track_time <- adjust.duplicateTimes(tracks.intpol$track_time, tracks.intpol$ID)
            #### combines all data
            x5 <- rbind(x5, as.data.frame(tracks.intpol))
          } else {
            x6 <- rbind(x6, as.data.frame(tracks))}
        }
        ## renaming x5 and combining x5 and x6
        head(x5)
        head(x6) 
        names(x5)[names(x5) == "date"] <- "dtime"
        names(x5)[names(x5) == "x"] <- "longitude"
        names(x5)[names(x5) == "y"] <- "latitude"
        
        #remove columns that are no longer needed
        x5$ID <- NULL
        x5$dx <- NULL
        x5$dy <- NULL
        x5$dist <- NULL
        x5$dt <- NULL
        x5$R2n <- NULL
        x5$abs.angle <- NULL
        x5$rel.angle <- NULL
        x6$argos_quality <- NULL
        x6$date_gmt <- NULL
        x6$time_gmt <- NULL
        x6$track_time <- as.double(x6$dtime)
        x6$id_stage <- NULL
        x6$equinox <- NULL
        df <- rbind(x5,x6)
        df$equinox <- NA
        
      } 
      
      #if the device is GLS, filter the equinox if needed
      if(devices == "GLS"){  
        
        df$year <- substr(df$dtime,1,4)
        years <- unique(df$year)
        for(i in 1:length(years)){
          
          yr <- subset(df, df$year == years[i])
          
          df_mar <- subset(yr, dtime < equinoxes$mar_start[equinoxes$year == years[i]] |
                             dtime > equinoxes$mar_end[equinoxes$year == years[i]] ) 
          df_sep <- subset(df_mar, dtime < equinoxes$sep_start[equinoxes$year == years[i]] |
                             dtime > equinoxes$sep_end[equinoxes$year == years[i]] ) 
          if(i == 1){
            df_allyrs <- df_sep
          } else {
            df_allyrs <- rbind(df_allyrs,df_sep)
          }
          
        }
        #export plots
        png(filename = paste0("outputs/01_cleaning_data/equinox_filtered/", str_remove(files[dataset_number],".csv"),".png"))
        par(mfrow=c(2,1),mar = c(3, 4, 1, 1))
        plot(latitude~longitude, data=df, type="n", asp=1, main="", 
             frame = T, xlab="", ylab=paste(df$scientific_name[1]))
        plot(land, col='lightgrey', add=T)
        points(latitude~longitude, data=df, pch=16, cex=0.5, col="blue")
        points(latitude~longitude, data=df_allyrs, pch=16, cex=0.5, col="green")
        points(lat_colony~lon_colony, data=df, pch=18, cex=2, col="red")
        
        plot(df$dtime,df$latitude,col="blue")
        points(df_allyrs$dtime,df_allyrs$latitude,col="green")
        abline(v=equinoxes$mar,col="red")
        abline(v=equinoxes$sep,col="red")
        
        abline(v=equinoxes$mar_start,col="orange")
        abline(v=equinoxes$sep_start,col="orange")
        abline(v=equinoxes$mar_end,col="orange")
        abline(v=equinoxes$sep_end,col="orange")
        
        dev.off()
        
        df <- df_allyrs
        df$year <- NULL
        
        
        
        sp::coordinates(df) <- ~longitude+latitude
        sp::proj4string(df) <- sp::CRS(sp::proj4string(land))
        ## changing projection
        x4_laea <- sp::spTransform(df, DgProj)
        df <- as.data.frame(x4_laea)
      }
      
      ############### REMOVE COLONY POSITIONs ####
      
      ## Exclude all locations within 5 km (GPS) or 15 km (PTT) of the colony, 
      #and retain all the rest. Colony here is a single lat/lon position.
      x7 <- df
      
      ## Creating a buffer around colonies
      gps_df <- data.frame()
      ptt_df <- data.frame()
      gls_df <- data.frame()
      
      #use site name instead
      x7$site_name <- as.character(x7$site_name)
      x7$colony_name <- as.character(x7$colony_name)
      x7$colony_name <- ifelse(is.na(x7$colony_name), x7$site_name, x7$colony_name)
      x7$colony_name <- as.factor(x7$colony_name)
      
      col <- unique(x7$colony_name);col
      
      for(i in 1:nlevels(col)){
        
        print(col[i])
        sub_col <- x7[x7$colony_name==col[i],]
        sp::coordinates(sub_col) <- ~longitude+latitude
        sp::proj4string(sub_col) <- DgProj
        
        ## removing land overlap at colony
        sub_col@data$device <- factor(sub_col@data$device)
        dev <- unique(sub_col@data$device)
        
        for (j in 1:nlevels(dev)){
          print(dev[j])
          a <- sub_col[sub_col$device==dev[j],]
          
          if (a$device[1]=="GPS"){
            
            if(col[i] != "At-Sea"){
              df_col <- data.frame(cbind(lon=sub_col$lon_colony[1], lat=sub_col$lat_colony[1]))
              sp::coordinates(df_col) <- ~lon+lat
              ## assigning projection
              sp::proj4string(df_col) <- sp::CRS(sp::proj4string(land))
              ## changing projection
              col_laea <- sp::spTransform(df_col, DgProj)
              ## buffers
              buf_small <- rgeos::gBuffer(col_laea, width = 5000)
              gps <- a[is.na(over(a, buf_small)),]
            } else {
              gps <- a[is.na(a),]
            }
            col_df <- as.data.frame(gps)
            col_df$argos_quality <- NA
            col_df$equinox <- NA
            gps_df <- rbind(gps_df, col_df)
            
            
          } else if (a$device[1]=="PTT"){
            
            if(col[i] != "At-Sea"){
              df_col <- data.frame(cbind(lon=sub_col$lon_colony[1], lat=sub_col$lat_colony[1]))
              sp::coordinates(df_col) <- ~lon+lat
              ## assigning projection
              sp::proj4string(df_col) <- sp::CRS(sp::proj4string(land))
              ## changing projection
              col_laea <- sp::spTransform(df_col, DgProj)
              ## buffers
              buf_large <- rgeos::gBuffer(col_laea, width = 15000)
              ptt <- a[is.na(over(a, buf_large)),]
            } else {
              ptt <- a
            }
            col_df <- as.data.frame(ptt)
            col_df$argos_quality <- NA
            col_df$equinox <- NA
            ptt_df <- rbind(ptt_df, col_df)
            
            
          } else {
            col_df <- as.data.frame(a)
            col_df$track_time <- NA
            col_df$date_gmt <- NULL
            col_df$time_gmt <- NULL
            
            head(col_df)
            years <- unique(substr(col_df$dtime,1,4))
            
            
            gls_df <- rbind(gls_df, col_df)
            
            
          }
        }
      } 
      
      df_all <-  rbind(gps_df, ptt_df, gls_df)
      sp::coordinates(df_all) <- ~longitude+latitude
      sp::proj4string(df_all) <- DgProj
      ## changing projection
      df_all_wgs <- sp::spTransform(df_all, (sp::proj4string(land)))
      df_all_wgs <- as.data.frame(df_all_wgs)
      df <- df_all_wgs
      df$original_track_id <- NULL
      df$equinox <- NA

      ############ EXPORT RESULTS #########

      site <- str_remove(df$site_name[1],"/")
      colony <- str_remove(df$colony_name[1],"/")
      
      write.csv(df, paste0(dir,  
                           df$scientific_name[1],"_",site,"_",colony,"_",
                           df$dataset_id[1],".csv"), 
                row.names = FALSE)
      
      ## PLOTTING TO CHECK RESULTS
      png(filename = paste0(dir, "maps/", 
                            df$scientific_name[1],"_",site,"_",colony,"_",
                            df$dataset_id[1],".png"))
      plot(latitude~longitude, data=df, type="n", asp=1, 
           xlim=c(-180,180), ylim=c(-90,90), 
           main="", frame = T, xlab="", ylab="")
      plot(land, col='lightgrey', add=T)
      points(latitude~longitude, data=df, pch=16, cex=0.5, col="green")
      points(lat_colony~lon_colony, data=df, pch=18, cex=1, col="purple")
      dev.off()
      
      print(df$scientific_name[1])
      print(df$colony_name[1])
      
    } else {
      name <- paste0(sci_name," dataset_number = ",dataset_number)
      skipped_age <- rbind(skipped_age, as.data.frame(name))
    }
  } else {
    name <- paste0(sci_name," dataset_number = ",dataset_number)
    skipped_species <- rbind(skipped_species, as.data.frame(name))
  }
  
}

#check skipped files
skipped_age
skipped_species

#Went to folder and check whether all GLS files need equinox filtering
#(some have undergone corrections e.g. with SST)
#visually judged based on obvious error in the blue locations (equinox periods)
#

#these are excluded from equinox filtering based on maps in "/01_cleaning_data/equinox/"

#to mark for rerunning without the filter, the map images are manually placed in a new folder
#"/01_cleaning_data/equinox_filtered/remove_equinox_filter"

remove_equinox_filter <- list.files(paste0(dir,"equinox_filtered/remove_equinox_filter/"),
                                    pattern = ".png")
remove_equinox_filter

files <- str_replace(remove_equinox_filter,".png",".csv")                  

#run the same process again, but this time only with the files we are removing the filter for
#(code relating only to GPS or PTT removed)

for(dataset_number in 1:length(files)){ 
  print(paste(dataset_number,files[dataset_number]))
  
  #read in the dataset
  df <- read.csv(paste0(datasets,files[dataset_number])) 
  sci_name <- df$scientific_name[1];sci_name
  head(df)
  
  #remove rows with NA for lat or lon
  df <- df[!is.na(df$latitude),]
  df <- df[!is.na(df$longitude),]
  summary(df)
  
  #remove data with impossible lat/lons
  df <- subset(df, latitude < 90 & latitude > -90)
  df <- subset(df, longitude < 180 & longitude > -180)
  
  #dataset specific corrections
  if(files[dataset_number] == "Dataset_973_2019-05-30.csv"){
    df <- subset(df,  longitude > -50)
  }#this is well outside the range of the data but not in equinox period
  if(files[dataset_number] == "Procellaria parkinsoni_New Zealand_GLS_2005-2006.csv"){
    df <- subset(df, date_gmt != "2006-12-01" & date_gmt != "2006-01-20" & date_gmt != "2006-01-30")
  } #these 3 dates were outside the range of the rest of the data and had the same lat/lon for different birds
  if(files[dataset_number] == "Dataset_1585_2020-07-16.csv"){
    df <- subset(df,  longitude > -2 & latitude > 26)
  }#this is well outside the range of the data but not in equinox period
  
  #create a bespoke equal areas projections
  mean_loc <- geosphere::geomean(cbind(df$longitude,df$latitude))
  DgProj <- sp::CRS(paste0("+proj=laea +lon_0=",mean_loc[1],
                       " +lat_0=",mean_loc[2]))
  
  
  
  ###### CHECKING DATA AND CREATING DTIME COLUMN in timestamp format ######
  df$bird_id <- factor(df$bird_id)
  df$track_id <- factor(df$track_id)
  df$time_gmt <- ifelse(is.na(df$time_gmt),"00:00:00",df$time_gmt)
  df$dtime <- as.POSIXct(strptime(paste(df$date_gmt, df$time_gmt, sep=" "), 
                                  "%Y-%m-%d %H:%M:%S "),"GMT") 
  df <- df[!is.na(df$dtime),]
  ## PLOTTING TO CHECK RESULTS 
  par(mfrow=c(1,1))
  plot(latitude~longitude, data=df, type="n", asp=1, main="", frame = T, xlab="", ylab="")
  plot(land, col='lightgrey', add=T)
  points(latitude~longitude, data=df, pch=16, cex=0.5, col="blue")
  points(lat_colony~lon_colony, data=df, pch=18, cex=2, col="red")
  
  ############# DATA CLEANING #############
  
  sp::coordinates(df) <- ~longitude+latitude
  sp::proj4string(df) <- sp::CRS(sp::proj4string(land))
  ## changing projection
  x4_laea <- sp::spTransform(df, DgProj)
  df <- as.data.frame(x4_laea)
  
  
  ############### REMOVE COLONY POSITIONs ####
  
  ## Exclude all locations within 5 km (GPS) or 15 km (PTT) of the colony, 
  #and retain all the rest. Colony here is a single lat/lon position.
  x7 <- df
  
  ## Creating a buffer around colonies
  gls_df <- data.frame()
  
  #use site name instead
  x7$site_name <- as.character(x7$site_name)
  x7$colony_name <- as.character(x7$colony_name)
  x7$colony_name <- ifelse(is.na(x7$colony_name), x7$site_name, x7$colony_name)
  x7$colony_name <- as.factor(x7$colony_name)
  
  col <- unique(x7$colony_name);col
  
  for(i in 1:nlevels(col)){
    
    print(col[i])
    sub_col <- x7[x7$colony_name==col[i],]
    sp::coordinates(sub_col) <- ~longitude+latitude
    sp::proj4string(sub_col) <- DgProj
    
    ## removing land overlap at colony
    sub_col@data$device <- factor(sub_col@data$device)
    dev <- unique(sub_col@data$device)
    
    for (j in 1:nlevels(dev)){
      print(dev[j])
      a <- sub_col[sub_col$device==dev[j],]
      
      if (a$device[1]=="GLS"){

        col_df <- as.data.frame(a)
        col_df$track_time <- NA
        col_df$date_gmt <- NULL
        col_df$time_gmt <- NULL
        
        head(col_df)
        years <- unique(substr(col_df$dtime,1,4))
        
        
        gls_df <- rbind(gls_df, col_df)
        
        
      }
    }
  } 
  
  df_all <-  rbind(gls_df)
  sp::coordinates(df_all) <- ~longitude+latitude
  sp::proj4string(df_all) <- DgProj
  ## changing projection
  df_all_wgs <- sp::spTransform(df_all, (sp::proj4string(land)))
  df_all_wgs <- as.data.frame(df_all_wgs)
  df <- df_all_wgs
  df$original_track_id <- NULL
  df$equinox <- NA
  
  ############ EXPORT RESULTS #########
  
  ## export tracking data cleaned and formatted
  
  site <- str_remove(df$site_name[1],"/")
  colony <- str_remove(df$colony_name[1],"/")
  
  write.csv(df, paste0(dir,  
                       df$scientific_name[1],"_",site,"_",colony,"_",
                       df$dataset_id[1],".csv"), 
            row.names = FALSE)
  
  ## PLOTTING TO CHECK RESULTS
  png(filename = paste0(dir, "maps/", 
                        df$scientific_name[1],"_",site,"_",colony,"_",
                        df$dataset_id[1],".png"))
  plot(latitude~longitude, data=df, type="n", asp=1, 
       xlim=c(-180,180), ylim=c(-90,90), 
       main="", frame = T, xlab="", ylab="")
  plot(land, col='lightgrey', add=T)
  points(latitude~longitude, data=df, pch=16, cex=0.5, col="green")
  points(lat_colony~lon_colony, data=df, pch=18, cex=1, col="purple")
  dev.off()
  
  print(df$scientific_name[1])
  print(df$colony_name[1])
  
}

