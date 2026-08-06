;;;; ggsave.lisp — render a plot to a file

(in-package #:ggplot)

(defun ggsave (plot filename &key (width 6.4d0) (height 4.8d0) (dpi 100) format)
  "Render PLOT and save it to FILENAME (format from extension: png/svg/pdf,
or override with :format). WIDTH/HEIGHT are in inches. Returns the figure."
  (let ((fig (ggdraw plot :width width :height height :dpi dpi)))
    (if format
        (cl-matplotlib.containers:savefig fig filename :format format)
        (cl-matplotlib.containers:savefig fig filename))
    fig))
