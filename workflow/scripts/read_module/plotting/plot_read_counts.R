#!/usr/bin/env Rscript

suppressPackageStartupMessages({
library(dplyr)
library(ggplot2)
library(tidyr)
library(scales)
})

plot_read_counts <- function(df, species, target_file) {
  file_path <- file.path(target_file)

  df_sum <- df %>%
    summarise(
      raw_count = sum(raw_count, na.rm = TRUE),
      adapter_removed_count = sum(adapter_removed_count, na.rm = TRUE),
      quality_filtered_count = sum(quality_filtered_count, na.rm = TRUE)
    )

  df_long <- df_sum %>%
    pivot_longer(cols = everything(),
                 names_to = "read_type", values_to = "count") %>%
    mutate(read_type = factor(read_type,
                              levels = c("raw_count",
                                         "adapter_removed_count",
                                         "quality_filtered_count")))

  p <- ggplot(df_long, aes(x = species, y = count, fill = read_type)) +
    geom_bar(stat = "identity", position = position_dodge(preserve = "single"),
             colour = "black") +
    scale_fill_manual(
      name = NULL,
      values = c("raw_count" = "white",
                 "adapter_removed_count" = "grey70",
                 "quality_filtered_count" = "grey30"),
      labels = c("raw_count" = "Raw Reads",
                 "adapter_removed_count" = "Adapter Removed",
                 "quality_filtered_count" = "Quality Filtered")
    ) +
    scale_y_continuous(labels = scales::comma) +
    labs(x = "Species", y = "Read Count (summed)", title = "Read Counts by Species") +
    theme_bw() +
    theme(axis.text.x = element_text(size = 12, angle = 45, vjust = 1, hjust = 1),
          axis.text.y = element_text(size = 12),
          axis.title.x = element_text(size = 14, face = "bold"),
          axis.title.y = element_text(size = 14, face = "bold"),
          plot.title = element_text(size = 14, hjust = 0.5),
          legend.position = "bottom",
          panel.grid.major = element_blank(),
          panel.grid.minor = element_blank(),
          panel.background = element_rect(fill = "white", colour = "black"))

  ggsave(file_path, plot = p, width = 8, height = 5, dpi = 300)
}

plot_compare_reads_before_after_processing <- function(species, source_file, target_file) {
  df <- read.csv(source_file, header = TRUE)
  plot_read_counts(df, species, target_file)
}

# Snakemake integration
plot_compare_reads_before_after_processing(
  snakemake@wildcards$species,
  snakemake@input[[1]],
  snakemake@output[[1]]
)
