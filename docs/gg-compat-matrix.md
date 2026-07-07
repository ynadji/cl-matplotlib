# ggplot (gg) — plotnine compatibility matrix

Status of the `ggplot` system against plotnine's public API and gallery.
SSIM scores are `make gg-compare-png` results against plotnine 0.15.7
references at 640x480/dpi 100 (threshold 0.90; `allowlist-gg.json` carries
justified exceptions). Updated: 2026-07-07.

## Example twins (reference_scripts/gg + examples/gg)

| example | SSIM | status |
|---|---|---|
| gg-boxplot | 0.969 | pass |
| gg-brewer | 0.957 | pass |
| gg-legend-none | 0.952 | pass |
| gg-theme-tufte | 0.945 | pass |
| gg-theme-538 | 0.934 | pass |
| gg-theme-matplotlib | 0.930 | pass |
| gg-abline | 0.954 | pass |
| gg-crossbar | 0.936 | pass |
| gg-reverse | 0.934 | pass |
| gg-gradient2 | 0.910 | pass |
| gg-area-stacked | 0.968 | pass |
| gg-density | 0.964 | pass |
| gg-violin | 0.958 | pass |
| gg-bar-flip | 0.954 | pass |
| gg-scatter-basic | 0.950 | pass |
| ggblank | 0.951 | pass |
| gg-bar-basic | 0.950 | pass |
| gg-rug-scatter | 0.939 | pass |
| gg-errorbar | 0.937 | pass |
| gg-bar-percent | 0.935 | pass |
| gg-scatter-color | 0.934 | pass |
| gg-bar-stacked | 0.933 | pass |
| gg-dates | 0.930 | pass |
| gg-segment-text | 0.929 | pass |
| gg-bar-dodge | 0.926 | pass |
| gg-line-basic | 0.921 | pass |
| gg-legend-left | 0.916 | pass |
| gg-legend-bottom | 0.914 | pass |
| gg-theme-light | 0.905 | pass |
| gg-theme-seaborn | 0.904 | pass |
| gg-smooth-lm | 0.909 | pass |
| gg-annotate | 0.903 | pass |
| gg-ecdf-step | 0.890 | step AA + 3px margin |
| gg-count | 0.881 | size-key calibration |
| gg-bin2d | 0.853 | tile AA detail |
| gg-tile-heatmap | 0.880 | tile edge AA |
| gg-histogram | 0.877 | 4px right margin + bar AA |
| gg-facet-wrap | 0.876 | strip/point detail |
| gg-qq-basic | 0.882 | point AA detail |
| gg-freqpoly | 0.858 | line AA detail |
| gg-facet-free | 0.842 | strip/gap detail |
| gg-log10-scatter | 0.841 | log minor-grid AA |
| gg-theme-linedraw | 0.874 | hairline-grid AA |
| gg-facet-grid | 0.808 | strip band detail |

Systemic fixes that lifted the suite (in discovery order): spine
visibility used the wrong key type (black frame everywhere); minor tick
MARKS drawn where plotnine has only gridlines; continuous axis breaks
computed over the EXPANDED limits (plotnine >= 0.15); legends drawn
manually to plotnine's measured geometry instead of through axes-legend;
margin/legend text measured with matplotlib's DejaVu advance-width table
(our rasterizer's ink extents run ~14% narrower and skewed every
margin); label-aware right/top margins when a tick label would overflow;
boxplot y-range trained over outliers (ymin/ymax-final). The remaining
sub-0.90 examples differ by antialiasing detail and 3-4px of empirical
margin rule, not by structure.

## plotnine API surface

### geoms
| implemented (30) | planned | blocked |
|---|---|---|
| blank point line path bar col histogram freqpoly area ribbon density boxplot violin smooth tile raster text label segment hline vline abline rect step rug linerange errorbar pointrange crossbar qq bin2d count jitter | dotplot density-2d quantile sina spoke pointdensity | map (no geospatial backend) |

### stats
| implemented (13) | planned |
|---|---|
| identity count bin bin2d sum density boxplot ydensity smooth(lm/loess) ecdf qq | function summary sina quantile |

### positions
All: identity stack fill dodge jitter nudge. (dodge2/jitterdodge planned.)

### scales
| implemented | planned | notes |
|---|---|---|
| x/y continuous + discrete, x/y log10, x/y sqrt, x/y reverse, x/y date, color/fill discrete (HLS = plotnine default), manual, brewer (22 ColorBrewer palettes), gradient, gradient2, gradientn, cmap (viridis default), grey, identity (color/fill/shape/size); shape manual; size (area palette); alpha; xlim/ylim/lims; expand-limits | datetime | log10 transforms data + integer-exponent ticks, like plotnine. Date scales take universal-time values (see `gg:date`), `:date-breaks '(:month 6)` calendar breaks, `:date-labels` strftime subset |

### coords / facets
- coord-cartesian, coord-flip. Planned: coord-fixed/equal/trans.
- facet-wrap and facet-grid (row/column strips), :scales :fixed/:free/
  :free-x/:free-y (continuous scales; free dims get per-panel limits,
  breaks, and tick labels with plotnine's widened panel spacing),
  labellers :value/:both/function.

### guides
- Discrete legends (color/fill/shape) drawn outside-right via proxy artists.
- Colorbar for continuous color/fill: drawn (gradient bar + value labels
  + title, geometry measured from plotnine). Tick placement detail still
  costs the heatmap example ~0.14.
- Multiple legends stack vertically (11px apart), centered as a group.
- legend-position :left mirrors the right geometry at the figure's left
  edge; :bottom/:top draw one horizontal key row (measured: keys 22px,
  9px from the figure edge); :none skips and reclaims the margin.

### themes
gray/grey (plotnine default, pixel-calibrated), bw, minimal, classic,
dark, void, 538, light, linedraw, matplotlib, seaborn, tufte +
element-line/rect/text/blank and theme/theme-set/theme-get.
Consumed elements now include panel-border (stroked), drawn axis-line
colors, strip-text, legend-key/legend-background fills, per-side
axis-text/-title fallbacks (%resolved-element), tick length/pad
(:axis-ticks-length/-minor, :axis-ticks-pad participate in margins),
per-theme :plot-margin-extra, and legend-position
(:right/:left/:bottom/:top/:none). Planned: xkcd (blocked on path
effects/handwriting font).

### helpers
labs xlab ylab ggtitle annotate qplot after-stat ggsave ggdraw
date format-date (universal-time helpers for date scales).

`after-stat` accepts a stat-output column keyword or a function of the
stat table, the analogue of plotnine's `after_stat('count / count.sum()')`:
`(gg:aes :y (gg:after-stat (lambda (tbl) ...)))`.

## plotnine gallery (34 examples)

- **Implementable with current gg (24)**: scatter/shape/bubble examples,
  4 bar variants, 3 area, density(+shade), 2 boxplot, 2 violin, 2 facet,
  smoothed means, 3 tile heatmaps (pending colorbar), 2 segment charts,
  text-label examples, qq.
- **Needs planned features (2)**: after_scale() example, plot composition
  example. (Date-break manipulation and counts/percentages are now
  implementable: `scale-x-date`/`scale-y-date` and function-valued
  `after-stat` cover them — see gg-dates and gg-bar-percent.)
- **Blocked (3)**: geom_map x2 (no geospatial support), spiral animation
  (static backends).
- **Extension package (1)**: density-ridges (not core plotnine).
- **Allowlist-by-design**: anything jitter-based (numpy vs CL RNG streams).
