#!/usr/bin/env Rscript

suppressPackageStartupMessages({
library(dplyr)
library(ggplot2)
library(tidyr)
library(scales)
library(stringr)
})

plot_combined_reads <- function(processing_csv, endogenous_csv, output_plot) {

  # 1. Load and process read processing results
  df_proc <- read.csv(processing_csv, header = TRUE) 
  
  # Group and summarise the three distinct filtering steps
  df_proc <- df_proc %>%
    group_by(individual) %>%
    summarise(
      raw_count_absolute = sum(raw_count),
      # Keeping adapter removed and quality filtered reads as separate metrics
      adapter_removed_count_absolute = sum(adapter_removed_count), 
      quality_filtered_count_absolute = sum(quality_filtered_count),
      .groups = "drop"
    )

  # 2. Load and process endogenous reads (CSV)
  # Uses the lowercase 'individual' and 'mapped_reads' columns for consistent joining.
  df_endo <- read.csv(endogenous_csv, header = TRUE) %>%
    select(individual = individual, endogenous_reads_absolute = mapped_reads)

  # 3. Merge the dataframes
  combined_df <- inner_join(df_proc, df_endo, by = "individual")
  
  # Check if the merge resulted in an empty dataframe
  if (nrow(combined_df) == 0) {
      stop("The combined plot data is empty! Check if the 'individual' IDs in your processing file (e.g., Dmel01) exactly match the 'individual' IDs in your endogenous file.")
  }

  # 4. Reshape and plot preparation
  plot_df <- combined_df %>%
    pivot_longer(
      # Pivot all four steps for visualization
      cols = c(raw_count_absolute, adapter_removed_count_absolute, quality_filtered_count_absolute, endogenous_reads_absolute),
      names_to = "read_type",
      values_to = "count"
    ) %>%
    mutate(
      read_type = case_match(
        read_type,
        "raw_count_absolute" ~ "Raw Reads",
        "adapter_removed_count_absolute" ~ "Trimmed Reads", # NEW LABEL
        "quality_filtered_count_absolute" ~ "Filtered Reads", # NEW LABEL
        "endogenous_reads_absolute" ~ "Endogenous Reads",
        .default = read_type
      ),
      # Update factor levels for the new four-bar structure
      read_type = factor(read_type,
                         levels = c("Raw Reads",
                                    "Trimmed Reads",
                                    "Filtered Reads",
                                    "Endogenous Reads"))
    )

  # 5. Create the plot
  # Added a fourth color for the new read type
  p <- ggplot(plot_df, aes(x = individual, y = count, fill = read_type)) +
    geom_bar(stat = "identity", position = position_dodge(preserve = "single"),
         colour = "black", linewidth = 0.3) +
    scale_fill_manual(values = c("Raw Reads" = "white",
                             "Trimmed Reads" = "grey70",
                             "Filtered Reads" = "grey50",
                             "Endogenous Reads" = "grey30")) +
    scale_y_continuous(labels = comma) +
    labs(x = "Individual",
         y = "Read Count",
         fill = NULL,
         title = "Reads Across Processing and Alignment Steps") +
    theme_bw() +
    theme(panel.grid.major = element_line(color = "grey90"),
          panel.grid.minor = element_blank(),
          axis.text.x = element_text(size = 12, angle = 45, vjust = 1, hjust = 1),
          axis.title.x = element_text(size = 12, face = "bold"),
          axis.title.y = element_text(size = 12, face = "bold"),
          plot.title = element_text(size = 14, hjust = 0.5),
          legend.position = "bottom")

  # 6. Save the plot
  ggsave(output_plot, plot = p, width = 9, height = 6, dpi = 300)
}

if (exists("snakemake")) {
 plot_combined_reads(
   processing_csv = snakemake@input[["processing_results"]], 
   endogenous_csv = snakemake@input[["endogenous_results"]], 
   output_plot = snakemake@output[["plot"]]
 )
}