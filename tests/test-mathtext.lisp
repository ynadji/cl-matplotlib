;;;; test-mathtext.lisp — Tests for mathtext parser and layout engine
;;;; Phase 6a — FiveAM test suite

(defpackage #:cl-matplotlib.tests.mathtext
  (:use #:cl #:fiveam)
  (:import-from #:cl-matplotlib.rendering
                ;; Mathtext data
                #:*tex2uni* #:initialize-tex2uni #:get-unicode-index
                #:*operator-names* #:operator-name-p
                #:classify-symbol #:classify-char #:inter-element-spacing
                #:+thin-space+ #:+medium-space+ #:+thick-space+
                #:+shrink-factor+ #:+num-size-levels+
                ;; Mathtext layout
                #:mt-node #:mt-box #:mt-box-width #:mt-box-height #:mt-box-depth
                #:mt-hbox #:make-mt-hbox
                #:mt-vbox #:make-mt-vbox
                #:mt-kern #:make-mt-kern #:mt-kern-width
                #:glue-spec #:make-glue-spec #:mt-glue #:make-mt-glue
                #:mt-list #:mt-list-shift-amount #:mt-list-children
                #:mt-char #:make-mt-char #:mt-char-c #:mt-char-width
                #:mt-char-height #:mt-char-depth #:mt-char-fontsize
                #:mt-rule #:make-mt-rule #:make-mt-hrule
                #:mt-hlist #:make-mt-hlist
                #:mt-vlist #:make-mt-vlist
                #:make-mt-hcentered
                #:mt-ship
                #:mt-node-shrink
                ;; Mathtext parser
                #:mt-token #:make-mt-token #:mt-token-type #:mt-token-value
                #:mt-lexer #:make-mt-lexer #:mt-lexer-peek #:mt-lexer-advance
                #:mt-parse #:mt-parse-math-string
                ;; Mathtext public interface
                #:mathtext-to-path #:mathtext-to-compound-path
                #:mathtext-get-dimensions #:mathtext-p
                ;; Font system
                #:ensure-font-manager #:findfont
                #:make-font-properties #:load-font)
  (:export #:run-mathtext-tests))

(in-package #:cl-matplotlib.tests.mathtext)

(def-suite mathtext-suite :description "Mathtext parser and layout engine tests")

(defun run-mathtext-tests ()
  (run! 'mathtext-suite))

;;; ============================================================
;;; Helper — get a font loader for testing
;;; ============================================================

(defvar *test-font-loader* nil "Cached font loader for tests.")

(defun get-test-font-loader ()
  "Get a zpb-ttf font-loader for testing."
  (unless *test-font-loader*
    (let* ((font-dir (merge-pathnames "data/fonts/ttf/"
                                       (asdf:system-source-directory :cl-matplotlib-rendering)))
           (font-path (merge-pathnames "DejaVuSans.ttf" font-dir)))
      (setf *test-font-loader* (zpb-ttf:open-font-loader font-path))))
  *test-font-loader*)

;;; ============================================================
;;; Section 1: Mathtext Data (tex2uni, symbol classification)
;;; ============================================================

(def-suite data-suite :in mathtext-suite :description "Mathtext data tables")

(test (tex2uni-initialized :suite data-suite)
  "tex2uni table is populated on load."
  (is (> (hash-table-count *tex2uni*) 50))
  (is (= (gethash "alpha" *tex2uni*) #x3b1))
  (is (= (gethash "beta" *tex2uni*) #x3b2))
  (is (= (gethash "pi" *tex2uni*) #x3c0))
  (is (= (gethash "infty" *tex2uni*) #x221e)))

(test (tex2uni-greek :suite data-suite)
  "Greek letters map to correct Unicode."
  (is (= (gethash "gamma" *tex2uni*) #x3b3))
  (is (= (gethash "delta" *tex2uni*) #x3b4))
  (is (= (gethash "sigma" *tex2uni*) #x3c3))
  (is (= (gethash "omega" *tex2uni*) #x3c9))
  ;; Uppercase
  (is (= (gethash "Gamma" *tex2uni*) #x393))
  (is (= (gethash "Delta" *tex2uni*) #x394))
  (is (= (gethash "Sigma" *tex2uni*) #x3a3))
  (is (= (gethash "Omega" *tex2uni*) #x3a9)))

(test (tex2uni-operators :suite data-suite)
  "Operator symbols map correctly."
  (is (= (gethash "int" *tex2uni*) #x222b))
  (is (= (gethash "sum" *tex2uni*) #x2211))
  (is (= (gethash "prod" *tex2uni*) #x220f))
  (is (= (gethash "pm" *tex2uni*) #x00b1))
  (is (= (gethash "times" *tex2uni*) #x00d7))
  (is (= (gethash "div" *tex2uni*) #x00f7)))

(test (tex2uni-relations :suite data-suite)
  "Relation operators map correctly."
  (is (= (gethash "leq" *tex2uni*) #x2264))
  (is (= (gethash "geq" *tex2uni*) #x2265))
  (is (= (gethash "neq" *tex2uni*) #x2260))
  (is (= (gethash "approx" *tex2uni*) #x2248)))

(test (get-unicode-index-function :suite data-suite)
  "get-unicode-index resolves various input types."
  ;; Single character
  (is (= (get-unicode-index "x") (char-code #\x)))
  ;; TeX command with backslash
  (is (= (get-unicode-index "\\alpha") #x3b1))
  ;; Plain name
  (is (= (get-unicode-index "pi") #x3c0))
  ;; Character
  (is (= (get-unicode-index #\A) (char-code #\A))))

(test (operator-names :suite data-suite)
  "Operator names are recognized."
  (is (eq t (not (null (operator-name-p "sin")))))
  (is (eq t (not (null (operator-name-p "cos")))))
  (is (eq t (not (null (operator-name-p "lim")))))
  (is (eq t (not (null (operator-name-p "log")))))
  (is (null (operator-name-p "foo")))
  (is (null (operator-name-p "alpha"))))

(test (symbol-classification :suite data-suite)
  "Symbol categories are correctly assigned."
  (is (eq :relation (classify-char #\=)))
  (is (eq :relation (classify-char #\<)))
  (is (eq :relation (classify-char #\>)))
  (is (eq :binary (classify-char #\+)))
  (is (eq :binary (classify-char #\-)))
  (is (eq :open (classify-char #\()))
  (is (eq :close (classify-char #\))))
  (is (eq :punctuation (classify-char #\,)))
  (is (eq :ordinary (classify-char #\x))))

(test (inter-element-spacing-values :suite data-suite)
  "Spacing between element types is correct."
  (is (= 0.0d0 (inter-element-spacing :ordinary :open)))
  (is (= 0.0d0 (inter-element-spacing :close :ordinary)))
  (is (> (inter-element-spacing :ordinary :binary) 0.0d0))
  (is (> (inter-element-spacing :ordinary :relation) 0.0d0)))

;;; ============================================================
;;; Section 2: Layout Engine (boxes, kern, glue)
;;; ============================================================

(def-suite layout-suite :in mathtext-suite :description "Box layout engine tests")

(test (hbox-creation :suite layout-suite)
  "Creating an Hbox with given width."
  (let ((box (make-mt-hbox 10.0d0)))
    (is (typep box 'mt-hbox))
    (is (= 10.0d0 (mt-box-width box)))
    (is (= 0.0d0 (mt-box-height box)))
    (is (= 0.0d0 (mt-box-depth box)))))

(test (vbox-creation :suite layout-suite)
  "Creating a Vbox with given height and depth."
  (let ((box (make-mt-vbox 5.0d0 2.0d0)))
    (is (typep box 'mt-vbox))
    (is (= 0.0d0 (mt-box-width box)))
    (is (= 5.0d0 (mt-box-height box)))
    (is (= 2.0d0 (mt-box-depth box)))))

(test (kern-creation :suite layout-suite)
  "Creating a Kern node."
  (let ((k (make-mt-kern 3.5d0)))
    (is (typep k 'mt-kern))
    (is (= 3.5d0 (mt-kern-width k)))))

(test (glue-creation :suite layout-suite)
  "Creating glue nodes by name."
  (let ((g (make-mt-glue :fil)))
    (is (typep g 'mt-glue))
    (is (= 0.0d0 (cl-matplotlib.rendering::glue-spec-width
                   (cl-matplotlib.rendering::mt-glue-spec g)))))
  (let ((g2 (make-mt-glue :ss)))
    (is (typep g2 'mt-glue))))

(test (char-node-creation :suite layout-suite)
  "Creating character nodes with font metrics."
  (let* ((fl (get-test-font-loader))
         (ch (make-mt-char #\x fl 12.0d0)))
    (is (typep ch 'mt-char))
    (is (eq #\x (mt-char-c ch)))
    (is (= 12.0d0 (mt-char-fontsize ch)))
    (is (> (mt-char-width ch) 0.0d0))
    (is (> (mt-char-height ch) 0.0d0))))

(test (hlist-with-chars :suite layout-suite)
  "Creating an Hlist from characters computes correct dimensions."
  (let* ((fl (get-test-font-loader))
         (c1 (make-mt-char #\A fl 12.0d0))
         (c2 (make-mt-char #\B fl 12.0d0))
         (hlist (make-mt-hlist (list c1 c2))))
    (is (typep hlist 'mt-hlist))
    ;; Width should be at least the sum of char widths
    (is (> (mt-box-width hlist) 0.0d0))
    ;; Height should be the max height of the chars
    (is (> (mt-box-height hlist) 0.0d0))
    ;; Should have children
    (is (>= (length (mt-list-children hlist)) 2))))

(test (vlist-creation :suite layout-suite)
  "Creating a Vlist stacks boxes vertically."
  (let ((b1 (make-mt-hbox 10.0d0))
        (b2 (make-mt-hbox 15.0d0)))
    ;; Give them some height
    (setf (mt-box-height b1) 5.0d0
          (mt-box-height b2) 5.0d0)
    (let ((vlist (make-mt-vlist (list b1 b2))))
      (is (typep vlist 'mt-vlist))
      ;; Width should be max of children widths
      (is (= 15.0d0 (mt-box-width vlist)))
      ;; Height should encompass both boxes
      (is (> (mt-box-height vlist) 0.0d0)))))

(test (rule-creation :suite layout-suite)
  "Creating rule nodes (fraction bars)."
  (let ((rule (make-mt-rule 20.0d0 0.5d0 0.5d0)))
    (is (typep rule 'mt-rule))
    (is (= 20.0d0 (mt-box-width rule)))
    (is (= 0.5d0 (mt-box-height rule)))
    (is (= 0.5d0 (mt-box-depth rule)))))

(test (shrink-reduces-size :suite layout-suite)
  "Shrinking reduces fontsize and dimensions."
  (let* ((fl (get-test-font-loader))
         (ch (make-mt-char #\x fl 12.0d0))
         (orig-fs (mt-char-fontsize ch))
         (orig-w (mt-char-width ch)))
    (mt-node-shrink ch)
    (is (< (mt-char-fontsize ch) orig-fs))
    (is (< (mt-char-width ch) orig-w))))

(test (hcentered-glue :suite layout-suite)
  "HCentered wraps content with centering glue."
  (let* ((fl (get-test-font-loader))
         (ch (make-mt-char #\A fl 12.0d0))
         (centered (make-mt-hcentered (list ch))))
    (is (typep centered 'mt-hlist))
    ;; Should have at least 3 children (glue, char, glue)
    (is (>= (length (mt-list-children centered)) 3))))

;;; ============================================================
;;; Section 3: Shipping (mt-ship)
;;; ============================================================

(def-suite ship-suite :in mathtext-suite :description "Ship box tree to output")

(test (ship-simple-hlist :suite ship-suite)
  "Shipping a simple hlist produces glyph output."
  (let* ((fl (get-test-font-loader))
         (c1 (make-mt-char #\x fl 12.0d0))
         (hlist (make-mt-hlist (list c1)))
         (output (mt-ship hlist)))
    (is (hash-table-p output))
    (is (listp (gethash :glyphs output)))
    ;; Should have at least one glyph
    (is (>= (length (gethash :glyphs output)) 1))
    ;; Width should be positive
    (is (> (gethash :width output) 0.0d0))))

(test (ship-multiple-chars :suite ship-suite)
  "Shipping multiple chars produces correct number of glyphs."
  (let* ((fl (get-test-font-loader))
         (chars (loop for ch across "abc"
                      collect (make-mt-char ch fl 12.0d0)))
         (hlist (make-mt-hlist chars))
         (output (mt-ship hlist)))
    ;; Should have glyphs for each character (plus maybe kern nodes counted)
    (is (>= (length (gethash :glyphs output)) 3))))

(test (ship-with-rule :suite ship-suite)
  "Shipping a hlist with a rule produces rect output."
  (let* ((rule (make-mt-rule 20.0d0 0.5d0 0.5d0))
         (hlist (make-mt-hlist (list rule) :do-kern nil))
         (output (mt-ship hlist)))
    ;; Rules appear in the rects list
    (is (hash-table-p output))))

;;; ============================================================
;;; Section 4: Lexer
;;; ============================================================

(def-suite lexer-suite :in mathtext-suite :description "Lexer tests")

(test (lex-simple-chars :suite lexer-suite)
  "Lexing simple characters."
  (let ((lex (make-mt-lexer "abc")))
    (let ((t1 (mt-lexer-advance lex)))
      (is (eq :char (mt-token-type t1)))
      (is (string= "a" (mt-token-value t1))))
    (let ((t2 (mt-lexer-advance lex)))
      (is (eq :char (mt-token-type t2)))
      (is (string= "b" (mt-token-value t2))))
    (let ((t3 (mt-lexer-advance lex)))
      (is (eq :char (mt-token-type t3)))
      (is (string= "c" (mt-token-value t3))))
    (let ((t4 (mt-lexer-peek lex)))
      (is (eq :eof (mt-token-type t4))))))

(test (lex-commands :suite lexer-suite)
  "Lexing TeX commands."
  (let ((lex (make-mt-lexer "\\alpha\\beta")))
    (let ((t1 (mt-lexer-advance lex)))
      (is (eq :command (mt-token-type t1)))
      (is (string= "\\alpha" (mt-token-value t1))))
    (let ((t2 (mt-lexer-advance lex)))
      (is (eq :command (mt-token-type t2)))
      (is (string= "\\beta" (mt-token-value t2))))))

(test (lex-braces :suite lexer-suite)
  "Lexing braces."
  (let ((lex (make-mt-lexer "{x}")))
    (is (eq :lbrace (mt-token-type (mt-lexer-advance lex))))
    (is (eq :char (mt-token-type (mt-lexer-advance lex))))
    (is (eq :rbrace (mt-token-type (mt-lexer-advance lex))))))

(test (lex-scripts :suite lexer-suite)
  "Lexing superscript and subscript."
  (let ((lex (make-mt-lexer "x^2_n")))
    (is (eq :char (mt-token-type (mt-lexer-advance lex))))       ;; x
    (is (eq :superscript (mt-token-type (mt-lexer-advance lex)))) ;; ^
    (is (eq :char (mt-token-type (mt-lexer-advance lex))))       ;; 2
    (is (eq :subscript (mt-token-type (mt-lexer-advance lex))))  ;; _
    (is (eq :char (mt-token-type (mt-lexer-advance lex))))))     ;; n

(test (lex-spacing-commands :suite lexer-suite)
  "Lexing spacing commands."
  (let ((lex (make-mt-lexer "\\, \\; \\quad")))
    (let ((t1 (mt-lexer-advance lex)))
      (is (eq :command (mt-token-type t1)))
      (is (string= "\\," (mt-token-value t1))))
    (let ((t2 (mt-lexer-advance lex)))
      (is (eq :command (mt-token-type t2)))
      (is (string= "\\;" (mt-token-value t2))))
    (let ((t3 (mt-lexer-advance lex)))
      (is (eq :command (mt-token-type t3)))
      (is (string= "\\quad" (mt-token-value t3))))))

(test (lex-frac :suite lexer-suite)
  "Lexing \\frac command with braced args."
  (let ((lex (make-mt-lexer "\\frac{a}{b}")))
    (is (eq :command (mt-token-type (mt-lexer-advance lex)))) ;; \frac
    (is (eq :lbrace (mt-token-type (mt-lexer-advance lex))))  ;; {
    (is (eq :char (mt-token-type (mt-lexer-advance lex))))    ;; a
    (is (eq :rbrace (mt-token-type (mt-lexer-advance lex))))  ;; }
    (is (eq :lbrace (mt-token-type (mt-lexer-advance lex))))  ;; {
    (is (eq :char (mt-token-type (mt-lexer-advance lex))))    ;; b
    (is (eq :rbrace (mt-token-type (mt-lexer-advance lex))))))  ;; }

;;; ============================================================
;;; Section 5: Parser
;;; ============================================================

(def-suite parser-suite :in mathtext-suite :description "Parser tests")

(test (parse-single-char :suite parser-suite)
  "Parsing a single character produces an Hlist."
  (let* ((fl (get-test-font-loader))
         (result (mt-parse "x" fl 12.0d0)))
    (is (typep result 'mt-hlist))
    (is (> (mt-box-width result) 0.0d0))
    (is (> (mt-box-height result) 0.0d0))))

(test (parse-multiple-chars :suite parser-suite)
  "Parsing multiple characters."
  (let* ((fl (get-test-font-loader))
         (result (mt-parse "abc" fl 12.0d0)))
    (is (typep result 'mt-hlist))
    (is (> (mt-box-width result) 0.0d0))))

(test (parse-superscript :suite parser-suite)
  "Parsing superscript x^2."
  (let* ((fl (get-test-font-loader))
         (result (mt-parse "x^2" fl 12.0d0)))
    (is (typep result 'mt-hlist))
    (is (> (mt-box-width result) 0.0d0))))

(test (parse-subscript :suite parser-suite)
  "Parsing subscript x_n."
  (let* ((fl (get-test-font-loader))
         (result (mt-parse "x_n" fl 12.0d0)))
    (is (typep result 'mt-hlist))
    (is (> (mt-box-width result) 0.0d0))))

(test (parse-both-scripts :suite parser-suite)
  "Parsing both super and subscript x^2_n."
  (let* ((fl (get-test-font-loader))
         (result (mt-parse "x^2_n" fl 12.0d0)))
    (is (typep result 'mt-hlist))
    (is (> (mt-box-width result) 0.0d0))))

(test (parse-group :suite parser-suite)
  "Parsing grouped expression {ab}."
  (let* ((fl (get-test-font-loader))
         (result (mt-parse "{ab}" fl 12.0d0)))
    (is (typep result 'mt-hlist))
    (is (> (mt-box-width result) 0.0d0))))

(test (parse-grouped-superscript :suite parser-suite)
  "Parsing x^{2n}."
  (let* ((fl (get-test-font-loader))
         (result (mt-parse "x^{2n}" fl 12.0d0)))
    (is (typep result 'mt-hlist))
    (is (> (mt-box-width result) 0.0d0))))

(test (parse-greek-letter :suite parser-suite)
  "Parsing Greek letter \\alpha."
  (let* ((fl (get-test-font-loader))
         (result (mt-parse "\\alpha" fl 12.0d0)))
    (is (typep result 'mt-hlist))
    (is (> (mt-box-width result) 0.0d0))))

(test (parse-multiple-greek :suite parser-suite)
  "Parsing multiple Greek letters."
  (let* ((fl (get-test-font-loader))
         (result (mt-parse "\\alpha+\\beta" fl 12.0d0)))
    (is (typep result 'mt-hlist))
    (is (> (mt-box-width result) 0.0d0))))

(test (parse-fraction :suite parser-suite)
  "Parsing \\frac{a}{b}."
  (let* ((fl (get-test-font-loader))
         (result (mt-parse "\\frac{a}{b}" fl 12.0d0)))
    (is (typep result 'mt-hlist))
    (is (> (mt-box-width result) 0.0d0))
    (is (> (mt-box-height result) 0.0d0))))

(test (parse-sqrt :suite parser-suite)
  "Parsing \\sqrt{x}."
  (let* ((fl (get-test-font-loader))
         (result (mt-parse "\\sqrt{x}" fl 12.0d0)))
    (is (typep result 'mt-hlist))
    (is (> (mt-box-width result) 0.0d0))))

(test (parse-operator-name :suite parser-suite)
  "Parsing operator names like \\sin, \\cos."
  (let* ((fl (get-test-font-loader))
         (result (mt-parse "\\sin x" fl 12.0d0)))
    (is (typep result 'mt-hlist))
    (is (> (mt-box-width result) 0.0d0))))

(test (parse-spacing :suite parser-suite)
  "Parsing spacing commands \\, \\; \\quad."
  (let* ((fl (get-test-font-loader))
         (result (mt-parse "a\\,b\\;c\\quad d" fl 12.0d0)))
    (is (typep result 'mt-hlist))
    (is (> (mt-box-width result) 0.0d0))))

(test (parse-complex-expression :suite parser-suite)
  "Parsing a complex expression: x^2 + y^2 = r^2."
  (let* ((fl (get-test-font-loader))
         (result (mt-parse "x^2 + y^2 = r^2" fl 12.0d0)))
    (is (typep result 'mt-hlist))
    (is (> (mt-box-width result) 0.0d0))))

(test (parse-nested-scripts :suite parser-suite)
  "Parsing nested superscripts e^{x^2}."
  (let* ((fl (get-test-font-loader))
         (result (mt-parse "e^{x^2}" fl 12.0d0)))
    (is (typep result 'mt-hlist))
    (is (> (mt-box-width result) 0.0d0))))

(test (parse-infty :suite parser-suite)
  "Parsing \\infty symbol."
  (let* ((fl (get-test-font-loader))
         (result (mt-parse "\\infty" fl 12.0d0)))
    (is (typep result 'mt-hlist))
    (is (> (mt-box-width result) 0.0d0))))

(test (parse-int-with-limits :suite parser-suite)
  "Parsing integral with limits \\int_0^\\infty."
  (let* ((fl (get-test-font-loader))
         (result (mt-parse "\\int_0^\\infty" fl 12.0d0)))
    (is (typep result 'mt-hlist))
    (is (> (mt-box-width result) 0.0d0))))

(test (parse-sum-expression :suite parser-suite)
  "Parsing \\sum_{i=1}^{n}."
  (let* ((fl (get-test-font-loader))
         (result (mt-parse "\\sum_{i=1}^{n}" fl 12.0d0)))
    (is (typep result 'mt-hlist))
    (is (> (mt-box-width result) 0.0d0))))

(test (parse-fraction-complex :suite parser-suite)
  "Parsing nested fraction \\frac{x^2+1}{x-1}."
  (let* ((fl (get-test-font-loader))
         (result (mt-parse "\\frac{x^2+1}{x-1}" fl 12.0d0)))
    (is (typep result 'mt-hlist))
    (is (> (mt-box-width result) 0.0d0))))

(test (parse-empty-group :suite parser-suite)
  "Parsing empty group {} doesn't crash."
  (let* ((fl (get-test-font-loader))
         (result (mt-parse "{}" fl 12.0d0)))
    (is (typep result 'mt-hlist))))

;;; ============================================================
;;; Section 6: Dollar-sign math strings
;;; ============================================================

(def-suite dollar-suite :in mathtext-suite :description "Dollar-sign delimited math")

(test (mathtext-p-detection :suite dollar-suite)
  "mathtext-p detects dollar signs."
  (is (eq t (not (null (mathtext-p "$x^2$")))))
  (is (eq t (not (null (mathtext-p "$\\alpha$")))))
  (is (null (mathtext-p "plain text")))
  (is (null (mathtext-p "x")))
  (is (null (mathtext-p ""))))

(test (parse-dollar-wrapped :suite dollar-suite)
  "Parsing dollar-sign wrapped expression."
  (let* ((fl (get-test-font-loader))
         (result (mt-parse-math-string "$x^2$" fl 12.0d0)))
    (is (typep result 'mt-hlist))
    (is (> (mt-box-width result) 0.0d0))))

(test (parse-plain-text :suite dollar-suite)
  "Plain text (no dollars) renders as roman text."
  (let* ((fl (get-test-font-loader))
         (result (mt-parse-math-string "Hello" fl 12.0d0)))
    (is (typep result 'mt-hlist))
    (is (> (mt-box-width result) 0.0d0))))

;;; ============================================================
;;; Section 7: mathtext-to-path integration
;;; ============================================================

(def-suite integration-suite :in mathtext-suite :description "Full integration tests")

(test (mathtext-to-path-simple :suite integration-suite)
  "mathtext-to-path produces paths for simple expression."
  (let ((fl (get-test-font-loader)))
    (multiple-value-bind (paths width height depth)
        (mathtext-to-path "$x$" fl 12.0d0)
      (is (listp paths))
      (is (> (length paths) 0))
      (is (> width 0.0d0))
      (is (> height 0.0d0))
      (is (numberp depth)))))

(test (mathtext-to-path-superscript :suite integration-suite)
  "mathtext-to-path handles superscripts."
  (let ((fl (get-test-font-loader)))
    (multiple-value-bind (paths width height depth)
        (mathtext-to-path "$x^2$" fl 12.0d0)
      (declare (ignore depth))
      (is (> (length paths) 0))
      (is (> width 0.0d0))
      (is (> height 0.0d0)))))

(test (mathtext-to-path-greek :suite integration-suite)
  "mathtext-to-path renders Greek letters."
  (let ((fl (get-test-font-loader)))
    (multiple-value-bind (paths width height depth)
        (mathtext-to-path "$\\pi$" fl 12.0d0)
      (declare (ignore depth))
      (is (> (length paths) 0))
      (is (> width 0.0d0))
      (is (> height 0.0d0)))))

(test (mathtext-to-path-complex :suite integration-suite)
  "mathtext-to-path handles complex expressions."
  (let ((fl (get-test-font-loader)))
    (multiple-value-bind (paths width height depth)
        (mathtext-to-path "$x^2 + y^2 = r^2$" fl 12.0d0)
      (declare (ignore depth))
      (is (> (length paths) 0))
      (is (> width 0.0d0))
      (is (> height 0.0d0)))))

(test (mathtext-to-compound-path-works :suite integration-suite)
  "mathtext-to-compound-path returns a single path."
  (let ((fl (get-test-font-loader)))
    (multiple-value-bind (path width height depth)
        (mathtext-to-compound-path "$x^2$" fl 12.0d0)
      (declare (ignore depth))
      (is (typep path 'cl-matplotlib.primitives:mpl-path))
      (is (> width 0.0d0))
      (is (> height 0.0d0)))))

(test (mathtext-get-dimensions-works :suite integration-suite)
  "mathtext-get-dimensions returns dimensions."
  (let ((fl (get-test-font-loader)))
    (multiple-value-bind (width height depth)
        (mathtext-get-dimensions "$x^2$" fl 12.0d0)
      (is (> width 0.0d0))
      (is (> height 0.0d0))
      (is (numberp depth)))))

(test (mathtext-to-path-fraction :suite integration-suite)
  "mathtext-to-path handles fractions."
  (let ((fl (get-test-font-loader)))
    (multiple-value-bind (paths width height depth)
        (mathtext-to-path "$\\frac{a}{b}$" fl 12.0d0)
      (declare (ignore depth))
      (is (> (length paths) 0))
      (is (> width 0.0d0))
      (is (> height 0.0d0)))))

(test (mathtext-to-path-sqrt :suite integration-suite)
  "mathtext-to-path handles square root."
  (let ((fl (get-test-font-loader)))
    (multiple-value-bind (paths width height depth)
        (mathtext-to-path "$\\sqrt{x}$" fl 12.0d0)
      (declare (ignore depth))
      (is (> (length paths) 0))
      (is (> width 0.0d0))
      (is (> height 0.0d0)))))

(test (mathtext-to-path-integral :suite integration-suite)
  "mathtext-to-path handles integral expression."
  (let ((fl (get-test-font-loader)))
    (multiple-value-bind (paths width height depth)
        (mathtext-to-path "$\\int_0^\\infty e^{-x^2} dx$" fl 12.0d0)
      (declare (ignore depth))
      (is (> (length paths) 0))
      (is (> width 0.0d0))
      (is (> height 0.0d0)))))

;;; ============================================================
;;; Section 8: Edge cases
;;; ============================================================

(def-suite edge-cases-suite :in mathtext-suite :description "Edge case tests")

(test (parse-empty-string :suite edge-cases-suite)
  "Parsing empty string doesn't crash."
  (let* ((fl (get-test-font-loader))
         (result (mt-parse "" fl 12.0d0)))
    (is (not (null result)))))

(test (parse-single-digit :suite edge-cases-suite)
  "Parsing a single digit."
  (let* ((fl (get-test-font-loader))
         (result (mt-parse "5" fl 12.0d0)))
    (is (typep result 'mt-hlist))
    (is (> (mt-box-width result) 0.0d0))))

(test (mathtext-p-edge-cases :suite edge-cases-suite)
  "mathtext-p edge cases."
  (is (null (mathtext-p nil)))
  (is (null (mathtext-p 42)))
  (is (null (mathtext-p "$"))))  ;; Single dollar — not valid math

(test (parse-font-commands :suite edge-cases-suite)
  "Font change commands work."
  (let* ((fl (get-test-font-loader))
         (result (mt-parse "\\mathrm{x}" fl 12.0d0)))
    (is (typep result 'mt-hlist))
    (is (> (mt-box-width result) 0.0d0))))

(test (large-fontsize :suite edge-cases-suite)
  "Large fontsize doesn't crash."
  (let* ((fl (get-test-font-loader))
         (result (mt-parse "x" fl 72.0d0)))
    (is (typep result 'mt-hlist))
    (is (> (mt-box-width result) 0.0d0))))

(test (small-fontsize :suite edge-cases-suite)
  "Small fontsize doesn't crash."
  (let* ((fl (get-test-font-loader))
         (result (mt-parse "x" fl 4.0d0)))
    (is (typep result 'mt-hlist))
    (is (> (mt-box-width result) 0.0d0))))

(test (parse-pi-plus-expression :suite edge-cases-suite)
  "Parse \\pi r^2."
  (let* ((fl (get-test-font-loader))
         (result (mt-parse "\\pi r^2" fl 12.0d0)))
    (is (typep result 'mt-hlist))
    (is (> (mt-box-width result) 0.0d0))))
