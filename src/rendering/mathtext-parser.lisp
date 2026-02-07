;;;; mathtext-parser.lisp — Recursive-descent parser for TeX math syntax
;;;; Ported from matplotlib's _mathtext.py Parser class
;;;; Implements a hand-written recursive-descent parser (not pyparsing).

(in-package #:cl-matplotlib.rendering)

;;; ============================================================
;;; Token types for the lexer
;;; ============================================================

(defstruct (mt-token (:constructor make-mt-token (type value &optional position)))
  "A lexer token."
  (type     :eof :type keyword)
  (value    ""   :type t)
  (position 0    :type fixnum))

;;; ============================================================
;;; Lexer — tokenize TeX math input
;;; ============================================================

(defclass mt-lexer ()
  ((input    :initarg :input    :accessor mt-lexer-input)
   (pos      :initform 0        :accessor mt-lexer-pos)
   (tokens   :initform nil      :accessor mt-lexer-tokens)
   (tok-pos  :initform 0        :accessor mt-lexer-tok-pos))
  (:documentation "Tokenizer for TeX math expressions."))

(defun %mt-lex-all (input)
  "Tokenize the entire INPUT string into a list of tokens."
  (let ((tokens nil)
        (pos 0)
        (len (length input)))
    (flet ((peek () (when (< pos len) (char input pos)))
           (advance () (prog1 (char input pos) (incf pos)))
           (make-tok (type value p) (push (make-mt-token type value p) tokens)))
      (loop while (< pos len)
            for ch = (peek)
            do (cond
                 ;; Whitespace — skip
                 ((member ch '(#\Space #\Tab #\Newline))
                  (advance))
                 ;; Backslash commands
                 ((char= ch #\\)
                  (let ((start pos))
                    (advance) ;; skip backslash
                    (cond
                      ;; End of input after backslash
                      ((>= pos len)
                       (make-tok :command "\\" start))
                      ;; Single special char commands: \, \: \; \! \  \{ \} \# \$ \% \& \_
                      ((member (peek) '(#\, #\: #\; #\! #\Space #\{ #\} #\# #\$ #\% #\& #\_))
                       (let ((c (advance)))
                         (make-tok :command (format nil "\\~A" c) start)))
                      ;; Alphabetic command: \alpha, \frac, etc.
                      ((alpha-char-p (peek))
                       (let ((cmd-start pos))
                         (loop while (and (< pos len) (alpha-char-p (peek)))
                               do (advance))
                         (make-tok :command
                                   (format nil "\\~A" (subseq input cmd-start pos))
                                   start)))
                      ;; Any other char after backslash
                      (t
                       (let ((c (advance)))
                         (make-tok :command (format nil "\\~A" c) start))))))
                 ;; Grouping
                 ((char= ch #\{) (advance) (make-tok :lbrace "{" (1- pos)))
                 ((char= ch #\}) (advance) (make-tok :rbrace "}" (1- pos)))
                 ;; Super/subscript
                 ((char= ch #\^) (advance) (make-tok :superscript "^" (1- pos)))
                 ((char= ch #\_) (advance) (make-tok :subscript "_" (1- pos)))
                 ;; Regular characters (letters, digits, operators, etc.)
                 (t
                  (advance)
                  (make-tok :char (string ch) (1- pos))))))
    (push (make-mt-token :eof "" pos) tokens)
    (nreverse tokens)))

(defun make-mt-lexer (input)
  "Create a lexer for INPUT and tokenize it."
  (let ((lex (make-instance 'mt-lexer :input input)))
    (setf (mt-lexer-tokens lex) (%mt-lex-all input)
          (mt-lexer-tok-pos lex) 0)
    lex))

(defun mt-lexer-peek (lexer)
  "Peek at the current token."
  (nth (mt-lexer-tok-pos lexer) (mt-lexer-tokens lexer)))

(defun mt-lexer-advance (lexer)
  "Consume and return the current token."
  (prog1 (mt-lexer-peek lexer)
    (when (< (mt-lexer-tok-pos lexer) (1- (length (mt-lexer-tokens lexer))))
      (incf (mt-lexer-tok-pos lexer)))))

(defun mt-lexer-expect (lexer type)
  "Consume a token of the expected TYPE, or signal error."
  (let ((tok (mt-lexer-peek lexer)))
    (if (eq (mt-token-type tok) type)
        (mt-lexer-advance lexer)
        (error "Mathtext parse error at position ~D: expected ~A, got ~A (~A)"
               (mt-token-position tok) type (mt-token-type tok) (mt-token-value tok)))))

;;; ============================================================
;;; Parser State
;;; ============================================================

(defclass mt-parser-state ()
  ((font-loader :initarg :font-loader :accessor mt-ps-font-loader)
   (fontsize    :initarg :fontsize    :accessor mt-ps-fontsize)
   (font-style  :initarg :font-style  :initform :it :accessor mt-ps-font-style
                :documentation ":it (italic, for variables), :rm (roman, for operators)"))
  (:documentation "Parser state tracking font settings."))

(defun mt-ps-copy (state)
  "Copy parser state."
  (make-instance 'mt-parser-state
                 :font-loader (mt-ps-font-loader state)
                 :fontsize (mt-ps-fontsize state)
                 :font-style (mt-ps-font-style state)))

;;; ============================================================
;;; Parser — Recursive-descent TeX math parser
;;; ============================================================

(defclass mt-parser ()
  ((lexer :initarg :lexer :accessor mt-parser-lexer)
   (state :initarg :state :accessor mt-parser-state))
  (:documentation "Recursive-descent parser for TeX math syntax."))

(defun make-mt-parser (input font-loader fontsize)
  "Create a parser for INPUT string."
  (make-instance 'mt-parser
                 :lexer (make-mt-lexer input)
                 :state (make-instance 'mt-parser-state
                                       :font-loader font-loader
                                       :fontsize (float fontsize 1.0d0))))

;;; ============================================================
;;; Parser methods — Grammar production rules
;;; ============================================================

;; Grammar:
;;   expression = atom (superscript | subscript)*
;;   atom = char | command | group
;;   group = '{' expression* '}'
;;   superscript = '^' atom
;;   subscript = '_' atom
;;   command = '\frac' group group
;;           | '\sqrt' group
;;           | '\operatorname' group
;;           | greek/symbol/spacing command

(defun mt-parse-expression (parser)
  "Parse a full math expression, returning an Hlist."
  (let ((elements nil))
    (loop
      (let ((tok (mt-lexer-peek (mt-parser-lexer parser))))
        (case (mt-token-type tok)
          ((:eof :rbrace)
           (return))
          (otherwise
           (let ((atom (mt-parse-atom-with-scripts parser)))
             (when atom
               (if (listp atom)
                   (setf elements (append elements atom))
                   (push atom elements))))))))
    (if elements
        (make-mt-hlist (if (every #'listp elements)
                           (apply #'append elements)
                           (reverse
                            (loop for e in elements
                                  if (listp e) append (reverse e)
                                  else collect e))))
        (make-mt-hbox 0.0d0))))

(defun mt-parse-atom-with-scripts (parser)
  "Parse an atom followed by optional superscripts and subscripts."
  (let ((nucleus (mt-parse-atom parser)))
    (when (null nucleus)
      (return-from mt-parse-atom-with-scripts nil))
    (let ((super-node nil)
          (sub-node nil))
      ;; Check for super/subscripts (can appear in either order)
      (loop
        (let ((tok (mt-lexer-peek (mt-parser-lexer parser))))
          (case (mt-token-type tok)
            (:superscript
             (mt-lexer-advance (mt-parser-lexer parser))
             (setf super-node (mt-parse-atom parser)))
            (:subscript
             (mt-lexer-advance (mt-parser-lexer parser))
             (setf sub-node (mt-parse-atom parser)))
            (otherwise
             (return)))))
      (if (or super-node sub-node)
          (mt-build-script-node parser nucleus super-node sub-node)
          nucleus))))

(defun mt-parse-atom (parser)
  "Parse a single atom: character, command, or group."
  (let ((tok (mt-lexer-peek (mt-parser-lexer parser))))
    (case (mt-token-type tok)
      (:char
       (mt-lexer-advance (mt-parser-lexer parser))
       (mt-build-char parser (mt-token-value tok)))
      (:command
       (mt-parse-command parser))
      (:lbrace
       (mt-parse-group parser))
      (otherwise
       nil))))

(defun mt-parse-group (parser)
  "Parse a brace-delimited group: { expression }."
  (mt-lexer-expect (mt-parser-lexer parser) :lbrace)
  (let ((state (mt-ps-copy (mt-parser-state parser))))
    (prog1
        (mt-parse-expression parser)
      (mt-lexer-expect (mt-parser-lexer parser) :rbrace)
      ;; Restore state
      (setf (mt-parser-state parser) state))))

(defun mt-parse-command (parser)
  "Parse a TeX command: \\alpha, \\frac{}{}, \\sqrt{}, etc."
  (let* ((tok (mt-lexer-advance (mt-parser-lexer parser)))
         (cmd (mt-token-value tok))
         (name (subseq cmd 1))) ;; strip leading backslash
    (cond
      ;; Fraction: \frac{num}{den}
      ((string= name "frac")
       (mt-parse-frac parser))
      ;; Square root: \sqrt{content}
      ((string= name "sqrt")
       (mt-parse-sqrt parser))
      ;; Font commands
      ((string= name "mathrm")
       (mt-parse-font-change parser :rm))
      ((string= name "mathit")
       (mt-parse-font-change parser :it))
      ((string= name "mathbf")
       (mt-parse-font-change parser :bf))
      ((or (string= name "rm") (string= name "textrm"))
       (mt-parse-font-change parser :rm))
      ((or (string= name "it") (string= name "textit"))
       (mt-parse-font-change parser :it))
      ((or (string= name "bf") (string= name "textbf"))
       (mt-parse-font-change parser :bf))
      ;; Spacing commands
      ((string= name ",")  (make-mt-kern (* +thin-space+ (mt-ps-fontsize (mt-parser-state parser)))))
      ((string= name ":")  (make-mt-kern (* +medium-space+ (mt-ps-fontsize (mt-parser-state parser)))))
      ((string= name ";")  (make-mt-kern (* +thick-space+ (mt-ps-fontsize (mt-parser-state parser)))))
      ((string= name "!")  (make-mt-kern (- (* +thin-space+ (mt-ps-fontsize (mt-parser-state parser))))))
      ((string= name " ")  (make-mt-kern (* +medium-space+ (mt-ps-fontsize (mt-parser-state parser)))))
      ((string= name "quad")  (make-mt-kern (* +quad-space+ (mt-ps-fontsize (mt-parser-state parser)))))
      ((string= name "qquad") (make-mt-kern (* +qquad-space+ (mt-ps-fontsize (mt-parser-state parser)))))
      ;; Escaped characters
      ((string= name "{") (mt-build-char parser "{"))
      ((string= name "}") (mt-build-char parser "}"))
      ((string= name "#") (mt-build-char parser "#"))
      ((string= name "$") (mt-build-char parser "$"))
      ((string= name "%") (mt-build-char parser "%"))
      ((string= name "&") (mt-build-char parser "&"))
      ((string= name "_") (mt-build-char parser "_"))
      ((string= name "backslash") (mt-build-char parser "\\"))
      ;; Operator names (rendered upright)
      ((operator-name-p name)
       (mt-build-operator-name parser name))
      ;; Greek letters and symbols — look up in tex2uni
      ((gethash name *tex2uni*)
       (let ((code (gethash name *tex2uni*)))
         (if code
             (mt-build-symbol parser (code-char code) name)
             ;; If mapped to nil, it's an operator name
             (mt-build-operator-name parser name))))
      ;; Unknown command — render as text
      (t
       (mt-build-operator-name parser name)))))

(defun mt-parse-frac (parser)
  "Parse \\frac{numerator}{denominator} and build a fraction box."
  (let ((num (mt-parse-group parser))
        (den (mt-parse-group parser)))
    (mt-build-fraction parser num den)))

(defun mt-parse-sqrt (parser)
  "Parse \\sqrt{content} and build a square root box."
  (let ((content (mt-parse-group parser)))
    (mt-build-sqrt parser content)))

(defun mt-parse-font-change (parser style)
  "Parse a font change command: \\mathrm{...}, etc."
  (let ((saved-style (mt-ps-font-style (mt-parser-state parser))))
    (setf (mt-ps-font-style (mt-parser-state parser)) style)
    (prog1 (mt-parse-group parser)
      (setf (mt-ps-font-style (mt-parser-state parser)) saved-style))))

;;; ============================================================
;;; Node builders — create layout nodes from parsed elements
;;; ============================================================

(defun mt-build-char (parser text)
  "Build a character node for TEXT (a string containing one character)."
  (let* ((state (mt-parser-state parser))
         (fl (mt-ps-font-loader state))
         (fs (mt-ps-fontsize state))
         (ch (if (= (length text) 1) (char text 0) #\?))
         ;; Variables in italic by default, digits/operators in roman
         (italic-p (and (eq (mt-ps-font-style state) :it)
                        (alpha-char-p ch)
                        (not (digit-char-p ch)))))
    (make-mt-char ch fl fs :italic-p italic-p)))

(defun mt-build-symbol (parser char name)
  "Build a symbol node (Greek letter, operator symbol, etc.)."
  (declare (ignore name))
  (let* ((state (mt-parser-state parser))
         (fl (mt-ps-font-loader state))
         (fs (mt-ps-fontsize state)))
    (make-mt-char char fl fs :italic-p nil)))

(defun mt-build-operator-name (parser name)
  "Build a node for a named operator like 'lim', 'sin', etc.
Rendered as upright (roman) text."
  (let* ((state (mt-parser-state parser))
         (fl (mt-ps-font-loader state))
         (fs (mt-ps-fontsize state))
         (chars (loop for ch across name
                      collect (make-mt-char ch fl fs :italic-p nil))))
    (make-mt-hlist chars)))

(defun mt-build-script-node (parser nucleus super-node sub-node)
  "Build a superscript/subscript node around NUCLEUS."
  (let* ((state (mt-parser-state parser))
         (fs (mt-ps-fontsize state))
         (result-elements nil))
    ;; Nucleus first
    (push nucleus result-elements)
    ;; Handle superscript
    (when super-node
      ;; Shrink the superscript content
      (mt-node-shrink super-node)
      ;; Shift up
      (let ((sup-shift (* fs +sup1+))
            (kern (make-mt-kern (* fs +script-space+))))
        (when (typep super-node 'mt-list)
          (setf (mt-list-shift-amount super-node) (- sup-shift)))
        ;; Create a vlist with the superscript shifted up
        ;; Actually, for horizontal layout, we use shift_amount on an hlist
        (let ((sup-hlist (if (typep super-node 'mt-hlist)
                             super-node
                             (make-mt-hlist (list super-node) :do-kern nil))))
          (setf (mt-list-shift-amount sup-hlist) (- sup-shift))
          (push kern result-elements)
          (push sup-hlist result-elements))))
    ;; Handle subscript
    (when sub-node
      ;; Shrink the subscript content
      (mt-node-shrink sub-node)
      ;; Shift down
      (let ((sub-shift (* fs +sub1+))
            (kern (make-mt-kern (* fs +script-space+))))
        (when (typep sub-node 'mt-list)
          (setf (mt-list-shift-amount sub-node) sub-shift))
        (let ((sub-hlist (if (typep sub-node 'mt-hlist)
                             sub-node
                             (make-mt-hlist (list sub-node) :do-kern nil))))
          (setf (mt-list-shift-amount sub-hlist) sub-shift)
          ;; If we also had a superscript, add back-kern to overlap horizontally
          (when super-node
            (let* ((nuc-width (typecase nucleus
                                (mt-char (mt-char-width nucleus))
                                (mt-box (mt-box-width nucleus))
                                (t 0.0d0)))
                   (sup-width (if (typep (car (cdr result-elements)) 'mt-list)
                                  (mt-box-width (car (cdr result-elements)))
                                  0.0d0))
                   (back-kern (- (+ sup-width (* fs +script-space+)))))
              (declare (ignore nuc-width))
              (push (make-mt-kern back-kern) result-elements)))
          (push kern result-elements)
          (push sub-hlist result-elements))))
    (make-mt-hlist (nreverse result-elements) :do-kern nil)))

(defun mt-build-fraction (parser num-box den-box)
  "Build a fraction node with NUM-BOX over DEN-BOX."
  (let* ((state (mt-parser-state parser))
         (fs (mt-ps-fontsize state))
         (rule-thickness (* fs +fraction-rule-thickness+))
         (num-vgap (* fs +fraction-num-vgap+))
         (den-vgap (* fs +fraction-denom-vgap+))
         ;; Get dimensions
         (num-width (mt-box-width num-box))
         (num-height (mt-box-height num-box))
         (num-depth (mt-box-depth num-box))
         (den-width (mt-box-width den-box))
         (den-height (mt-box-height den-box))
         (den-depth (mt-box-depth den-box))
         ;; Overall width is the wider of num and den
         (width (max num-width den-width))
         ;; Center both
         (num-shift (/ (- width num-width) 2.0d0))
         (den-shift (/ (- width den-width) 2.0d0))
         ;; Build the fraction bar
         (rule (make-mt-rule width (* rule-thickness 0.5d0) (* rule-thickness 0.5d0)))
         ;; Kern above and below the bar
         (num-kern (make-mt-kern (+ num-vgap (* rule-thickness 0.5d0))))
         (den-kern (make-mt-kern (+ den-vgap (* rule-thickness 0.5d0)))))
    ;; Center the numerator
    (when (/= num-shift 0.0d0)
      (when (typep num-box 'mt-list)
        (setf (mt-list-shift-amount num-box) num-shift)))
    ;; Center the denominator
    (when (/= den-shift 0.0d0)
      (when (typep den-box 'mt-list)
        (setf (mt-list-shift-amount den-box) den-shift)))
    ;; Build vertical list: numerator, gap, rule, gap, denominator
    (let ((vlist (make-mt-vlist (list num-box num-kern rule den-kern den-box))))
      ;; Shift the vlist so the fraction bar sits at the math axis
      ;; (approximately half x-height above baseline)
      (let ((axis-height (* fs 0.25d0))
            (total-above-bar (+ num-height num-depth (glue-spec-width (make-glue-spec (+ num-vgap (* rule-thickness 0.5d0)) 0.0d0 0 0.0d0 0)))))
        (declare (ignore total-above-bar))
        (setf (mt-list-shift-amount vlist) 0.0d0)
        ;; Adjust so bar is at axis height
        ;; The vlist's natural height places the top at the top
        ;; We need the bar centered at axis-height
        (let* ((bar-center (+ num-height num-depth num-vgap (* rule-thickness 0.5d0)))
               (shift (- bar-center axis-height (mt-box-height vlist))))
          (declare (ignore shift))
          ;; Simplified: use the hlist wrapper with shift
          (let ((wrapper (make-mt-hlist (list vlist) :do-kern nil)))
            ;; Position fraction so rule is at math axis
            (setf (mt-list-shift-amount vlist)
                  (- (- (mt-box-height vlist)
                        (+ num-height num-depth num-vgap (* rule-thickness 0.5d0)))
                     axis-height))
            wrapper))))))

(defun mt-build-sqrt (parser content-box)
  "Build a square root node around CONTENT-BOX."
  (let* ((state (mt-parser-state parser))
         (fs (mt-ps-fontsize state))
         (fl (mt-ps-font-loader state))
         (rule-thickness (* fs +sqrt-rule-thickness+))
         (vgap (* fs +sqrt-vgap+))
         ;; Build the radical sign
         (sqrt-char (make-mt-char (code-char #x221a) fl fs))
         ;; Content dimensions
         (content-height (mt-box-height content-box))
         (content-depth (mt-box-depth content-box))
         (content-width (mt-box-width content-box))
         ;; The bar on top
         (bar (make-mt-rule content-width (* rule-thickness 0.5d0) (* rule-thickness 0.5d0)))
         ;; Gap between content and bar
         (gap-kern (make-mt-kern vgap)))
    (declare (ignore content-height content-depth))
    ;; Build: sqrt-sign + vlist(bar, gap, content)
    (let* ((inner-vlist (make-mt-vlist (list bar gap-kern content-box)))
           (result (make-mt-hlist (list sqrt-char inner-vlist) :do-kern nil)))
      result)))

;;; ============================================================
;;; Top-level parse function
;;; ============================================================

(defun mt-parse (input font-loader fontsize)
  "Parse a TeX math expression and return an Hlist box tree.
INPUT is the math expression (without dollar signs).
FONT-LOADER is a zpb-ttf font-loader.
FONTSIZE is the font size in points.
Returns an mt-hlist representing the parsed expression."
  (let ((parser (make-mt-parser input font-loader fontsize)))
    (mt-parse-expression parser)))

(defun mt-parse-math-string (input font-loader fontsize)
  "Parse a string that may contain dollar-sign delimited math.
Returns an mt-hlist. Non-math text is rendered in roman style.
Math text ($...$) is parsed as TeX."
  (let ((len (length input))
        (elements nil)
        (pos 0))
    (if (= len 0)
        (make-mt-hbox 0.0d0)
        (progn
          ;; Check for $...$ wrapping
          (if (and (>= len 2)
                   (char= (char input 0) #\$)
                   (char= (char input (1- len)) #\$))
              ;; Entire string is math
              (mt-parse (subseq input 1 (1- len)) font-loader fontsize)
              ;; Mix of text and math — for now, parse as all math if no $ found,
              ;; or as text with embedded math
              (let ((dollar-pos (position #\$ input)))
                (if (null dollar-pos)
                    ;; No math — just render as text
                    (let ((state (make-instance 'mt-parser-state
                                                :font-loader font-loader
                                                :fontsize (float fontsize 1.0d0)
                                                :font-style :rm)))
                      (loop for ch across input
                            collect (make-mt-char ch font-loader fontsize :italic-p nil)
                              into chars
                            finally (return (make-mt-hlist chars))))
                    ;; Mixed: parse segments
                    (progn
                      (loop while (< pos len)
                            do (let ((next-dollar (position #\$ input :start pos)))
                                 (if next-dollar
                                     (progn
                                       ;; Text before $
                                       (when (> next-dollar pos)
                                         (let ((text (subseq input pos next-dollar)))
                                           (loop for ch across text
                                                 do (push (make-mt-char ch font-loader fontsize
                                                                        :italic-p nil)
                                                          elements))))
                                       ;; Find closing $
                                       (let ((end-dollar (position #\$ input :start (1+ next-dollar))))
                                         (if end-dollar
                                             (let* ((math-str (subseq input (1+ next-dollar) end-dollar))
                                                    (math-box (mt-parse math-str font-loader fontsize)))
                                               (push math-box elements)
                                               (setf pos (1+ end-dollar)))
                                             ;; No closing $ — treat rest as text
                                             (progn
                                               (loop for ch across (subseq input next-dollar)
                                                     do (push (make-mt-char ch font-loader fontsize
                                                                            :italic-p nil)
                                                              elements))
                                               (setf pos len)))))
                                     ;; No more $ signs — rest is text
                                     (progn
                                       (loop for ch across (subseq input pos)
                                             do (push (make-mt-char ch font-loader fontsize
                                                                    :italic-p nil)
                                                      elements))
                                       (setf pos len)))))
                      (make-mt-hlist (nreverse elements) :do-kern t)))))))))
