;;;; colors-database.lisp — CSS4 and base color name database
;;;; Ported from matplotlib._color_data

(in-package #:cl-matplotlib.colors)

;;; ============================================================
;;; Color database hash tables
;;; ============================================================

(defvar *base-colors* (make-hash-table :test 'equal)
  "Single-letter matplotlib color codes → (R G B) tuples.")

(defvar *tableau-colors* (make-hash-table :test 'equal)
  "Tableau color names → hex strings.")

(defvar *css4-colors* (make-hash-table :test 'equal)
  "CSS4 named colors → hex strings (148 colors).")

(defvar *all-named-colors* (make-hash-table :test 'equal)
  "Combined lookup: all named colors → RGBA vectors.")

;;; ============================================================
;;; Hex string → RGBA vector conversion
;;; ============================================================

(defun hex-to-rgba (hex-string &optional (alpha 1.0))
  "Convert a hex color string like \"#FF0000\" to an RGBA vector #(1.0 0.0 0.0 1.0).
Supports #RGB, #RRGGBB, and #RRGGBBAA formats."
  (let ((hex (if (char= (char hex-string 0) #\#)
                 (subseq hex-string 1)
                 hex-string)))
    (cond
      ;; #RRGGBBAA
      ((= (length hex) 8)
       (vector (/ (parse-integer hex :start 0 :end 2 :radix 16) 255.0)
               (/ (parse-integer hex :start 2 :end 4 :radix 16) 255.0)
               (/ (parse-integer hex :start 4 :end 6 :radix 16) 255.0)
               (/ (parse-integer hex :start 6 :end 8 :radix 16) 255.0)))
      ;; #RRGGBB
      ((= (length hex) 6)
       (vector (/ (parse-integer hex :start 0 :end 2 :radix 16) 255.0)
               (/ (parse-integer hex :start 2 :end 4 :radix 16) 255.0)
               (/ (parse-integer hex :start 4 :end 6 :radix 16) 255.0)
               alpha))
      ;; #RGB (short form)
      ((= (length hex) 3)
       (vector (/ (* (parse-integer hex :start 0 :end 1 :radix 16) 17) 255.0)
               (/ (* (parse-integer hex :start 1 :end 2 :radix 16) 17) 255.0)
               (/ (* (parse-integer hex :start 2 :end 3 :radix 16) 17) 255.0)
               alpha))
      (t (error "Invalid hex color string: ~S" hex-string)))))

(defun rgb-to-rgba (r g b &optional (alpha 1.0))
  "Create an RGBA vector from R, G, B components (each 0.0-1.0)."
  (vector (float r 1.0) (float g 1.0) (float b 1.0) (float alpha 1.0)))

;;; ============================================================
;;; Color lookup
;;; ============================================================

(defun to-rgba (color &optional (alpha nil))
  "Convert COLOR to an RGBA vector #(R G B A).
COLOR can be:
  - A named color string (\"red\", \"tab:blue\", \"C0\", etc.)
  - A hex string (\"#FF0000\", \"FF0000\")
  - An RGB/RGBA tuple (list or vector of 3-4 numbers)
  - A grayscale string (\"0.5\")
  - The string \"none\" → #(0.0 0.0 0.0 0.0)
ALPHA if provided overrides the alpha channel."
  (let ((result
          (cond
            ;; NIL or "none"
            ((null color) (vector 0.0 0.0 0.0 0.0))
            ((and (stringp color) (string-equal color "none"))
             (vector 0.0 0.0 0.0 0.0))

            ;; Already a vector of 3-4 (but NOT a string — strings are vectors in CL)
            ((and (vectorp color) (not (stringp color)) (= (length color) 4))
             (vector (float (aref color 0) 1.0)
                     (float (aref color 1) 1.0)
                     (float (aref color 2) 1.0)
                     (float (aref color 3) 1.0)))
            ((and (vectorp color) (not (stringp color)) (= (length color) 3))
             (vector (float (aref color 0) 1.0)
                     (float (aref color 1) 1.0)
                     (float (aref color 2) 1.0)
                     1.0))

            ;; List of 3-4 numbers
            ((and (listp color) (member (length color) '(3 4))
                  (every #'numberp color))
             (apply #'rgb-to-rgba color))

            ;; String processing
            ((stringp color)
             (let ((lower (string-downcase (string-trim '(#\Space #\Tab) color))))
               (cond
                 ;; Hex string with #
                 ((and (> (length lower) 0) (char= (char lower 0) #\#))
                  (hex-to-rgba lower))
                 ;; Named color lookup (BEFORE hex-without-# to avoid "red" → hex)
                 ((gethash lower *all-named-colors*)
                  (let ((v (gethash lower *all-named-colors*)))
                    (vector (aref v 0) (aref v 1) (aref v 2) (aref v 3))))
                 ;; CN color cycle syntax "C0", "C1", etc.
                 ((and (>= (length lower) 2) (char= (char lower 0) #\c)
                       (every #'digit-char-p (subseq lower 1)))
                  (let ((idx (parse-integer lower :start 1)))
                    (let ((tab10 #("1f77b4" "ff7f0e" "2ca02c" "d62728" "9467bd"
                                   "8c564b" "e377c2" "7f7f7f" "bcbd22" "17becf")))
                      (hex-to-rgba (concatenate 'string "#"
                                                (aref tab10 (mod idx 10)))))))
                 ;; Hex without # (only 6 or 8 chars, all hex digits)
                 ((and (member (length lower) '(6 8))
                       (every (lambda (c) (digit-char-p c 16)) lower))
                  (hex-to-rgba (concatenate 'string "#" lower)))
                 ;; Grayscale float string "0.5" etc.
                 ((let ((val (ignore-errors (read-from-string lower))))
                    (and (numberp val) (<= 0 val 1)))
                  (let ((g (float (read-from-string lower) 1.0)))
                    (vector g g g 1.0)))
                 (t (error "~S is not a recognized color" color)))))
            (t (error "~S is not a recognized color" color)))))

    ;; Override alpha if requested
    (when alpha
      (setf (aref result 3) (float alpha 1.0)))
    result))

(defun is-color-like (color)
  "Return T if COLOR can be interpreted as a color, NIL otherwise."
  (handler-case (progn (to-rgba color) t)
    (error () nil)))

;;; ============================================================
;;; Initialize color databases
;;; ============================================================

(defun initialize-color-databases ()
  "Populate all color database hash tables."

  ;; Base colors (single-letter)
  (loop for (name . rgb) in '(("b" . (0.0 0.0 1.0))
                                ("g" . (0.0 0.5 0.0))
                                ("r" . (1.0 0.0 0.0))
                                ("c" . (0.0 0.75 0.75))
                                ("m" . (0.75 0.0 0.75))
                                ("y" . (0.75 0.75 0.0))
                                ("k" . (0.0 0.0 0.0))
                                ("w" . (1.0 1.0 1.0)))
        do (setf (gethash name *base-colors*) rgb)
           (setf (gethash name *all-named-colors*)
                 (apply #'rgb-to-rgba rgb)))

  ;; Tableau colors
  (loop for (name . hex) in '(("tab:blue"    . "#1f77b4")
                                ("tab:orange"  . "#ff7f0e")
                                ("tab:green"   . "#2ca02c")
                                ("tab:red"     . "#d62728")
                                ("tab:purple"  . "#9467bd")
                                ("tab:brown"   . "#8c564b")
                                ("tab:pink"    . "#e377c2")
                                ("tab:gray"    . "#7f7f7f")
                                ("tab:olive"   . "#bcbd22")
                                ("tab:cyan"    . "#17becf"))
        do (setf (gethash name *tableau-colors*) hex)
           (setf (gethash name *all-named-colors*) (hex-to-rgba hex)))

  ;; CSS4 colors — 148 named colors
  (loop for (name . hex) in
        '(("aliceblue"            . "#F0F8FF")
          ("antiquewhite"         . "#FAEBD7")
          ("aqua"                 . "#00FFFF")
          ("aquamarine"           . "#7FFFD4")
          ("azure"                . "#F0FFFF")
          ("beige"                . "#F5F5DC")
          ("bisque"               . "#FFE4C4")
          ("black"                . "#000000")
          ("blanchedalmond"       . "#FFEBCD")
          ("blue"                 . "#0000FF")
          ("blueviolet"           . "#8A2BE2")
          ("brown"                . "#A52A2A")
          ("burlywood"            . "#DEB887")
          ("cadetblue"            . "#5F9EA0")
          ("chartreuse"           . "#7FFF00")
          ("chocolate"            . "#D2691E")
          ("coral"                . "#FF7F50")
          ("cornflowerblue"       . "#6495ED")
          ("cornsilk"             . "#FFF8DC")
          ("crimson"              . "#DC143C")
          ("cyan"                 . "#00FFFF")
          ("darkblue"             . "#00008B")
          ("darkcyan"             . "#008B8B")
          ("darkgoldenrod"        . "#B8860B")
          ("darkgray"             . "#A9A9A9")
          ("darkgreen"            . "#006400")
          ("darkgrey"             . "#A9A9A9")
          ("darkkhaki"            . "#BDB76B")
          ("darkmagenta"          . "#8B008B")
          ("darkolivegreen"       . "#556B2F")
          ("darkorange"           . "#FF8C00")
          ("darkorchid"           . "#9932CC")
          ("darkred"              . "#8B0000")
          ("darksalmon"           . "#E9967A")
          ("darkseagreen"         . "#8FBC8F")
          ("darkslateblue"        . "#483D8B")
          ("darkslategray"        . "#2F4F4F")
          ("darkslategrey"        . "#2F4F4F")
          ("darkturquoise"        . "#00CED1")
          ("darkviolet"           . "#9400D3")
          ("deeppink"             . "#FF1493")
          ("deepskyblue"          . "#00BFFF")
          ("dimgray"              . "#696969")
          ("dimgrey"              . "#696969")
          ("dodgerblue"           . "#1E90FF")
          ("firebrick"            . "#B22222")
          ("floralwhite"          . "#FFFAF0")
          ("forestgreen"          . "#228B22")
          ("fuchsia"              . "#FF00FF")
          ("gainsboro"            . "#DCDCDC")
          ("ghostwhite"           . "#F8F8FF")
          ("gold"                 . "#FFD700")
          ("goldenrod"            . "#DAA520")
          ("gray"                 . "#808080")
          ("green"                . "#008000")
          ("greenyellow"          . "#ADFF2F")
          ("grey"                 . "#808080")
          ("honeydew"             . "#F0FFF0")
          ("hotpink"              . "#FF69B4")
          ("indianred"            . "#CD5C5C")
          ("indigo"               . "#4B0082")
          ("ivory"                . "#FFFFF0")
          ("khaki"                . "#F0E68C")
          ("lavender"             . "#E6E6FA")
          ("lavenderblush"        . "#FFF0F5")
          ("lawngreen"            . "#7CFC00")
          ("lemonchiffon"         . "#FFFACD")
          ("lightblue"            . "#ADD8E6")
          ("lightcoral"           . "#F08080")
          ("lightcyan"            . "#E0FFFF")
          ("lightgoldenrodyellow" . "#FAFAD2")
          ("lightgray"            . "#D3D3D3")
          ("lightgreen"           . "#90EE90")
          ("lightgrey"            . "#D3D3D3")
          ("lightpink"            . "#FFB6C1")
          ("lightsalmon"          . "#FFA07A")
          ("lightseagreen"        . "#20B2AA")
          ("lightskyblue"         . "#87CEFA")
          ("lightslategray"       . "#778899")
          ("lightslategrey"       . "#778899")
          ("lightsteelblue"       . "#B0C4DE")
          ("lightyellow"          . "#FFFFE0")
          ("lime"                 . "#00FF00")
          ("limegreen"            . "#32CD32")
          ("linen"                . "#FAF0E6")
          ("magenta"              . "#FF00FF")
          ("maroon"               . "#800000")
          ("mediumaquamarine"     . "#66CDAA")
          ("mediumblue"           . "#0000CD")
          ("mediumorchid"         . "#BA55D3")
          ("mediumpurple"         . "#9370DB")
          ("mediumseagreen"       . "#3CB371")
          ("mediumslateblue"      . "#7B68EE")
          ("mediumspringgreen"    . "#00FA9A")
          ("mediumturquoise"      . "#48D1CC")
          ("mediumvioletred"      . "#C71585")
          ("midnightblue"         . "#191970")
          ("mintcream"            . "#F5FFFA")
          ("mistyrose"            . "#FFE4E1")
          ("moccasin"             . "#FFE4B5")
          ("navajowhite"          . "#FFDEAD")
          ("navy"                 . "#000080")
          ("oldlace"              . "#FDF5E6")
          ("olive"                . "#808000")
          ("olivedrab"            . "#6B8E23")
          ("orange"               . "#FFA500")
          ("orangered"            . "#FF4500")
          ("orchid"               . "#DA70D6")
          ("palegoldenrod"        . "#EEE8AA")
          ("palegreen"            . "#98FB98")
          ("paleturquoise"        . "#AFEEEE")
          ("palevioletred"        . "#DB7093")
          ("papayawhip"           . "#FFEFD5")
          ("peachpuff"            . "#FFDAB9")
          ("peru"                 . "#CD853F")
          ("pink"                 . "#FFC0CB")
          ("plum"                 . "#DDA0DD")
          ("powderblue"           . "#B0E0E6")
          ("purple"               . "#800080")
          ("rebeccapurple"        . "#663399")
          ("red"                  . "#FF0000")
          ("rosybrown"            . "#BC8F8F")
          ("royalblue"            . "#4169E1")
          ("saddlebrown"          . "#8B4513")
          ("salmon"               . "#FA8072")
          ("sandybrown"           . "#F4A460")
          ("seagreen"             . "#2E8B57")
          ("seashell"             . "#FFF5EE")
          ("sienna"               . "#A0522D")
          ("silver"               . "#C0C0C0")
          ("skyblue"              . "#87CEEB")
          ("slateblue"            . "#6A5ACD")
          ("slategray"            . "#708090")
          ("slategrey"            . "#708090")
          ("snow"                 . "#FFFAFA")
          ("springgreen"          . "#00FF7F")
          ("steelblue"            . "#4682B4")
          ("tan"                  . "#D2B48C")
          ("teal"                 . "#008080")
          ("thistle"              . "#D8BFD8")
          ("tomato"               . "#FF6347")
          ("turquoise"            . "#40E0D0")
          ("violet"               . "#EE82EE")
          ("wheat"                . "#F5DEB3")
          ("white"                . "#FFFFFF")
          ("whitesmoke"           . "#F5F5F5")
          ("yellow"               . "#FFFF00")
          ("yellowgreen"          . "#9ACD32"))
        do (setf (gethash name *css4-colors*) hex)
           (setf (gethash name *all-named-colors*) (hex-to-rgba hex)))

  ;; Report counts
  (format t "~&; cl-matplotlib.colors: ~D base, ~D tableau, ~D CSS4 colors loaded (~D total).~%"
          (hash-table-count *base-colors*)
          (hash-table-count *tableau-colors*)
          (hash-table-count *css4-colors*)
          (hash-table-count *all-named-colors*)))

;; Initialize at load time
(initialize-color-databases)
