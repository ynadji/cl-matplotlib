;;;; ggsave.lisp — render a plot to a file, a string, or a display backend

(in-package #:ggplot)

(defun ggsave (plot destination &key (width 6.4d0) (height 4.8d0) (dpi 100) format)
  "Render PLOT and write it to DESTINATION: a filename (format from the
extension: png/svg/pdf, or override with :format), a character output
stream (:format :svg required), or NIL to return the SVG document as a
string (:format :svg required; see GGSVG). WIDTH/HEIGHT are in inches.
Returns the figure, and as a second value what SAVEFIG returned: the
filename, the stream, or the SVG string."
  (let* ((fig (ggdraw plot :width width :height height :dpi dpi))
         (result (if format
                     (cl-matplotlib.containers:savefig fig destination :format format)
                     (cl-matplotlib.containers:savefig fig destination))))
    (values fig result)))

(defun ggsvg (plot &key (width 6.4d0) (height 4.8d0) (dpi 100))
  "Render PLOT and return the SVG document as a string, without touching
the filesystem. WIDTH/HEIGHT are in inches. No plotnine counterpart; it
exists for in-process display (an editor image buffer, a web response)."
  (nth-value 1 (ggsave plot nil :width width :height height :dpi dpi :format :svg)))

(defun ggshow (plot &key (width 6.4d0) (height 4.8d0) (dpi 100) block)
  "Draw PLOT and display it through whatever display backend pyplot's
(show) uses — cl-matplotlib-show-emacs, -web, -sdl2, ... — via
mpl.pyplot:*show-hook*. WIDTH/HEIGHT are in inches. BLOCK is passed to
the backend. With no backend loaded, prints the same hint as (show).
Returns the figure."
  (let ((fig (ggdraw plot :width width :height height :dpi dpi)))
    (if cl-matplotlib.pyplot:*show-hook*
        (funcall cl-matplotlib.pyplot:*show-hook* fig :block block)
        (format t "~&; ggshow: No display backend loaded — use (ggsave plot \"file.png\"), or (ql:quickload :cl-matplotlib-show-emacs) / :cl-matplotlib-show-web for display.~%"))
    fig))
