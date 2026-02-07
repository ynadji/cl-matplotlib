;;;; mathtext-data.lisp — Glyph metrics tables for math symbols
;;;; Ported from matplotlib's _mathtext_data.py
;;;; Maps TeX command names to Unicode code points.

(in-package #:cl-matplotlib.rendering)

;;; ============================================================
;;; tex2uni — TeX command name to Unicode code point mapping
;;; Core subset of symbols needed for math rendering
;;; ============================================================

(defvar *tex2uni* (make-hash-table :test 'equal)
  "Map from TeX symbol name (without backslash) to Unicode code point.")

(defun initialize-tex2uni ()
  "Initialize the TeX-to-Unicode mapping table."
  (let ((ht *tex2uni*))
    (clrhash ht)
    ;; Greek lowercase
    (setf (gethash "alpha" ht)      #x3b1
          (gethash "beta" ht)       #x3b2
          (gethash "gamma" ht)      #x3b3
          (gethash "delta" ht)      #x3b4
          (gethash "epsilon" ht)    #x3b5
          (gethash "varepsilon" ht) #x3b5
          (gethash "zeta" ht)       #x3b6
          (gethash "eta" ht)        #x3b7
          (gethash "theta" ht)      #x3b8
          (gethash "vartheta" ht)   #x3d1
          (gethash "iota" ht)       #x3b9
          (gethash "kappa" ht)      #x3ba
          (gethash "lambda" ht)     #x3bb
          (gethash "mu" ht)         #x3bc
          (gethash "nu" ht)         #x3bd
          (gethash "xi" ht)         #x3be
          (gethash "pi" ht)         #x3c0
          (gethash "varpi" ht)      #x3d6
          (gethash "rho" ht)        #x3c1
          (gethash "varrho" ht)     #x3f1
          (gethash "sigma" ht)      #x3c3
          (gethash "varsigma" ht)   #x3c2
          (gethash "tau" ht)        #x3c4
          (gethash "upsilon" ht)    #x3c5
          (gethash "phi" ht)        #x3c6
          (gethash "varphi" ht)     #x3d5
          (gethash "chi" ht)        #x3c7
          (gethash "psi" ht)        #x3c8
          (gethash "omega" ht)      #x3c9)
    ;; Greek uppercase
    (setf (gethash "Gamma" ht)   #x393
          (gethash "Delta" ht)   #x394
          (gethash "Theta" ht)   #x398
          (gethash "Lambda" ht)  #x39b
          (gethash "Xi" ht)      #x39e
          (gethash "Pi" ht)      #x3a0
          (gethash "Sigma" ht)   #x3a3
          (gethash "Upsilon" ht) #x3a5
          (gethash "Phi" ht)     #x3a6
          (gethash "Psi" ht)     #x3a8
          (gethash "Omega" ht)   #x3a9)
    ;; Operators (large)
    (setf (gethash "int" ht)     #x222b
          (gethash "iint" ht)    #x222c
          (gethash "iiint" ht)   #x222d
          (gethash "oint" ht)    #x222e
          (gethash "sum" ht)     #x2211
          (gethash "prod" ht)    #x220f
          (gethash "coprod" ht)  #x2210
          (gethash "bigcap" ht)  #x22c2
          (gethash "bigcup" ht)  #x22c3
          (gethash "bigvee" ht)  #x22c1
          (gethash "bigwedge" ht) #x22c0)
    ;; Relation operators
    (setf (gethash "leq" ht)     #x2264
          (gethash "le" ht)      #x2264
          (gethash "geq" ht)     #x2265
          (gethash "ge" ht)      #x2265
          (gethash "neq" ht)     #x2260
          (gethash "ne" ht)      #x2260
          (gethash "approx" ht)  #x2248
          (gethash "equiv" ht)   #x2261
          (gethash "sim" ht)     #x223c
          (gethash "simeq" ht)   #x2243
          (gethash "ll" ht)      #x226a
          (gethash "gg" ht)      #x226b
          (gethash "subset" ht)  #x2282
          (gethash "supset" ht)  #x2283
          (gethash "subseteq" ht) #x2286
          (gethash "supseteq" ht) #x2287
          (gethash "in" ht)      #x2208
          (gethash "ni" ht)      #x220b
          (gethash "notin" ht)   #x2209
          (gethash "propto" ht)  #x221d
          (gethash "perp" ht)    #x22a5
          (gethash "parallel" ht) #x2225
          (gethash "vdash" ht)   #x22a2
          (gethash "dashv" ht)   #x22a3)
    ;; Binary operators
    (setf (gethash "pm" ht)      #x00b1
          (gethash "mp" ht)      #x2213
          (gethash "times" ht)   #x00d7
          (gethash "div" ht)     #x00f7
          (gethash "cdot" ht)    #x22c5
          (gethash "ast" ht)     #x2217
          (gethash "star" ht)    #x22c6
          (gethash "circ" ht)    #x2218
          (gethash "bullet" ht)  #x2219
          (gethash "oplus" ht)   #x2295
          (gethash "ominus" ht)  #x2296
          (gethash "otimes" ht)  #x2297
          (gethash "cap" ht)     #x2229
          (gethash "cup" ht)     #x222a
          (gethash "wedge" ht)   #x2227
          (gethash "vee" ht)     #x2228)
    ;; Arrows
    (setf (gethash "leftarrow" ht)       #x2190
          (gethash "rightarrow" ht)      #x2192
          (gethash "to" ht)              #x2192
          (gethash "uparrow" ht)         #x2191
          (gethash "downarrow" ht)       #x2193
          (gethash "leftrightarrow" ht)  #x2194
          (gethash "Leftarrow" ht)       #x21d0
          (gethash "Rightarrow" ht)      #x21d2
          (gethash "Uparrow" ht)         #x21d1
          (gethash "Downarrow" ht)       #x21d3
          (gethash "Leftrightarrow" ht)  #x21d4
          (gethash "mapsto" ht)          #x21a6)
    ;; Miscellaneous symbols
    (setf (gethash "infty" ht)      #x221e
          (gethash "nabla" ht)      #x2207
          (gethash "partial" ht)    #x2202
          (gethash "forall" ht)     #x2200
          (gethash "exists" ht)     #x2203
          (gethash "neg" ht)        #x00ac
          (gethash "lnot" ht)       #x00ac
          (gethash "emptyset" ht)   #x2205
          (gethash "wp" ht)         #x2118
          (gethash "Re" ht)         #x211c
          (gethash "Im" ht)         #x2111
          (gethash "aleph" ht)      #x2135
          (gethash "hbar" ht)       #x210f
          (gethash "ell" ht)        #x2113
          (gethash "dots" ht)       #x2026
          (gethash "ldots" ht)      #x2026
          (gethash "cdots" ht)      #x22ef
          (gethash "vdots" ht)      #x22ee
          (gethash "ddots" ht)      #x22f1
          (gethash "prime" ht)      #x2032)
    ;; Delimiters
    (setf (gethash "langle" ht)  #x27e8
          (gethash "rangle" ht)  #x27e9
          (gethash "lfloor" ht)  #x230a
          (gethash "rfloor" ht)  #x230b
          (gethash "lceil" ht)   #x2308
          (gethash "rceil" ht)   #x2309
          (gethash "lbrace" ht)  #x7b
          (gethash "rbrace" ht)  #x7d
          (gethash "lbrack" ht)  #x5b
          (gethash "rbrack" ht)  #x5d
          (gethash "vert" ht)    #x7c
          (gethash "Vert" ht)    #x2016)
    ;; Function names (mapped to regular text)
    (setf (gethash "lim" ht)     nil  ;; handled specially as operator name
          (gethash "sin" ht)     nil
          (gethash "cos" ht)     nil
          (gethash "tan" ht)     nil
          (gethash "log" ht)     nil
          (gethash "ln" ht)      nil
          (gethash "exp" ht)     nil
          (gethash "max" ht)     nil
          (gethash "min" ht)     nil
          (gethash "sup" ht)     nil
          (gethash "inf" ht)     nil
          (gethash "det" ht)     nil
          (gethash "dim" ht)     nil
          (gethash "ker" ht)     nil
          (gethash "hom" ht)     nil
          (gethash "arg" ht)     nil
          (gethash "deg" ht)     nil
          (gethash "gcd" ht)     nil)
    ;; Square root symbol
    (setf (gethash "__sqrt__" ht) #x221a)
    ;; Escaped characters
    (setf (gethash "{" ht)  #x7b
          (gethash "}" ht)  #x7d
          (gethash "#" ht)  #x23
          (gethash "$" ht)  #x24
          (gethash "%" ht)  #x25
          (gethash "&" ht)  #x26
          (gethash "_" ht)  #x5f
          (gethash "backslash" ht) #x5c)
    ht))

;; Initialize on load
(initialize-tex2uni)

;;; ============================================================
;;; Operator names — rendered as upright text, not symbols
;;; ============================================================

(defvar *operator-names*
  '("lim" "sin" "cos" "tan" "log" "ln" "exp" "max" "min"
    "sup" "inf" "det" "dim" "ker" "hom" "arg" "deg" "gcd"
    "arcsin" "arccos" "arctan" "sinh" "cosh" "tanh"
    "cot" "csc" "sec")
  "TeX operator names that should be rendered as upright text.")

(defun operator-name-p (name)
  "Return T if NAME is a TeX operator name."
  (member name *operator-names* :test #'string=))

;;; ============================================================
;;; TeX spacing categories
;;; ============================================================

(defconstant +thin-space+   0.16667d0 "Thin space (3/18 em).")
(defconstant +medium-space+ 0.22222d0 "Medium space (4/18 em).")
(defconstant +thick-space+  0.27778d0 "Thick space (5/18 em).")
(defconstant +quad-space+   1.0d0     "Quad space (1 em).")
(defconstant +qquad-space+  2.0d0     "Double-quad space (2 em).")

;;; ============================================================
;;; Shrink factors for sub/superscripts
;;; ============================================================

(defconstant +shrink-factor+ 0.7d0
  "Factor for shrinking text in sub/superscripts.")

(defconstant +num-size-levels+ 3
  "Maximum number of shrink levels (script, scriptscript).")

;;; ============================================================
;;; TeX spacing parameters (fractions of em)
;;; ============================================================

(defconstant +script-space+ 0.05d0
  "Additional spacing after super/subscript.")

(defconstant +sub-drop+ 0.05d0
  "How much to drop subscripts from baseline.")

(defconstant +sup-drop+ 0.386d0
  "How much to raise superscripts above baseline.")

(defconstant +sub1+ 0.2d0
  "Subscript shift for normal style.")

(defconstant +sup1+ 0.45d0
  "Superscript shift for normal style.")

(defconstant +delta+ 0.025d0
  "Clearance for super/subscript from nucleus.")

(defconstant +fraction-rule-thickness+ 0.04d0
  "Thickness of fraction bar as fraction of fontsize.")

(defconstant +fraction-num-vgap+ 0.1d0
  "Vertical gap above fraction bar for numerator.")

(defconstant +fraction-denom-vgap+ 0.1d0
  "Vertical gap below fraction bar for denominator.")

(defconstant +sqrt-rule-thickness+ 0.04d0
  "Thickness of square root bar.")

(defconstant +sqrt-vgap+ 0.1d0
  "Gap between content and sqrt bar.")

;;; ============================================================
;;; Symbol category for spacing
;;; ============================================================

(deftype symbol-category ()
  '(member :ordinary :operator :binary :relation :open :close :punctuation))

(defun classify-symbol (sym)
  "Return the spacing category for a math symbol.
SYM is a single character or TeX command name (without backslash)."
  (cond
    ;; TeX commands
    ((stringp sym)
     (let ((code (gethash sym *tex2uni*)))
       (if code
           (classify-char (code-char code))
           ;; Operator names
           (if (operator-name-p sym)
               :operator
               :ordinary))))
    ;; Single characters
    ((characterp sym)
     (classify-char sym))
    (t :ordinary)))

(defun classify-char (ch)
  "Return the spacing category for a character."
  (let ((code (char-code ch)))
    (cond
      ;; Relation operators
      ((member code '(#x003c #x003d #x003e  ;; < = >
                       #x2190 #x2191 #x2192 #x2193 #x2194  ;; arrows
                       #x21d0 #x21d1 #x21d2 #x21d3 #x21d4
                       #x2208 #x2209 #x220b #x221d
                       #x2223 #x2225 #x2227 #x2228
                       #x2243 #x2245 #x2248 #x224d
                       #x2260 #x2261 #x2264 #x2265
                       #x226a #x226b #x2282 #x2283
                       #x2286 #x2287 #x22a2 #x22a3 #x22a5))
       :relation)
      ;; Binary operators
      ((member code '(#x002b #x002d ;; + -
                       #x00b1 #x00d7 #x00f7  ;; ± × ÷
                       #x2213 #x2217 #x2218 #x2219
                       #x222a #x2229 #x2295 #x2296 #x2297
                       #x22c5 #x22c6))
       :binary)
      ;; Large operators
      ((member code '(#x220f #x2210 #x2211
                       #x222b #x222c #x222d #x222e
                       #x22c0 #x22c1 #x22c2 #x22c3))
       :operator)
      ;; Opening delimiters
      ((member code '(#x0028 #x005b #x007b  ;; ( [ {
                       #x2308 #x230a #x27e8))
       :open)
      ;; Closing delimiters
      ((member code '(#x0029 #x005d #x007d  ;; ) ] }
                       #x2309 #x230b #x27e9))
       :close)
      ;; Punctuation
      ((member code '(#x002c #x002e #x003a #x003b))  ;; , . : ;
       :punctuation)
      (t :ordinary))))

(defun inter-element-spacing (left-type right-type &optional script-p)
  "Return the spacing (in ems) between two element types.
SCRIPT-P indicates whether we're in a sub/superscript."
  (declare (ignore script-p))
  ;; Simplified spacing table from TeX
  (cond
    ;; No space next to open/close delimiters
    ((eq right-type :open) 0.0d0)
    ((eq left-type :close) 0.0d0)
    ;; Thin space around binary operators
    ((or (eq left-type :binary) (eq right-type :binary))
     +thin-space+)
    ;; Medium space around relations
    ((or (eq left-type :relation) (eq right-type :relation))
     +thick-space+)
    ;; Thin space between operator and ordinary
    ((and (eq left-type :operator) (eq right-type :ordinary))
     +thin-space+)
    ;; Thin space after punctuation
    ((eq left-type :punctuation)
     +thin-space+)
    ;; No extra space otherwise
    (t 0.0d0)))

;;; ============================================================
;;; get-unicode-index — resolve symbol to Unicode code point
;;; ============================================================

(defun get-unicode-index (symbol)
  "Return the Unicode code point for SYMBOL.
SYMBOL can be a single character, a TeX command (e.g. \"\\\\alpha\"),
or a name (e.g. \"alpha\")."
  (cond
    ;; Single character
    ((and (stringp symbol) (= (length symbol) 1))
     (char-code (char symbol 0)))
    ;; TeX command with backslash
    ((and (stringp symbol) (> (length symbol) 0)
          (char= (char symbol 0) #\\))
     (let ((name (subseq symbol 1)))
       (or (gethash name *tex2uni*)
           (error "Unknown TeX symbol: ~A" symbol))))
    ;; Plain name
    ((stringp symbol)
     (or (gethash symbol *tex2uni*)
         (error "Unknown symbol name: ~A" symbol)))
    ;; Character
    ((characterp symbol)
     (char-code symbol))
    (t (error "Invalid symbol: ~A" symbol))))
