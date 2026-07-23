#!/usr/bin/env Rscript

suppressPackageStartupMessages({
library(ggplot2)
library(dplyr)
library(readr)
library(stringr)
})

species <- snakemake@params[["species"]]
input_file <- snakemake@input[[1]]
output_file <- snakemake@output[[1]]

df <- read_csv(input_file)
if (nrow(df) == 0) stop("Input file is empty.")

df <- df %>%
  mutate(individual = str_split(Filename, "_", simplify = TRUE)[,1])

# Bar plot function: weighted overall percent covered
df_summary <- df %>%
  group_by(individual) %>%
  summarise(
    total_covered = sum(covered_bases, na.rm = TRUE),
    total_bases = sum(total_bases, na.rm = TRUE),
    overall_percent_covered = ifelse(total_bases > 0, 100 * total_covered / total_bases, 0),
    .groups = "drop"
  )

bar_plot <- ggplot(df_summary, aes(x = reorder(individual, -overall_percent_covered),
                                   y = overall_percent_covered)) +
  geom_bar(stat = "identity", fill = "grey30") +
  scale_y_continuous(limits = c(0, 100), breaks = seq(0, 100, 20)) +
  theme_bw() +
  ylab("Overall coverage [%]") +
  xlab("Individual") +
  ggtitle(paste0("Overall Breadth of Coverage [%]: ", species)) +
  theme(axis.text.x = element_text(size = 12, angle = 45, hjust = 1),
        axis.text.y = element_text(size = 12),
        axis.title.x = element_text(size = 12, face = "bold"),
        axis.title.y = element_text(size = 12, face = "bold"),
        plot.title = element_text(size = 14, hjust = 0.5),
        legend.position = "none")

ggsave(output_file, plot = bar_plot, width = 12, height = 6, dpi = 300)
