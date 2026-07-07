# ggplot (gg) — plotnine compatibility matrix

Status of the `ggplot` system against plotnine's public API and gallery.
SSIM scores are `make gg-compare-png` results against plotnine 0.13.6
references at 640x480/dpi 100 (threshold 0.90; `allowlist-gg.json` carries
justified exceptions). Updated: 2026-07-06.

## Example twins (reference_scripts/gg + examples/gg)

| example | SSIM | status |
|---|---|---|
| ggblank | 0.951 | pass |
| gg-scatter-basic | 0.950 | pass |
| gg-bar-flip | 0.942 | pass |
| gg-bar-basic | 0.926 | pass |
| gg-line-basic | 0.921 | pass |
| gg-area-stacked | 0.904 | pass |
| gg-scatter-color | 0.878 | legend geometry |
| gg-bar-stacked | 0.876 | legend geometry |
| gg-facet-wrap | 0.872 | strip/tick detail |
| gg-smooth-lm | 0.868 | ribbon AA detail |
| gg-density | 0.858 | curve detail |
| gg-bar-dodge | 0.843 | legend geometry |
| gg-violin | 0.842 | outline detail |
| gg-histogram | 0.842 | bin edge detail |
| gg-boxplot | 0.831 | whisker/median weight |
| gg-tile-heatmap | 0.764 | colorbar tick/label detail |

Earlier scores were dragged 0.03-0.10 per plot by two backend-side bugs,
both fixed: a black frame drawn because spine visibility used the wrong
key type, and minor tick MARKS drawn outside the panel (plotnine draws
only minor gridlines). Glyph rasterization itself matches matplotlib's
almost exactly (ink ratio 1.016, aligned cosine 0.987 on identical
strings). The remaining spread is per-plot geometry detail, chiefly
legend-box layout.

## plotnine API surface

### geoms
| implemented (24) | planned | blocked |
|---|---|---|
| blank point line path bar col histogram freqpoly area ribbon density boxplot violin smooth tile raster text label segment hline vline rect step rug linerange errorbar pointrange qq | abline crossbar count jitter(alias) dotplot bin2d density-2d quantile sina spoke pointdensity | map (no geospatial backend) |

### stats
| implemented (11) | planned |
|---|---|
| identity count bin density boxplot ydensity smooth(lm/loess) ecdf qq | bin-2d function summary sina quantile |

### positions
All: identity stack fill dodge jitter nudge. (dodge2/jitterdodge planned.)

### scales
| implemented | planned | notes |
|---|---|---|
| x/y continuous + discrete, x/y log10, color/fill discrete (HLS = plotnine default), manual, gradient, grey; shape manual; size (area palette); alpha; xlim/ylim/lims; expand-limits | sqrt/reverse/date/datetime; brewer/cmap/gradient2/gradientn; identity scales | log10 transforms data + integer-exponent ticks, like plotnine |

### coords / facets
- coord-cartesian, coord-flip. Planned: coord-fixed/equal/trans.
- facet-wrap (fixed scales). Planned: facet-grid, free scales, labellers.

### guides
- Discrete legends (color/fill/shape) drawn outside-right via proxy artists.
- Colorbar for continuous color/fill: drawn (gradient bar + value labels
  + title, geometry measured from plotnine). Tick placement detail still
  costs the heatmap example ~0.14.
- One legend per plot for now; multi-aesthetic guide merging planned.

### themes
gray/grey (plotnine default, pixel-calibrated), bw, minimal, classic,
dark, void + element-line/rect/text/blank and theme/theme-set/theme-get.
Planned: 538, xkcd-style, per-side element variants.

### helpers
labs xlab ylab ggtitle annotate qplot after-stat ggsave ggdraw.

## plotnine gallery (34 examples)

- **Implementable with current gg (24)**: scatter/shape/bubble examples,
  4 bar variants, 3 area, density(+shade), 2 boxplot, 2 violin, 2 facet,
  smoothed means, 3 tile heatmaps (pending colorbar), 2 segment charts,
  text-label examples, qq.
- **Needs planned features (4)**: date-break manipulation (date scales),
  counts/percentages tutorial (after_stat arithmetic), after_scale()
  example, plot composition example.
- **Blocked (3)**: geom_map x2 (no geospatial support), spiral animation
  (static backends).
- **Extension package (1)**: density-ridges (not core plotnine).
- **Allowlist-by-design**: anything jitter-based (numpy vs CL RNG streams).
