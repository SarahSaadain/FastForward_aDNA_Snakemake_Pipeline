library(ggplot2)
library(dplyr)
library(tidyr)

# ─────────────────────────────────────────────────────────────────────────────
# Output
# ─────────────────────────────────────────────────────────────────────────────

args <- commandArgs(trailingOnly = TRUE)
output_dir <- if (length(args) >= 1) args[1] else "scg_plots"
dir.create(output_dir, showWarnings = FALSE, recursive = TRUE)

# ─────────────────────────────────────────────────────────────────────────────
# Scoring parameters (must match determine_scg_ranking.py)
# ─────────────────────────────────────────────────────────────────────────────

depth_variance_decay    <- 0.15
depth_consistency_decay <- 0.25

# ─────────────────────────────────────────────────────────────────────────────
# Component 1: Breadth
# score_breadth = mean_breadth  (identity — breadth is already 0–1)
# ─────────────────────────────────────────────────────────────────────────────

breadth_df <- tibble(
  breadth = seq(0, 1, length.out = 500),
  score   = breadth
)

p_breadth <- ggplot(breadth_df, aes(x = breadth, y = score)) +
  geom_line(colour = "#2196F3", linewidth = 1.2) +
  scale_x_continuous(labels = scales::percent_format(), breaks = seq(0, 1, 0.2)) +
  scale_y_continuous(limits = c(0, 1), breaks = seq(0, 1, 0.2)) +
  labs(
    title    = "Score: Breadth of Coverage",
    subtitle = "score_breadth = mean_breadth",
    x        = "Mean breadth across samples",
    y        = "Score contribution"
  ) +
  theme_minimal(base_size = 12) +
  theme_bw() +
  theme(
    panel.grid.minor = element_blank(),
    plot.title       = element_text(face = "bold"),
    plot.subtitle    = element_text(colour = "grey40", family = "mono", size = 9)
  )

# ─────────────────────────────────────────────────────────────────────────────
# Component 2: Depth Variation
# score_depth_variation = exp(-max_variation * 0.3)
# max_variation = max_depth / mean_median_depth
# ─────────────────────────────────────────────────────────────────────────────

variation_df <- tibble(
  max_variation = seq(0, 30, length.out = 500),
  score         = exp(-max_variation * depth_variance_decay)
)

# Annotate a few reference points
variation_refs <- tibble(
  max_variation = c(1, 5, 10, 20),
  score         = exp(-c(1, 5, 10, 20) * depth_variance_decay),
  label         = paste0("x=", c(1, 5, 10, 20))
)

p_variation <- ggplot(variation_df, aes(x = max_variation, y = score)) +
  geom_line(colour = "#4CAF50", linewidth = 1.2) +
  geom_point(data = variation_refs, size = 3, colour = "#4CAF50") +
  geom_text(data = variation_refs, aes(label = label),
            nudge_y = 0.04, nudge_x = 0.3, size = 3.2, colour = "grey30") +
  scale_y_continuous(limits = c(0, 1), breaks = seq(0, 1, 0.2)) +
  scale_x_continuous(breaks = seq(0, 30, 5)) +
  labs(
    title    = "Score: Depth Variation",
    subtitle = paste0("score_depth_variation = exp(-max_variation \u00d7 ", depth_variance_decay, ")"),
    x        = "max_variation  (max_depth / mean_median_depth)",
    y        = "Score contribution"
  ) +
  theme_minimal(base_size = 12) +
  theme_bw() +
  theme(
    panel.grid.minor = element_blank(),
    plot.title       = element_text(face = "bold"),
    plot.subtitle    = element_text(colour = "grey40", family = "mono", size = 9)
  )

# ─────────────────────────────────────────────────────────────────────────────
# Component 3: Depth Consistency
# depth_deviation = |median_depth_scg - global_median| / (global_MAD + eps)
# score_depth_consistency = exp(-depth_deviation / 3)
# ─────────────────────────────────────────────────────────────────────────────

consistency_df <- tibble(
  depth_deviation = seq(0, 20, length.out = 500),
  score           = exp(-depth_deviation * depth_consistency_decay)
)

consistency_refs <- tibble(
  depth_deviation = c(1, 3, 6, 12),
  score           = exp(-c(1, 3, 6, 12) * depth_consistency_decay),
  label           = paste0("dev=", c(1, 3, 6, 12))
)

p_consistency <- ggplot(consistency_df, aes(x = depth_deviation, y = score)) +
  geom_line(colour = "#FF9800", linewidth = 1.2) +
  geom_point(data = consistency_refs, size = 3, colour = "#FF9800") +
  geom_text(data = consistency_refs, aes(label = label),
            nudge_y = 0.04, nudge_x = 0.2, size = 3.2, colour = "grey30") +
  scale_y_continuous(limits = c(0, 1), breaks = seq(0, 1, 0.2)) +
  scale_x_continuous(breaks = seq(0, 20, 2)) +
  labs(
    title    = "Score: Depth Consistency",
    subtitle = paste0("score_depth_consistency = exp(-depth_deviation * ", depth_consistency_decay, ")"),
    x        = "depth_deviation  (MAD-normalised distance from global median)",
    y        = "Score contribution"
  ) +
  theme_minimal(base_size = 12) +
  theme_bw() +
  theme(
    panel.grid.minor = element_blank(),
    plot.title       = element_text(face = "bold"),
    plot.subtitle    = element_text(colour = "grey40", family = "mono", size = 9)
  )

# ─────────────────────────────────────────────────────────────────────────────
# Save individual plots
# ─────────────────────────────────────────────────────────────────────────────

ggsave(file.path(output_dir, "curve_breadth.png"),      p_breadth,      width = 7, height = 5, dpi = 150)
ggsave(file.path(output_dir, "curve_depth_variation.png"),   p_variation,    width = 7, height = 5, dpi = 150)
ggsave(file.path(output_dir, "curve_depth_consistency.png"), p_consistency,  width = 7, height = 5, dpi = 150)

