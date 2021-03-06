parameter_ratio <- function(inTable_frem,covdata,pardata,file_format) {
  # as default file format will be png
  if (missing(file_format)) {
    file_format <- c("png")
  }
  # check if there are all 3 input data files
  if (exists("inTable_frem") & exists("covdata") & exists("pardata")) {
    library(grid)
    library(gridExtra)
    library(reshape2)
    library(dplyr)
    library(ggplot2)

    # colnames of frem data
    colnames_frem <- colnames(inTable_frem)
    # names of covariate (names of first column in covdata input table, header = FALSE)
    covariate <- as.character(covdata[[1]])
    
    # delete "LN" prefixes (if they exist) from any of covariates
    for (i in 1:length(covariate)) {
      if (grepl("^LN", covariate[i])) {
        covariate[i] <- gsub("\\LN","",covariate[i])
      }
    }
   
    # number of covariates
    iNumCovs <- length(covariate)

    # round values to reasonable amount of significant figures (4 as maximum)
    for (i in 1:nrow(covdata)) {
      if (covdata$is.categorical[i] == "0") {
        # covdata contains percentiles and means
        covdata[i, 2:5] <- signif(covdata[i, 2:5], digits=4)
      }
    }

    # CREATE VECTOR OF POINT (MEAN) NAMES IN PLOT -----------------------------
    list_v <- list() # for pont names in plot
    list_color <- list() # for point colors in plot
    list_mean <- list() # for text in left side of plot
    list_covariate <- list()

    for (v in 1:nrow(covdata)) {
      if (covdata$is.categorical[v] != "1") {
        r <- rbind(covdata$perc5th[v],covdata$perc95th[v])
        p_color <- rbind("cov5th", "cov95th")
        m <- rbind(paste0(format(signif(covdata$mean[v], digits=2))," ",covdata$unit[v]),"")
        c <- rbind(covariate[v],"")
      } else {
        r <- covdata$category.other[v]
        p_color <- "other"
        m <- covdata$category.reference[v]
        c <- covariate[v]
      }
      list_v[v] <- list(r)
      list_color[v] <- list(p_color)
      list_mean[v] <- list(m)
      list_covariate[v] <- list(c)
    }
    point_names <- as.vector(do.call(rbind,list_v))
    point_color <- as.vector(do.call(rbind,list_color))
    MEAN <- as.vector(do.call(rbind,list_mean))
    COVARIATE <- as.vector(do.call(rbind,list_covariate))

    # SORT NEEDED DATA FOR EACH PARAMETER -------------------------------------
    list_part <- list()
    list_colnames <- list()
    for (j in 1:nrow(pardata)) {
      for (i in 1:length(covariate)) {
        if (covdata$is.categorical[i] != "1") {
          part_5th <- inTable_frem[ , grepl("RATIO.par.", names(inTable_frem)) & grepl(pardata$parname[j], names(inTable_frem)) & grepl("given.cov5th.", names(inTable_frem))  & grepl(covariate[i], names(inTable_frem))]
          name_5th <- paste0(covariate[i],".cov5th")
          part_95th <- inTable_frem[ , grepl("RATIO.par.", names(inTable_frem)) & grepl(pardata$parname[j], names(inTable_frem)) & grepl("given.cov95th.", names(inTable_frem))  & grepl(covariate[i], names(inTable_frem))]
          name_95th <- paste0(covariate[i],".cov95th")
          part <- cbind(part_5th,part_95th)
          name <- cbind(name_5th,name_95th)
          list_part[i] <- list(part)
          list_colnames[i] <- list(name)
        } else {
          part <- inTable_frem[ , grepl("RATIO.par.", names(inTable_frem)) & grepl(pardata$parname[j], names(inTable_frem)) & grepl("given.other.", names(inTable_frem))  & grepl(covariate[i], names(inTable_frem))]
          name <- paste0(covariate[i],".other")
          list_part[i] <- list(part)
          list_colnames[i] <- list(name)
        }
      }
      ColNames <- unlist(list_colnames)
      DF <- do.call(cbind,list_part) # matrix for each parameter
      colnames(DF) <- ColNames
      DF <- as.data.frame(DF) # data frame for each parameter with column names of covariate

      # PREPARE DATA FRAME FOR PLOTTING ----------------------------------------
      # Create long data set
      DF_melt <- melt(DF)

      # summaryze dataframe and calculate mean, quantile for each group (for each column in DF)
      outTable <- DF_melt %>% group_by(variable) %>%
      summarise(mean = value[1],
                ci_low = quantile(value[-1], probs=c(0.05),type=2),
                ci_high = quantile(value[-1], probs=c(0.95),type=2))
      # calculating procentage of outTable
      outTablet_proc <- t(round(t((outTable[, 2:ncol(outTable)])-1) * 100, 2))
      outTable <- cbind(outTable[1],outTablet_proc)
      # add some needed columns for plotting
      outTable$EXPECTED<-sprintf("%+.3G %%  [%+.3G, %+.3G]",outTable$mean,outTable$ci_low,outTable$ci_high)
      outTable$points <- point_names
      outTable$group <- point_color
      outTable$MEAN <- MEAN
      outTable$COVARIATE <- COVARIATE

      # add an empty row to outTable
      empty_row <- c(rep(NA,ncol(outTable)))
      outTable <-rbind(empty_row,outTable)

      outTable$y <- factor(c(1:nrow(outTable)), levels=c(nrow(outTable):1))
      # MAKE FOREST PLOT --------------------------------------------------------
      p <- ggplot(outTable, aes(mean,y)) +
        geom_point(aes(color = group, shape = group),size = 2) +
        geom_text(aes(label = points, color = group),size = 4, vjust = 0, nudge_y = 0.1) +
        geom_errorbarh(aes(xmax = ci_high, xmin = ci_low, color = group, height = 0.15)) +
        geom_vline(xintercept = 0, linetype = "longdash") +
        labs(x = "Effect size in percentage (%)", y="") +
        theme_bw() +
        theme(legend.position = "none",
              panel.border = element_rect(),
              axis.title = element_text(size = 14),
              axis.text = element_text(size = 12),
              axis.line = element_line(),
              axis.ticks = element_blank(),
              axis.text.y = element_blank(),
              plot.margin = unit(c(1,0.1,1,1), "cm"))
      if ((2 %in% c(1:ncol(pardata))) & (3 %in% c(1:ncol(pardata)))) {
        if ((is.na(pardata[j,2]) == FALSE) & (is.na(pardata[j,3]) == FALSE)) {
          p <- p + coord_cartesian(xlim = c(pardata[j,2],pardata[j,3]))
        }
      }

      # create table with all needed information
      outTable <- outTable[-1,]
      outTable_text <- data.frame()
      V1 <- c(colnames(outTable)[9], outTable$COVARIATE, colnames(outTable)[8],outTable$MEAN, colnames(outTable)[5], outTable$EXPECTED)
      V05 <- rep(c(1:3),each = (nrow(outTable) +1) )
      outTable_text <- data.frame(V1,V05,V0 = factor(rep(c(1:(nrow(outTable) +1)),3),levels = c((nrow(outTable) +1):1)))

      # create plot of text table
      data_table <- ggplot(outTable_text,aes(x = V05, y = V0, label = format(V1, nsmall = 1))) +
        geom_text(size = 4, hjust = 0, vjust = 0.2) + theme_bw() +
        geom_hline(aes(yintercept = c(nrow(outTable) + 0.5))) +
        theme(panel.grid.major = element_blank(),
              panel.border = element_blank(),
              legend.position = "none",
              axis.text.x = element_text(size = 12, colour = "white"),
              axis.text.y = element_blank(),
              axis.ticks = element_blank(),
              plot.margin = unit(c(1,1,1,0), "cm")) +
        labs(x="",y="") +
        coord_cartesian(xlim = c(1,5))

      # Create title in the plot
      if (4 %in% c(1:ncol(pardata))) {
        if (is.na(pardata[j,4]) == TRUE) {
          title <- paste0("Covariate effects on parameter ",pardata$parname[j])
        } else {
          title <- paste0(pardata[j,4])
        }
      } else {
        title <- paste0("Covariate effects on parameter ",pardata$parname[j])
      }

      # print out forest plot with table text
      gp <- grid.arrange(p, data_table, ncol=2, top = textGrob(title,gp=gpar(fontsize=20)))

      # Save each plot with different names in different pdg files (based on each parameter j)
      name <- paste0(pardata$parname[j],".",file_format)
      ggsave(filename = name, plot = gp, width=11.69, height=8.27)
      dev.off()
    }
  } else {
    cat("Input data files are not found! Make sore that input data files are in your working directory!")
  }
}

