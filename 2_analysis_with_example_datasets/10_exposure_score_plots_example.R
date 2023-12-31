## Read in exposure scores grouped by population, season
## and species, and plot results including IUCN redlist
## threat categories.
## Beth Clark 2022

rm(list=ls()) 

library(raster)
library(tidyverse)
library(viridis)
library(cowplot)
library(ggtext)
se <- function(x) sqrt(var(x)/length(x))

pops <- read.csv("outputs/05_exposure_scores_by_population.csv")
seasons <- read.csv("outputs/07_exposure_scores_by_season.csv")
species <- read.csv("outputs/08_exposure_scores_by_species.csv")

summary(species$species_exposure)

#add common name & IUCN
names_iucn <- read.csv("input_data/Species_list_IUCN.csv")
head(names_iucn)

pops$common_name <- names_iucn$common_name[match(pops$species,names_iucn$scientific_name)]
pops$iucn <- names_iucn$IUCN[match(pops$species,names_iucn$scientific_name)]
head(pops)

seasons$species <- pops$species[match(seasons$species_pop,pops$sp_pop)]
seasons$common_name <- names_iucn$common_name[match(seasons$species,names_iucn$scientific_name)]
seasons$iucn <- names_iucn$IUCN[match(seasons$species,names_iucn$scientific_name)]

species$common_name <- names_iucn$common_name[match(species$species,names_iucn$scientific_name)]
species$iucn <- names_iucn$IUCN[match(species$species,names_iucn$scientific_name)]
head(species)

#plot season scores for populations with greatest differences ####
#calculate season differences 
head(seasons)
seasons$tracks_breeding <- NULL
seasons$tracks_nonbreeding <- NULL
seasons$ref_breeding <- NULL
seasons$ref_nonbreeding <- NULL
seasons$season_diff_raw <- seasons$br_exposure - seasons$nonbr_exposure 
seasons$season_diff <- abs(seasons$br_exposure - seasons$nonbr_exposure)
head(seasons)

#pivot longer for plotting
seasons_plot <- pivot_longer(seasons, c(br_exposure, nonbr_exposure),
                     names_to = "season", 
                     values_to = "season_exposure") %>% 
  data.frame();head(seasons_plot)

#remove non breeding seasons that don't exist
seasons_plot <- subset(seasons_plot, !is.na(seasons_plot$season_exposure)) #

hist(seasons_plot$season_exposure)

#correct population names for plotting
seasons_plot$sp_pop <- seasons_plot$species_pop 
seasons_plot$pop <- gsub(".*_","",seasons_plot$sp_pop)
seasons_plot$species_pop <- paste0(seasons_plot$common_name,", ",
                                  seasons_plot$pop)

seasons_plot$species_pop <-  ifelse(seasons_plot$species_pop == "Incorrect name",
                           "Correct name",
                           seasons_plot$species_pop)

seasons_plot$species_pop <- paste0(seasons_plot$species_pop," ")

seasons <- ggplot(seasons_plot,aes(reorder(species_pop, season_diff),season_exposure,
                             season_exposure,group=species_pop)) +
  theme_bw()+
  coord_flip() +
  xlab("") +
  scale_colour_manual(values = c("grey","black"))+
  geom_line(colour="#696969",size=2)+   geom_point(aes(colour=season),size=8) +
  theme(legend.position = "none")+
  ylab("\nSeason-specific plastic exposure")+ 
  theme(text=element_text(size = 42),
        axis.text = element_text(colour="black"));seasons

png("outputs/10_season_differences.png", 
    width=1350,height=1840) 
par(mfrow=c(1,1))
seasons
dev.off()
dev.off()

#plot species scores ####
head(species)
species$species_label <- paste0(species$common_name,
                               " (",species$n_pops,",",
                               species$seasons,") ",
                               species$iucn)

#split in half for plotting
plot_species <- ggplot(species,
                   aes(reorder(species,species_exposure),
                       species_exposure)) +
  geom_point(size=4) +
  coord_flip() +
  scale_y_continuous(limits = c(0,max(species$species_exposure)*1.05),expand = c(0,0))+
  xlab("") + ylab("Plastic exposure score") +
  theme(axis.ticks = element_blank())+
  theme_bw() 

#add the population level scores ####

head(pops)
max(pops$population_exposure)
pops$species_label <- species$species_label[match(pops$species,species$species)]

#add in dashed line for the score if plastic was evenly distributed
#read in plastics data
plastics <- raster("outputs/00_PlasticsRaster.tif")
plastics[is.na(plastics)] <- 0 
p_sum1 <- plastics/sum(getValues(plastics))
p_sum1_mean <- p_sum1
p_sum1_mean[!is.na(plastics)] <- mean(getValues(p_sum1))
exp <- p_sum1_mean*p_sum1
mean_plastic_score <- sum(getValues(exp))*1000000
mean_plastic_score

#how many species above this?
above_mean <- subset(species,species_exposure > mean_plastic_score)
above_mean
table(above_mean$iucn) 

sp_pops <- ggplot(species, aes(reorder(species_label,
                                      species_exposure),
                                      species_exposure)) +
  geom_point(size=6) +
  geom_point(aes(species_label,population_exposure),
             data = pops,
             size=7,alpha=0.2,shape=18) +
  coord_flip() +
  xlab("") + ylab("Plastic exposure score") +
  scale_y_continuous(limits = c(0,max(pops$population_exposure)*1.05),expand = c(0,0))+
  theme(axis.ticks = element_blank())+
  theme_bw()+ 
  theme(text=element_text(size = 25),
        axis.text = element_text(colour="black"));sp_pops


png("outputs/10_species_exposure_scores.png", 
    width=2000,height=1125)
par(mfrow=c(1,1))
sp_pops
dev.off()
dev.off()

# plot iucn red list categories ####
head(species)

iucn <- species %>% 
  group_by(iucn) %>%
  summarise(sum = sum(species_exposure),
            mean = mean(species_exposure),
            n = n()) %>%
  data.frame();iucn

iucn$Exposure <- iucn$sum/sum(iucn$sum)
iucn$Species <- iucn$n/sum(iucn$n)

iucn_bars <- pivot_longer(iucn, c(Species,Exposure),
                          names_to = "type", 
                          values_to = "prop") %>% 
  data.frame();iucn_bars

iucn_bars$type <- factor(iucn_bars$type,levels=c("Species","Exposure"))

all_iucn <- ggplot(iucn_bars,
                   aes(y=prop,x=type,label=iucn,
                       fill=factor(iucn,levels=c("CR","EN","VU","NT","LC")))) +
  geom_bar(position="stack", stat="identity") +
  scale_fill_manual(values = c("#A60808","#E22929","#EA6666","#F3A3A3",
                               "grey"))+
  theme(axis.ticks = element_blank())+
  theme_bw() + 
  theme(legend.position = "none")+
  labs(fill = "IUCN\nRed List\nCategory")+
  scale_y_continuous(labels = scales::percent,expand=c(0,0))+
  xlab("")+ylab("")+
  theme(plot.margin=unit(c(1,1,-1,-1),"cm"))+
  theme(text=element_text(size = 55,colour="black"));all_iucn

png("outputs/10_iucn_redlist.png", 
    width=700,height=2000)
all_iucn
dev.off()
dev.off()
