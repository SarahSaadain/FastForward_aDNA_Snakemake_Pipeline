#!/usr/bin/env Rscript

suppressPackageStartupMessages({
library(dplyr)
library(ggplot2)
library(tidyr)
library(scales)
})


plot_by_individual <- function(df, species, target_file) {

  file_path <- file.path(target_file)
  
  df_individual <- df %>%
    group_by(individual) %>%
    summarise(
      raw_count_absolute = sum(raw_count),
      adapter_removed_count_absolute = sum(adapter_removed_count),
      quality_filtered_count_absolute = sum(quality_filtered_count),
      .groups = "drop"
    ) %>%

    pivot_longer(cols = c(raw_count_absolute, adapter_removed_count_absolute, quality_filtered_count_absolute),
                 names_to = "read_type", values_to = "count") %>%

    mutate(read_type = factor(read_type,
                              levels = c("raw_count_absolute",
                                         "adapter_removed_count_absolute",
                                         "quality_filtered_count_absolute")))

  p <- ggplot(df_individual, aes(x = individual, y = count, fill = read_type)) +
    geom_bar(stat = "identity", position = position_dodge(preserve = "single"),
             colour = "black") +
    scale_fill_manual(
      name = NULL,
      values = c("raw_count_absolute" = "white",
                 "adapter_removed_count_absolute" = "grey70",
                 "quality_filtered_count_absolute" = "grey30"),
      labels = c("raw_count_absolute" = "Raw Reads",
                 "adapter_removed_count_absolute" = "Adapter Removed",
                 "quality_filtered_count_absolute" = "Quality Filtered")
    ) +
    scale_y_continuous(labels = comma) +
    labs(x = "Individual", y = "Read Count", title = "Read Counts by Individual") +
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
  plot_by_individual(df, species, target_file)
}

# Snakemake integration
plot_compare_reads_before_after_processing(
  snakemake@wildcards$species,
  snakemake@input[[1]],
  snakemake@output[[1]]
)
