#!/usr/bin/env Rscript

suppressPackageStartupMessages({
library(ggplot2)
library(dplyr)
library(readr)
})

plot_coverage_breadth_bins <- function(df, output_file) {
  
  bins <- c(0, 100000, 250000, 500000, 1000000, 2500000, 5000000, 10000000, 20000000, Inf)
  bin_labels <- c('0-100k', '100k-250k', '250k-500k', '500k-1M', '1M-2.5M', '2.5M-5M', '5M-10M', '10M-20M', '20M+')
  
  df$length_bin <- cut(df$total_bases, breaks = bins, labels = bin_labels, right = FALSE)
  
  avg_coverage_by_bin <- df %>%
    group_by(length_bin) %>%
    summarise(
      avg_coverage = mean(percent_covered, na.rm = TRUE),
      scaffold_count = n(),
      std_dev = sd(percent_covered, na.rm = TRUE)
    )
  
  plot <- ggplot(avg_coverage_by_bin, aes(x = length_bin, y = avg_coverage, group = 1)) +
    geom_bar(stat = "identity", fill = "skyblue", color = "black") +
    geom_errorbar(aes(ymin = avg_coverage - std_dev, ymax = avg_coverage + std_dev), width = 0.2, color = "black") +
    labs(x = "Scaffold Length Bin", y = "Average Percent Covered", title = "Average Coverage by Scaffold Length Bin") +
    theme_bw() +
    theme(axis.text.x = element_text(angle = 45, hjust = 1))
  
  dir.create(dirname(output_file), recursive = TRUE, showWarnings = FALSE)
  ggsave(output_file, plot = plot, width = 10, height = 6)
  cat("✅ Saved:", output_file, "\n")
}

# Snakemake integration
if (exists("snakemake")) {
  input_file <- snakemake@input[[1]]
  output_file <- snakemake@output[[1]]
  
  df <- read.csv(input_file, header = TRUE)
  plot_coverage_breadth_bins(df, output_file)
}
