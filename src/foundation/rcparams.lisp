;;;; rcparams.lisp — Default rcParams definitions (~180 params relevant to PNG/PDF)
;;;; Ported from matplotlib's matplotlibrc defaults.
;;;; Skips GUI-related params (backend.qt5, toolbar, keymap.*, animation.*, webagg.*)

(in-package #:cl-matplotlib.rc)

;;; ============================================================
;;; Register all default rcParams
;;; ============================================================

(defun initialize-default-rc-params ()
  "Register all default rcParams with their validators and default values.
Call this once at load time."

  ;; Clear any existing params first
  (clrhash *rc-validators*)
  (clrhash *rc-params*)
  (clrhash *rc-defaults*)

  ;; -------------------------------------------------------
  ;; LINES
  ;; -------------------------------------------------------
  (define-rc-param "lines.linewidth"       1.5          #'validate-float)
  (define-rc-param "lines.linestyle"       "-"          #'validate-linestyle)
  (define-rc-param "lines.color"           "C0"         #'validate-color)
  (define-rc-param "lines.marker"          "None"       #'validate-marker)
  (define-rc-param "lines.markerfacecolor" "auto"       #'validate-color-or-auto)
  (define-rc-param "lines.markeredgecolor" "auto"       #'validate-color-or-auto)
  (define-rc-param "lines.markeredgewidth" 1.0          #'validate-float)
  (define-rc-param "lines.markersize"      6.0          #'validate-float)
  (define-rc-param "lines.antialiased"     t            #'validate-bool)
  (define-rc-param "lines.dash_joinstyle"  "round"      #'validate-joinstyle)
  (define-rc-param "lines.solid_joinstyle" "round"      #'validate-joinstyle)
  (define-rc-param "lines.dash_capstyle"   "butt"       #'validate-capstyle)
  (define-rc-param "lines.solid_capstyle"  "projecting" #'validate-capstyle)
  (define-rc-param "lines.dashed_pattern"  '(3.7 1.6)   #'validate-floatlist)
  (define-rc-param "lines.dashdot_pattern" '(6.4 1.6 1.0 1.6) #'validate-floatlist)
  (define-rc-param "lines.dotted_pattern"  '(1.0 1.65)  #'validate-floatlist)
  (define-rc-param "lines.scale_dashes"    t            #'validate-bool)

  ;; MARKERS
  (define-rc-param "markers.fillstyle"     "full"       #'validate-fillstyle)

  ;; -------------------------------------------------------
  ;; PATCHES
  ;; -------------------------------------------------------
  (define-rc-param "patch.linewidth"       1.0          #'validate-float)
  (define-rc-param "patch.facecolor"       "C0"         #'validate-color)
  (define-rc-param "patch.edgecolor"       "black"      #'validate-color)
  (define-rc-param "patch.force_edgecolor" nil          #'validate-bool)
  (define-rc-param "patch.antialiased"     t            #'validate-bool)

  ;; HATCHES
  (define-rc-param "hatch.color"           "edge"       #'validate-color)
  (define-rc-param "hatch.linewidth"       1.0          #'validate-float)

  ;; -------------------------------------------------------
  ;; BOXPLOT
  ;; -------------------------------------------------------
  (define-rc-param "boxplot.notch"         nil          #'validate-bool)
  (define-rc-param "boxplot.vertical"      t            #'validate-bool)
  (define-rc-param "boxplot.whiskers"      1.5          #'validate-float)
  (define-rc-param "boxplot.bootstrap"     nil          #'validate-int-or-none)
  (define-rc-param "boxplot.patchartist"   nil          #'validate-bool)
  (define-rc-param "boxplot.showmeans"     nil          #'validate-bool)
  (define-rc-param "boxplot.showcaps"      t            #'validate-bool)
  (define-rc-param "boxplot.showbox"       t            #'validate-bool)
  (define-rc-param "boxplot.showfliers"    t            #'validate-bool)
  (define-rc-param "boxplot.meanline"      nil          #'validate-bool)

  (define-rc-param "boxplot.flierprops.color"           "black"  #'validate-color)
  (define-rc-param "boxplot.flierprops.marker"          "o"      #'validate-marker)
  (define-rc-param "boxplot.flierprops.markerfacecolor" "none"   #'validate-color)
  (define-rc-param "boxplot.flierprops.markeredgecolor" "black"  #'validate-color)
  (define-rc-param "boxplot.flierprops.markeredgewidth" 1.0      #'validate-float)
  (define-rc-param "boxplot.flierprops.markersize"      6.0      #'validate-float)
  (define-rc-param "boxplot.flierprops.linestyle"       "none"   #'validate-linestyle)
  (define-rc-param "boxplot.flierprops.linewidth"       1.0      #'validate-float)

  (define-rc-param "boxplot.boxprops.color"     "black"  #'validate-color)
  (define-rc-param "boxplot.boxprops.linewidth" 1.0      #'validate-float)
  (define-rc-param "boxplot.boxprops.linestyle" "-"      #'validate-linestyle)

  (define-rc-param "boxplot.whiskerprops.color"     "black"  #'validate-color)
  (define-rc-param "boxplot.whiskerprops.linewidth" 1.0      #'validate-float)
  (define-rc-param "boxplot.whiskerprops.linestyle" "-"      #'validate-linestyle)

  (define-rc-param "boxplot.capprops.color"     "black"  #'validate-color)
  (define-rc-param "boxplot.capprops.linewidth" 1.0      #'validate-float)
  (define-rc-param "boxplot.capprops.linestyle" "-"      #'validate-linestyle)

  (define-rc-param "boxplot.medianprops.color"     "C1"   #'validate-color)
  (define-rc-param "boxplot.medianprops.linewidth" 1.0    #'validate-float)
  (define-rc-param "boxplot.medianprops.linestyle" "-"    #'validate-linestyle)

  (define-rc-param "boxplot.meanprops.color"           "C2"   #'validate-color)
  (define-rc-param "boxplot.meanprops.marker"          "^"    #'validate-marker)
  (define-rc-param "boxplot.meanprops.markerfacecolor" "C2"   #'validate-color)
  (define-rc-param "boxplot.meanprops.markeredgecolor" "C2"   #'validate-color)
  (define-rc-param "boxplot.meanprops.markersize"      6.0    #'validate-float)
  (define-rc-param "boxplot.meanprops.linestyle"       "--"   #'validate-linestyle)
  (define-rc-param "boxplot.meanprops.linewidth"       1.0    #'validate-float)

  ;; -------------------------------------------------------
  ;; FONT
  ;; -------------------------------------------------------
  (define-rc-param "font.family"      '("sans-serif")  #'validate-stringlist)
  (define-rc-param "font.style"       "normal"         #'validate-string)
  (define-rc-param "font.variant"     "normal"         #'validate-string)
  (define-rc-param "font.weight"      "normal"         #'validate-fontweight)
  (define-rc-param "font.stretch"     "normal"         #'validate-fontstretch)
  (define-rc-param "font.size"        10.0             #'validate-float)
  (define-rc-param "font.serif"
    '("DejaVu Serif" "Bitstream Vera Serif" "Times New Roman" "Times" "serif")
    #'validate-stringlist)
  (define-rc-param "font.sans-serif"
    '("DejaVu Sans" "Bitstream Vera Sans" "Lucida Grande" "Verdana" "Geneva" "Arial" "Helvetica" "sans-serif")
    #'validate-stringlist)
  (define-rc-param "font.cursive"
    '("Apple Chancery" "Textile" "Zapf Chancery" "Sand" "cursive")
    #'validate-stringlist)
  (define-rc-param "font.fantasy"
    '("Chicago" "Charcoal" "Impact" "Western" "fantasy")
    #'validate-stringlist)
  (define-rc-param "font.monospace"
    '("DejaVu Sans Mono" "Bitstream Vera Sans Mono" "Courier New" "Courier" "monospace")
    #'validate-stringlist)

  ;; -------------------------------------------------------
  ;; TEXT
  ;; -------------------------------------------------------
  (define-rc-param "text.color"          "black"          #'validate-color)
  (define-rc-param "text.usetex"         nil              #'validate-bool)
  (define-rc-param "text.latex.preamble" ""               #'validate-string)
  (define-rc-param "text.hinting"        "force_autohint" #'validate-string)
  (define-rc-param "text.hinting_factor" 8                #'validate-int)
  (define-rc-param "text.kerning_factor" 0                #'validate-int)
  (define-rc-param "text.antialiased"    t                #'validate-bool)
  (define-rc-param "text.parse_math"     t                #'validate-bool)

  ;; MATHTEXT
  (define-rc-param "mathtext.fontset"    "dejavusans"  #'validate-string)
  (define-rc-param "mathtext.default"    "it"          #'validate-string)
  (define-rc-param "mathtext.fallback"   "cm"          #'validate-string-or-none)
  (define-rc-param "mathtext.bf"         "sans:bold"   #'validate-string)
  (define-rc-param "mathtext.bfit"       "sans:italic:bold" #'validate-string)
  (define-rc-param "mathtext.cal"        "cursive"     #'validate-string)
  (define-rc-param "mathtext.it"         "sans:italic" #'validate-string)
  (define-rc-param "mathtext.rm"         "sans"        #'validate-string)
  (define-rc-param "mathtext.sf"         "sans"        #'validate-string)
  (define-rc-param "mathtext.tt"         "monospace"   #'validate-string)

  ;; -------------------------------------------------------
  ;; AXES
  ;; -------------------------------------------------------
  (define-rc-param "axes.facecolor"       "white"    #'validate-color)
  (define-rc-param "axes.edgecolor"       "black"    #'validate-color)
  (define-rc-param "axes.linewidth"       0.8        #'validate-float)
  (define-rc-param "axes.grid"            nil        #'validate-bool)
  (define-rc-param "axes.grid.which"      "major"    #'validate-string)
  (define-rc-param "axes.grid.axis"       "both"     #'validate-string)
  (define-rc-param "axes.titlelocation"   "center"   #'validate-string)
  (define-rc-param "axes.titlesize"       "large"    #'validate-fontsize)
  (define-rc-param "axes.titleweight"     "normal"   #'validate-fontweight)
  (define-rc-param "axes.titlecolor"      "auto"     #'validate-color-or-auto)
  (define-rc-param "axes.titley"          nil        #'validate-float-or-none)
  (define-rc-param "axes.titlepad"        6.0        #'validate-float)
  (define-rc-param "axes.labelsize"       "medium"   #'validate-fontsize)
  (define-rc-param "axes.labelpad"        4.0        #'validate-float)
  (define-rc-param "axes.labelweight"     "normal"   #'validate-fontweight)
  (define-rc-param "axes.labelcolor"      "black"    #'validate-color)
  (define-rc-param "axes.axisbelow"       "line"     #'validate-axisbelow)

  (define-rc-param "axes.formatter.limits"          '(-5 6)  #'validate-intlist)
  (define-rc-param "axes.formatter.use_locale"      nil      #'validate-bool)
  (define-rc-param "axes.formatter.use_mathtext"    nil      #'validate-bool)
  (define-rc-param "axes.formatter.min_exponent"    0        #'validate-int)
  (define-rc-param "axes.formatter.useoffset"       t        #'validate-bool)
  (define-rc-param "axes.formatter.offset_threshold" 4       #'validate-int)

  (define-rc-param "axes.spines.left"   t  #'validate-bool)
  (define-rc-param "axes.spines.right"  t  #'validate-bool)
  (define-rc-param "axes.spines.top"    t  #'validate-bool)
  (define-rc-param "axes.spines.bottom" t  #'validate-bool)

  (define-rc-param "axes.unicode_minus"    t         #'validate-bool)
  (define-rc-param "axes.autolimit_mode"   "data"    #'validate-string)
  (define-rc-param "axes.xmargin"          0.05      #'validate-float)
  (define-rc-param "axes.ymargin"          0.05      #'validate-float)
  (define-rc-param "axes.zmargin"          0.05      #'validate-float)

  ;; AXIS
  (define-rc-param "xaxis.labellocation" "center"  #'validate-string)
  (define-rc-param "yaxis.labellocation" "center"  #'validate-string)

  ;; -------------------------------------------------------
  ;; TICKS
  ;; -------------------------------------------------------
  (define-rc-param "xtick.top"            nil      #'validate-bool)
  (define-rc-param "xtick.bottom"         t        #'validate-bool)
  (define-rc-param "xtick.labeltop"       nil      #'validate-bool)
  (define-rc-param "xtick.labelbottom"    t        #'validate-bool)
  (define-rc-param "xtick.major.size"     3.5      #'validate-float)
  (define-rc-param "xtick.minor.size"     2.0      #'validate-float)
  (define-rc-param "xtick.major.width"    0.8      #'validate-float)
  (define-rc-param "xtick.minor.width"    0.6      #'validate-float)
  (define-rc-param "xtick.major.pad"      3.5      #'validate-float)
  (define-rc-param "xtick.minor.pad"      3.4      #'validate-float)
  (define-rc-param "xtick.color"          "black"  #'validate-color)
  (define-rc-param "xtick.labelcolor"     "inherit" #'validate-color-or-inherit)
  (define-rc-param "xtick.labelsize"      "medium" #'validate-fontsize)
  (define-rc-param "xtick.direction"      "out"    #'validate-string)
  (define-rc-param "xtick.minor.visible"  nil      #'validate-bool)
  (define-rc-param "xtick.major.top"      t        #'validate-bool)
  (define-rc-param "xtick.major.bottom"   t        #'validate-bool)
  (define-rc-param "xtick.minor.top"      t        #'validate-bool)
  (define-rc-param "xtick.minor.bottom"   t        #'validate-bool)
  (define-rc-param "xtick.alignment"      "center" #'validate-string)

  (define-rc-param "ytick.left"           t        #'validate-bool)
  (define-rc-param "ytick.right"          nil      #'validate-bool)
  (define-rc-param "ytick.labelleft"      t        #'validate-bool)
  (define-rc-param "ytick.labelright"     nil      #'validate-bool)
  (define-rc-param "ytick.major.size"     3.5      #'validate-float)
  (define-rc-param "ytick.minor.size"     2.0      #'validate-float)
  (define-rc-param "ytick.major.width"    0.8      #'validate-float)
  (define-rc-param "ytick.minor.width"    0.6      #'validate-float)
  (define-rc-param "ytick.major.pad"      3.5      #'validate-float)
  (define-rc-param "ytick.minor.pad"      3.4      #'validate-float)
  (define-rc-param "ytick.color"          "black"  #'validate-color)
  (define-rc-param "ytick.labelcolor"     "inherit" #'validate-color-or-inherit)
  (define-rc-param "ytick.labelsize"      "medium" #'validate-fontsize)
  (define-rc-param "ytick.direction"      "out"    #'validate-string)
  (define-rc-param "ytick.minor.visible"  nil      #'validate-bool)
  (define-rc-param "ytick.major.left"     t        #'validate-bool)
  (define-rc-param "ytick.major.right"    t        #'validate-bool)
  (define-rc-param "ytick.minor.left"     t        #'validate-bool)
  (define-rc-param "ytick.minor.right"    t        #'validate-bool)
  (define-rc-param "ytick.alignment"      "center_baseline" #'validate-string)

  ;; -------------------------------------------------------
  ;; GRIDS
  ;; -------------------------------------------------------
  (define-rc-param "grid.color"     "#b0b0b0" #'validate-color)
  (define-rc-param "grid.linestyle" "-"       #'validate-linestyle)
  (define-rc-param "grid.linewidth" 0.8       #'validate-float)
  (define-rc-param "grid.alpha"     1.0       #'validate-float)

  ;; -------------------------------------------------------
  ;; LEGEND
  ;; -------------------------------------------------------
  (define-rc-param "legend.loc"             "best"    #'validate-string)
  (define-rc-param "legend.frameon"         t         #'validate-bool)
  (define-rc-param "legend.framealpha"      0.8       #'validate-float-or-none)
  (define-rc-param "legend.facecolor"       "inherit" #'validate-color-or-inherit)
  (define-rc-param "legend.edgecolor"       "0.8"     #'validate-color-or-inherit)
  (define-rc-param "legend.linewidth"       nil       #'validate-float-or-none)
  (define-rc-param "legend.fancybox"        t         #'validate-bool)
  (define-rc-param "legend.shadow"          nil       #'validate-bool)
  (define-rc-param "legend.numpoints"       1         #'validate-int)
  (define-rc-param "legend.scatterpoints"   1         #'validate-int)
  (define-rc-param "legend.markerscale"     1.0       #'validate-float)
  (define-rc-param "legend.fontsize"        "medium"  #'validate-fontsize)
  (define-rc-param "legend.labelcolor"      nil       #'validate-color-or-none)
  (define-rc-param "legend.title_fontsize"  nil       #'validate-fontsize-or-none)
  (define-rc-param "legend.borderpad"       0.4       #'validate-float)
  (define-rc-param "legend.labelspacing"    0.5       #'validate-float)
  (define-rc-param "legend.handlelength"    2.0       #'validate-float)
  (define-rc-param "legend.handleheight"    0.7       #'validate-float)
  (define-rc-param "legend.handletextpad"   0.8       #'validate-float)
  (define-rc-param "legend.borderaxespad"   0.5       #'validate-float)
  (define-rc-param "legend.columnspacing"   2.0       #'validate-float)

  ;; -------------------------------------------------------
  ;; FIGURE
  ;; -------------------------------------------------------
  (define-rc-param "figure.titlesize"    "large"   #'validate-fontsize)
  (define-rc-param "figure.titleweight"  "normal"  #'validate-fontweight)
  (define-rc-param "figure.labelsize"    "large"   #'validate-fontsize)
  (define-rc-param "figure.labelweight"  "normal"  #'validate-fontweight)
  (define-rc-param "figure.figsize"      '(6.4 4.8) #'validate-floatlist)
  (define-rc-param "figure.dpi"          100.0     #'validate-float)
  (define-rc-param "figure.facecolor"    "white"   #'validate-color)
  (define-rc-param "figure.edgecolor"    "white"   #'validate-color)
  (define-rc-param "figure.frameon"      t         #'validate-bool)
  (define-rc-param "figure.autolayout"   nil       #'validate-bool)
  (define-rc-param "figure.max_open_warning" 20    #'validate-int)

  (define-rc-param "figure.subplot.left"   0.125  #'validate-float)
  (define-rc-param "figure.subplot.right"  0.9    #'validate-float)
  (define-rc-param "figure.subplot.bottom" 0.11   #'validate-float)
  (define-rc-param "figure.subplot.top"    0.88   #'validate-float)
  (define-rc-param "figure.subplot.wspace" 0.2    #'validate-float)
  (define-rc-param "figure.subplot.hspace" 0.2    #'validate-float)

  (define-rc-param "figure.constrained_layout.use" nil      #'validate-bool)
  (define-rc-param "figure.constrained_layout.h_pad" 0.04167 #'validate-float)
  (define-rc-param "figure.constrained_layout.w_pad" 0.04167 #'validate-float)
  (define-rc-param "figure.constrained_layout.hspace" 0.02  #'validate-float)
  (define-rc-param "figure.constrained_layout.wspace" 0.02  #'validate-float)

  ;; -------------------------------------------------------
  ;; IMAGES
  ;; -------------------------------------------------------
  (define-rc-param "image.aspect"              "equal"  #'validate-aspect)
  (define-rc-param "image.interpolation"       "auto"   #'validate-string)
  (define-rc-param "image.interpolation_stage" "auto"   #'validate-string)
  (define-rc-param "image.cmap"                "viridis" #'validate-string)
  (define-rc-param "image.lut"                 256      #'validate-int)
  (define-rc-param "image.origin"              "upper"  #'validate-string)
  (define-rc-param "image.resample"            t        #'validate-bool)
  (define-rc-param "image.composite_image"     t        #'validate-bool)

  ;; -------------------------------------------------------
  ;; CONTOUR
  ;; -------------------------------------------------------
  (define-rc-param "contour.negative_linestyle" "--"    #'validate-linestyle)
  (define-rc-param "contour.corner_mask"        t       #'validate-bool)
  (define-rc-param "contour.linewidth"          nil     #'validate-float-or-none)
  (define-rc-param "contour.algorithm"          "mpl2014" #'validate-string)

  ;; ERRORBAR
  (define-rc-param "errorbar.capsize"  0.0  #'validate-float)

  ;; HISTOGRAM
  (define-rc-param "hist.bins"  10  #'validate-int)

  ;; SCATTER
  (define-rc-param "scatter.marker"      "o"     #'validate-marker)
  (define-rc-param "scatter.edgecolors"  "face"  #'validate-string)

  ;; PCOLOR
  (define-rc-param "pcolor.shading"     "auto"  #'validate-string)
  (define-rc-param "pcolormesh.snap"    t       #'validate-bool)

  ;; -------------------------------------------------------
  ;; PATHS
  ;; -------------------------------------------------------
  (define-rc-param "path.simplify"            t            #'validate-bool)
  (define-rc-param "path.simplify_threshold"  0.111111111  #'validate-float-0-to-1)
  (define-rc-param "path.snap"                t            #'validate-bool)
  (define-rc-param "path.sketch"              nil          #'validate-sketch)
  (define-rc-param "path.effects"             nil          #'validate-any)
  (define-rc-param "agg.path.chunksize"       0            #'validate-int)

  ;; -------------------------------------------------------
  ;; SAVING FIGURES
  ;; -------------------------------------------------------
  (define-rc-param "savefig.dpi"          "figure"     #'validate-dpi)
  (define-rc-param "savefig.facecolor"    "auto"       #'validate-color-or-auto)
  (define-rc-param "savefig.edgecolor"    "auto"       #'validate-color-or-auto)
  (define-rc-param "savefig.format"       "png"        #'validate-string)
  (define-rc-param "savefig.bbox"         nil          #'validate-bbox)
  (define-rc-param "savefig.pad_inches"   0.1          #'validate-float)
  (define-rc-param "savefig.directory"    "~"          #'validate-pathlike)
  (define-rc-param "savefig.transparent"  nil          #'validate-bool)
  (define-rc-param "savefig.orientation"  "portrait"   #'validate-string)

  ;; -------------------------------------------------------
  ;; PS / PDF output
  ;; -------------------------------------------------------
  (define-rc-param "ps.papersize"      "letter"  #'validate-string)
  (define-rc-param "ps.useafm"         nil       #'validate-bool)
  (define-rc-param "ps.fonttype"       3         #'validate-fonttype)
  (define-rc-param "ps.distiller.res"  6000      #'validate-int)
  (define-rc-param "pdf.compression"   6         #'validate-int)
  (define-rc-param "pdf.inheritcolor"  nil       #'validate-bool)
  (define-rc-param "pdf.use14corefonts" nil      #'validate-bool)
  (define-rc-param "pdf.fonttype"      3         #'validate-fonttype)

  ;; SVG
  (define-rc-param "svg.image_inline"  t         #'validate-bool)
  (define-rc-param "svg.fonttype"      "path"    #'validate-string)
  (define-rc-param "svg.hashsalt"      nil       #'validate-string-or-none)

  ;; -------------------------------------------------------
  ;; DATES
  ;; -------------------------------------------------------
  (define-rc-param "date.autoformatter.year"        "%Y"           #'validate-string)
  (define-rc-param "date.autoformatter.month"       "%Y-%m"        #'validate-string)
  (define-rc-param "date.autoformatter.day"         "%Y-%m-%d"     #'validate-string)
  (define-rc-param "date.autoformatter.hour"        "%m-%d %H"     #'validate-string)
  (define-rc-param "date.autoformatter.minute"      "%d %H:%M"     #'validate-string)
  (define-rc-param "date.autoformatter.second"      "%H:%M:%S"     #'validate-string)
  (define-rc-param "date.autoformatter.microsecond" "%M:%S.%f"     #'validate-string)

  ;; -------------------------------------------------------
  ;; DOCSTRING (internal)
  ;; -------------------------------------------------------
  (define-rc-param "docstring.hardcopy" nil  #'validate-bool)
  (define-rc-param "_internal.classic_mode" nil #'validate-bool)

  ;; Count registered params
  (let ((count (hash-table-count *rc-params*)))
    (format t "~&; cl-matplotlib: ~D rcParams registered.~%" count)
    count))

;; Initialize at load time
(initialize-default-rc-params)
