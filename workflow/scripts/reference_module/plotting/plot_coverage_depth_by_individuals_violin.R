#!/usr/bin/env Rscript

suppressPackageStartupMessages({
library(ggplot2)
library(dplyr)
library(readr)
library(stringr)
library(scales)
})

# Access Snakemake variables
input_file <- snakemake@input[[1]]
output_file <- snakemake@output[[1]]
species <- snakemake@params[["species"]]

# Read CSV
df <- read_csv(input_file)
if (nrow(df) == 0) stop("Input file is empty.")

# Extract individual
df <- df %>%
  mutate(individual = str_split(Filename, "_", simplify = TRUE)[,1])

violin_plot <- ggplot(df, aes(x = factor(individual), y = avg_depth)) +
  scale_y_continuous(
    trans = "log10",
    breaks = trans_breaks("log10", function(x) 10^x),
    labels = comma
  ) +
  geom_violin(scale = "width", trim = TRUE, fill = "grey30") +
  theme_bw() +
  ylab("Avg. Depth (log10)") +
  xlab("Individual") +
  ggtitle(paste0("Per-Scaffold Average Depth: ", species)) +
  theme(axis.text.x = element_text(size = 12, angle = 45, vjust = 1, hjust = 1),
        axis.text.y = element_text(size = 12),
        axis.title.x = element_text(size = 12, face = "bold"),
        axis.title.y = element_text(size = 12, face = "bold"),
        plot.title = element_text(size = 14, hjust = 0.5),
        panel.grid.major = element_blank(),
        panel.grid.minor = element_blank(),
        panel.background = element_rect(fill = "white", colour = "black"))
ggsave(output_file, plot = violin_plot, width = 12, height = 6, dpi = 300)
