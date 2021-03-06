# Originally this was for a blog post in May 2019.
# Updated November 2019 to produce just the latest line graph and Twitter-friendly animation
#
# Peter Ellis

library(rvest)
library(tidyverse)
library(scales)
library(gganimate)
library(svglite)
library(frs)
library(lubridate)
library(transformr)
library(gifski)

the_caption <- "Data from https://www.treasury.gov/, analysis by freerangestats.info"

# we read in the data a year at a time because although there is a page with all 29 years of data,
# it was too difficult to read in all at once ie it crashed my humble laptop:
read_a_year <- function(y){
  url_stub <- "https://www.treasury.gov/resource-center/data-chart-center/interest-rates/pages/TextView.aspx?data=yieldYear&year=XXXX"
  url <- gsub("XXXX", y, url_stub)
  
  yield_page <- read_html(url)
  yield_data <- as_tibble(html_table(yield_page, fill = TRUE)[[2]] )
  
  return(yield_data)
  
}

yields_l <- lapply(1990:2019, read_a_year)


periods <- tibble(
  period = paste(c(1,2,3,6,1,2,3,5,7,10,20,30), rep(c("mo", "yr"), c(4,8))),
  period_n = c(30, 60, 90, 180, 365.25 * c(1,2,3,5,7,10,20,30))
)

yields <- do.call("rbind", yields_l) %>%
  mutate(Date = as.Date(Date, format = c("%m/%d/%y"))) %>%
  gather(period, value, -Date) %>%
  mutate(value = suppressWarnings(as.numeric(value))) %>% 
  left_join(periods, by = "period") %>%
  group_by(Date) %>%
  mutate(ratio_5_30 = value[period == "30 yr"] / value[period == "5 yr"],
         yield_av = mean(value, na.rm = TRUE, tr = 0.2),
         yield_30yr = value[period == "30 yr"],
         yield_3mo = value[period == "3 mo"],
         diff303 = yield_30yr - yield_3mo) %>%
  ungroup() %>%
  filter(!is.na(value)) 
  
col_br <- tibble(
  lab = c(1990, 2000, 2010),
  date = as.Date(paste0(c(1990, 2000, 2010), "-03-01"))
) %>%
  mutate(date_n = as.numeric(date))

p2 <- yields %>% 
#  filter(Date < as.Date("1990-01-31")) %>%
  ggplot(aes(x = period_n, y = value, group = Date, colour = as.numeric(Date))) +
  geom_path(alpha = 0.1) +
  scale_colour_viridis_c("",
                         breaks = pull(col_br, date_n),
                         labels = pull(col_br, lab)) +
  scale_y_continuous("Treasury yield curve rate") +
  scale_x_continuous("", breaks = periods[c(10:12), ]$period_n,
                     labels = periods[c(10:12), ]$period) +
  labs(caption = the_caption)

# svglite("../img/0151-all-years-one-frame.svg", 8, 6)
# print(p2)
# dev.off()

d <- yields  #%>% filter(Date < as.Date("1991-02-28"))

a <- d %>% 
  ggplot(aes(x = period_n, y = value)) +
  geom_segment(data = distinct(d, Date, yield_3mo, yield_30yr),
               x = 90, xend = 10958, aes(y = yield_3mo, yend = yield_30yr),
               colour = "grey50") +
  geom_line(size = 1.5, aes(colour = diff303)) +
  scale_y_continuous("Treasury yield curve rate") +
  scale_x_continuous("", breaks = periods[c(10:12), ]$period_n,
                     labels = periods[c(10:12), ]$period) +
  scale_colour_viridis_c("Premium for long term lending:\n30 year yield minus 3 month yield", 
                         option= "A", direction = -1) +
  labs(title = "US Treasury Yield Curve Rates, 1990 to 2019",
       subtitle = 'Date: {frame_time}',
       caption = the_caption) +
  transition_time(Date) 


# Save the frames in the file system and then manually knit into an animation, because
# there are so many and so large that I like to keep control of the two steps:
# dir.create("tmp")
# res <- 150
# animate(a, nframes = length(unique(d$Date)) * 3, dev = "png", fps = 30,
#         type = "cairo-png", antialias = "subpixel", 
#         width = 6 * res, height =  4.3 * res, res = res,
#         renderer = file_renderer(dir = "tmp", overwrite = TRUE))
# 
# od <- setwd("tmp")
# system("ffmpeg -i gganim_plot%04d.png  -pix_fmt yuv420p -s 900x646 -c:v libx264 -r 30 movie.mp4")
# setwd(od)


p3 <- yields %>%
  mutate(period = fct_reorder(period, period_n)) %>%
  ggplot(aes(x = Date, y = value, colour = period)) +
  geom_line() +
  scale_colour_viridis_d(option = "C") +
  labs(x = "", colour = "Term", y = "Treasury yield curve rate",
       caption = the_caption) +
  ggtitle("US Treasury Yield Curve Rates, 1990 to 2019")

frs::svg_png(p3, "../img/0151-trad-line-latest", 8, 6)

# plots <- list.files(pattern = "0151.*\\.svg", path = "../img/", full.names = TRUE)
# lapply(plots, svg_googlefonts)

#-----------------Gif version for Twitter------------
d2 <- yields %>%
  mutate(mon = month(Date),
         yr = year(Date)) %>%
  group_by(mon, yr, period_n, period) %>%
  summarise(value = mean(value, na.rm = TRUE)) %>%
  ungroup() %>%
  complete(mon, yr, period, fill = list(value = NA)) %>%
  group_by(mon, yr) %>%
  mutate(yield_30yr = value[period == "30 yr"],
         yield_3mo = value[period == "3 mo"],
         diff303 = yield_30yr - yield_3mo) %>%
  ungroup() %>%
  filter(!is.na(value)) %>%
  mutate(Date = as.Date(paste(yr, mon, 15, sep = "-"), format = "%Y-%m-%d"))
  

a2 <- d2 %>% 
  ggplot(aes(x = period_n, y = value)) +
  geom_segment(data = distinct(d, Date, yield_3mo, yield_30yr),
               x = 90, xend = 10958, aes(y = yield_3mo, yend = yield_30yr),
               colour = "grey50") +
  geom_line(size = 1.5, aes(colour = diff303)) +
  scale_y_continuous("Treasury yield curve rate") +
  scale_x_continuous("", breaks = periods[c(10:12), ]$period_n,
                     labels = periods[c(10:12), ]$period) +
  scale_colour_viridis_c("Premium for long term lending:\n30 year yield minus 3 month yield", 
                         option= "A", direction = -1) +
  labs(title = "US Treasury Yield Curve Rates, 1990 to 2019",
       subtitle = 'Date: {frame_time}',
       caption = the_caption) +
  transition_time(Date) 



res <- 100
animate(a2, nframes = length(unique(d2$Date)) * 3, dev = "png", fps = 15,
        type = "cairo-png", antialias = "subpixel", 
        width = 6 * res, height =  4.3 * res, res = res)

anim_save("0151-yield-anim-monthly-latest.gif", path = "../img/")

# convert_pngs("0151")

thankr::shoulders() %>% 
  mutate(maintainer = str_squish(gsub("<.+>", "", maintainer)),
         maintainer = ifelse(maintainer == "R-core", "R Core Team", maintainer)) %>%
  group_by(maintainer) %>%
  summarise(`Number packages` = sum(no_packages),
            packages = paste(packages, collapse = ", ")) %>%
  arrange(desc(`Number packages`)) %>%
  knitr::kable() %>% 
  clipr::write_clip()
