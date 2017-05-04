library(ggplot2)
library(readr)
library(reshape2)
library(dplyr, warn.conflicts=FALSE)
library(gridExtra)
library(scales)

open_data <- function(fname, nt, compiler, device, acc, every=1) {
    path <- "../results/"
    data <- read_csv(paste(path,fname,sep=""), col_names=TRUE)
    data <- data[seq(1, nrow(data), every),]
    data$imgrange <- 100*((data$talpha)/(5-(-5))*64) # [-5,5]^2 -> {dimx, dimy}^2, dimx=dimy,  

    ## melt values of columns Testxxx to $variable
    data <- melt(data,
                 id.vars=c('Width','Height','talpha','imgrange'),
                 measure.vars=paste('Test', 0:(nt-1), sep=""))
    data$compiler <- compiler
    data$device <- device
    data$accelerated <- acc
    data$bw <- data$Width*data$Height*4*64*2/data$value*1000*1e-9 # GB/s to compute velocity field / density
    data$dimension <- as.factor(paste(data$Width,data$Height,sep='x'))
    data$platform <- with(data, paste(device," (",compiler,")",sep=""))
    return(data)
}

nt<-20 # number tests

color_cpu<-"#3487D7"
color_gpu<-"#AE449D"
color_cuda<-"#FF2211"
color_cpus<-"#0EA000"

data_k80 <- open_data('512x512_it64_r20_pgi_k80.csv', nt, 'pgi-17.1', '1xK80', 'with acceleration')
data_multicore <- open_data('512x512_it64_r20_pgi_haswell_24core.csv', nt, 'pgi-17.1', '24xCPU', 'with acceleration')
data_singlecore <- open_data('512x512_it64_r20_pgi_haswell_1core.csv', nt, 'pgi-17.1', '1xCPU', 'without acceleration')
#data_gcc <- open_data('512x512_it64_r20_gcc5_haswell_1core.csv', nt, 'gcc-5.3', '1xCPU', 'without acceleration')
#data_cuda_k80 <- open_data('512x512_it64_r20_cuda_k80.csv', nt, 'cuda-8', '1xK80', 'with acceleration', every=1)
#
data_df <- 
#    data_gcc %>%
    data_singlecore %>%
#    bind_rows(data_cuda_k80) %>%
    bind_rows(data_k80) %>%
    bind_rows(data_multicore)
cat("total rows collected: \t",nrow(data_df),"\n")

data_k80_atomic <- open_data('512x512_it64_r20_pgi_k80_atomic.csv', nt, 'pgi-17.1', '1xK80', 'with acceleration & atomics')
data_multicore_atomic <- open_data('512x512_it64_r20_pgi_haswell_24core_atomic.csv', nt, 'pgi-17.1', '24xCPU', 'with acceleration & atomics')
data_df_atomic <- data_multicore %>%
    bind_rows(data_k80) %>%
    bind_rows(data_k80_atomic) %>%
    bind_rows(data_multicore_atomic)


cols_to_grp_by <- lapply(c("Width","dimension","compiler","device","platform", "accelerated","talpha","imgrange"), as.symbol)


my_theme <-  theme_bw() + theme(axis.title.x = element_text(size=19),
                                axis.title.y = element_text(size=19),
                                axis.text.x = element_text(size=16),
                                axis.text.y = element_text(size=16),
                                plot.title = element_text(color="black",face="bold",size=18, hjust=0.5,vjust=1),
                                panel.grid.major = element_line(colour="#777777", size=0.5, linetype=3),
                                panel.grid.minor = element_line(colour="#888888", size=0.5, linetype=3),
                                strip.text.x = element_text(size = 14, face="bold" )
                                )
my_theme <- my_theme + theme(legend.title = element_text(size=16, face="bold"),
                             legend.text = element_text( size = 14),
                             legend.position="bottom",
                             legend.direction="vertical",
                             legend.box ="horizontal",
                             legend.box.just ="top",
                             legend.background = element_rect(colour = 'white', fill = 'white', size = 0., linetype='dashed'),
                             legend.key = element_rect(colour = 'white', fill = 'white', size = 0., linetype='dashed'),
                             legend.key.width = unit(1.1, "cm")
                             )





data_alpha <- data_df %>% filter(talpha %in% c(0,0.2))
dta <- data_alpha %>%
    group_by_(.dots = cols_to_grp_by) %>%
    summarize(moi_mean = mean(value),
              moi_median = median(value),
              moi_stddev = sd(value)
              )

dtatmp <- filter(dta, accelerated=="with acceleration");
dtatmp$accelerated <- "without acceleration"
dta <- dta %>% bind_rows(dtatmp)

acc_names1 <- c(
    'with acceleration'="GPU + Multi-CPU",
    'without acceleration'="Single-CPU + GPU + Multi-CPU"
    )

barplot <- ggplot(dta, aes(x=factor(imgrange), y=moi_mean, fill=platform)) + my_theme
barplot <- barplot + geom_bar(stat = "identity", position = position_dodge(width=0.9))
barplot <- barplot + geom_errorbar(aes(ymin = moi_mean-moi_stddev,
                                       ymax = moi_mean+moi_stddev),
                                   position = position_dodge(width=0.9),
                                   width = 0.25)
barplot <- barplot + facet_wrap(~accelerated, scales="free", labeller=labeller(accelerated = acc_names1))
barplot <- barplot + labs(x="Orbit length in % of image width", y="Runtime in ms")
barplot <- barplot + ggtitle("Popcorn2D 512x512 - Comparison of average runtimes")
barplot <- barplot + guides(fill=guide_legend(ncol=2,reverse=TRUE) )
barplot <- barplot + scale_fill_manual(values=c(color_cpu, color_gpu, color_cpus))


## boxplot <- ggplot(data_alpha, aes(x=factor(talpha),fill=device)) + my_theme
## boxplot <- boxplot + geom_boxplot(aes(y=value))
## boxplot <- boxplot + ylab('Runtime in ms')
## boxplot <- boxplot + facet_wrap(~accelerated, scales = "free")

data_for_plotting <- data_df %>%
    group_by_(.dots = cols_to_grp_by) %>%
    summarize(moi_mean = mean(value),
              moi_median = median(value),
              moi_stddev = sd(value)
              )
acc_names2 <- c(
    'with acceleration'="GPU + Multi-CPU",
    'without acceleration'="Single-CPU"
    )

## to enlarge data window
## dummy <- data.frame(imgrange = c(0,200), value = c(256,768),
##                     compiler=rep("pgi-17.1",2), device=rep("1xCPU",2),
##                     accelerated = rep("without acceleration",2))

lineplot <- ggplot(data_for_plotting, aes(x=imgrange, color=platform)) + my_theme
lineplot <- lineplot + scale_y_continuous(trans=log_trans(base=2), breaks=c(1,2,5,10,20,50,100,200,1500,1600,1700,1800,1900,2000,2100), minor_breaks=c(as.vector(outer(seq(1,9), c(1,10,200), function(x,y) x*y))))
##lineplot <- lineplot + scale_x_continuous(trans=log_trans(base=10))
lineplot <- lineplot + facet_wrap(~accelerated, scales="free", labeller=labeller(accelerated = acc_names2))
lineplot <- lineplot + geom_line(aes(y=moi_mean),size=0.8)
lineplot <- lineplot + geom_errorbar(aes(ymin = moi_mean - moi_stddev,
                                         ymax = moi_mean + moi_stddev),
                                     width=0.004, ,size=.4, linetype =1)
## lineplot <- lineplot + geom_blank(data=dummy,aes(y=value))
lineplot <- lineplot + xlab('Orbit length in % of image width')
lineplot <- lineplot + ylab('Runtime in ms')
lineplot <- lineplot + ggtitle("Popcorn2D 512x512 - Comparison of average runtimes")
lineplot <- lineplot + scale_color_manual(values=c(color_cpu, color_gpu, color_cpus))

pointplot <- ggplot(data_for_plotting, aes(x=imgrange, color=platform)) + my_theme
pointplot <- pointplot + scale_y_continuous(trans=log_trans(base=2), breaks=c(1,2,5,10,20,50,100,200,1500,1600,1700,1800,1900,2000,2100), minor_breaks=c(as.vector(outer(seq(1,9), c(1,10,200), function(x,y) x*y))))
pointplot <- pointplot + geom_point(aes(y=moi_mean),size=0.5,alpha=0.9)
pointplot <- pointplot + facet_wrap(~accelerated, scales="free")
pointplot <- pointplot + xlab('Orbit length in % of image width')
pointplot <- pointplot + ylab('Runtime in ms')
pointplot <- pointplot + ggtitle("Popcorn2D 512x512 - Comparison of runtimes")
pointplot <- pointplot + guides(colour = guide_legend(override.aes = list(alpha = 1, size=1)))
pointplot <- pointplot + scale_color_manual(values=c(color_cpu, color_gpu, color_cpus))

data_cuda_k80_d <- open_data('512x512_it64_r20_cuda_k80.csv', nt, 'cuda-8', '1xK80', 'with acceleration')
data_k80_d <- open_data('512x512_it64_r20_pgi_k80.csv', nt, 'pgi-17.1', '1xK80', 'with acceleration')
data_k80_df_d <- data_cuda_k80_d %>%    
    bind_rows(data_k80_d) %>%
    filter(imgrange<100)

pointplot_k80 <- ggplot(data_k80_df_d, aes(x=imgrange,y=value,color=compiler)) + my_theme
pointplot_k80 <- pointplot_k80 + geom_point(size=0.75,alpha=0.4)
## pointplot_k80 <- pointplot_k80 + scale_y_continuous(trans=log_trans(base=2))
## pointplot_k80 <- pointplot_k80 + scale_x_continuous(trans=log_trans(base=2))
pointplot_k80 <- pointplot_k80 + xlab('Orbit length in % of image width')
pointplot_k80 <- pointplot_k80 + ylab("Runtime in ms") + ggtitle("Popcorn2D 512x512 - Comparison of runtimes")
pointplot_k80 <- pointplot_k80 + guides(colour = guide_legend(override.aes = list(alpha = 1, size=1.5)))
pointplot_k80 <- pointplot_k80 + scale_color_manual(values=c(color_cuda, color_gpu))


lineplot_k80 <- ggplot(data_k80_df_d, aes(x=imgrange, y=value, color=compiler)) + my_theme
## lineplot_k80 <- lineplot_k80 + scale_y_continuous(trans=log_trans(base=10))
## lineplot_k80 <- lineplot_k80 + scale_x_continuous(trans=log_trans(base=10))
lineplot_k80 <- lineplot_k80 + stat_summary(fun.y="mean", geom="line", size=1)
lineplot_k80 <- lineplot_k80 + stat_summary(geom="errorbar",
                                            position=position_dodge(0.95), width=.05,
                                            fun.data = function(x){ return(c(y=mean(x), ymin=mean(x)-sd(x), ymax=mean(x)+sd(x))) })
## lineplot_k80 <- lineplot_k80 + geom_line(aes(y=moi_mean),size=0.8)
## lineplot_k80 <- lineplot_k80 + geom_errorbar(aes(ymin = moi_mean - moi_stddev,
##                                                  ymax = moi_mean + moi_stddev),
##                                              width=0.004, ,size=.4, linetype =1)
lineplot_k80 <- lineplot_k80 + ylab('Runtime in ms')
lineplot_k80 <- lineplot_k80 + xlab('Orbit lenght in % of image width')
lineplot_k80 <- lineplot_k80 + ggtitle("Popcorn2D 512x512 - Comparison of runtimes")
lineplot_k80 <- lineplot_k80 + scale_color_manual(values=c(color_cuda, color_gpu))
#lineplot_k80 <- lineplot_k80 + guides(fill=guide_legend(ncol=2,reverse=TRUE) )


data_for_plotting <- data_df_atomic %>%
    group_by_(.dots = cols_to_grp_by) %>%
    summarize(moi_mean = mean(value),
              moi_median = median(value),
              moi_stddev = sd(value)
              )

acc_names3 <- c(
    'with acceleration'="without atomics",
    'with acceleration & atomics'="with atomics"
    )

lineplot_atomic <- ggplot(data_for_plotting, aes(x=imgrange, color=platform)) + my_theme
lineplot_atomic <- lineplot_atomic + scale_y_continuous(trans=log_trans(base=10))#, breaks=c(1,2,5,10,20,50,100,200,1700,1800,1900,2000,2100), minor_breaks=c(as.vector(outer(seq(1,9), c(1,10,200), function(x,y) x*y))))
##lineplot_atomic <- lineplot_atomic + scale_x_continuous(trans=log_trans(base=10))
lineplot_atomic <- lineplot_atomic + facet_wrap(~accelerated, scales="free", labeller=labeller(accelerated = acc_names3))
lineplot_atomic <- lineplot_atomic + geom_line(aes(y=moi_mean),size=0.8)
## lineplot_atomic <- lineplot_atomic + geom_errorbar(aes(ymin = moi_mean - moi_stddev,
##                                          ymax = moi_mean + moi_stddev),
##                                      width=0.004, ,size=.4, linetype =1)
## lineplot_atomic <- lineplot_atomic + geom_blank(data=dummy,aes(y=value))
lineplot_atomic <- lineplot_atomic + xlab('Orbit length in % of image width')
lineplot_atomic <- lineplot_atomic + ylab('Runtime in ms')
lineplot_atomic <- lineplot_atomic + ggtitle("Popcorn2D 512x512 - Comparison of average runtimes")
lineplot_atomic <- lineplot_atomic + scale_color_manual(values=c(color_gpu, color_cpu))

## save plots to file, width and height are 7 inches by default
ggsave("barplot.png",barplot, width=10, height=7)
ggsave("lineplot.png",lineplot, width=10, height=7)
ggsave("lineplot_atomic.png",lineplot_atomic, width=10, height=7)
ggsave("pointplot.png",pointplot, width=10, height=7)
## ggsave("pointplot_k80.png",pointplot_k80)

## ## ggsave("boxplot.png",boxplot)
ggsave("lineplot_k80.png",lineplot_k80, width=10, height=7)
