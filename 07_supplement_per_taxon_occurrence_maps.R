# a script to calculate the difference in occurrence numbers per taxon for the supplement

# a script to visualize the raw and cleaned records
library(tidyverse)
library(raster)
library(viridis)
library(ggthemes)
library(speciesgeocodeR)

# load data
dat <- read_csv("output/all_records.csv") %>% 
  filter(!is.na(decimalLongitude)) %>% 
  filter(!is.na(decimalLatitude))

be <- raster("input/ABROCOMIDAE_ABROCOMIDAE.tif")

# define projections
behr <- '+proj=cea +lon_0=0 +lat_ts=30 +x_0=0 +y_0=0 +datum=WGS84 +ellps=WGS84 +units=m +no_defs'
wgs1984 <- "+proj=longlat +ellps=WGS84 +datum=WGS84 +no_defs"

# background map
world.inp  <- suppressWarnings(rnaturalearth::ne_download(scale = 50, 
                                                          type = 'land', 
                                                          category = 'physical',
                                                          load = TRUE))
world.behr <- spTransform(world.inp, CRS(behr)) %>% fortify()

#cleaned data for main mansucript
plo <- dat %>%
  filter(summary) %>% 
  select(species, taxon, decimalLongitude, decimalLatitude)

plo <- split(plo, f = plo$taxon)

plo <-  lapply(plo, 
               function(k){
                 pts <- k[, c("decimalLongitude", "decimalLatitude")]%>%
                   SpatialPoints(proj4string = CRS(wgs1984))%>%
                   spTransform(behr) %>% 
                   coordinates()
                 pts <-  data.frame(species = k$species,
                                    pts)
                 out <- pts %>% 
                   RichnessGrid(ras = be, type = "spnum") %>% 
                   rasterToPoints() %>% 
                   data.frame()})

plo_cl <- bind_rows(plo, .id = "taxon")
names(plo_cl)[4] <- "layer_cl"

# unfiltered for the supplement
plo <- dat %>%
  select(species, taxon, decimalLongitude, decimalLatitude)

plo <- split(plo, f = plo$taxon)

plo <-  lapply(plo, 
               function(k){
                 pts <- k[, c("decimalLongitude", "decimalLatitude")]%>%
                   SpatialPoints(proj4string = CRS(wgs1984))%>%
                   spTransform(behr) %>% 
                   coordinates()
                 pts <-  data.frame(species = k$species,
                                    pts)
                 out <- pts %>% 
                   RichnessGrid(ras = be, type = "spnum") %>% 
                   rasterToPoints() %>% 
                   data.frame()})

plo_rw <- bind_rows(plo, .id = "taxon")
names(plo_rw)[4] <- "layer_rw"

plo <- full_join(plo_rw, plo_cl, by = c("taxon", "x", "y")) 

# per species plots for the supplement
li <- unique(plo$taxon)

for(i in 1:length(li)){
  sub <- filter(plo, taxon == li[i]) %>% 
    pivot_longer(contains("layer"), values_to = "species", names_to = "dataset") %>% 
    mutate(dataset = recode(dataset, layer_rw = "Raw", layer_cl = "Filtered")) %>% 
    mutate(dataset = factor(dataset, levels = c("Raw", "Filtered")))
  
  ggplot()+
    geom_polygon(data = world.behr,
                 aes(x = long, y = lat, group = group), fill = "transparent", color = "black")+
    geom_tile(data = sub, aes(x = x, y = y, fill = species), alpha = 0.8)+
    scale_fill_viridis(name = "Number of\nspecies", direction = 1, na.value = "transparent")+
    xlim(-12000000, -3000000)+
    ylim(-6500000, 4500000)+
    coord_fixed()+
    theme_bw()+
    theme(legend.position = "bottom",
          legend.key.width = unit(1.5, "cm"),
          axis.title = element_blank(),
          axis.ticks = element_blank(),
          axis.text = element_blank(),
          panel.grid.major = element_blank(),
          panel.grid.minor = element_blank())+
    facet_wrap(.~ dataset)
  
  ggsave(paste("output/species_richness/", li[i], ".jpg", sep = ""), height = 6.5, width=8)
  
}