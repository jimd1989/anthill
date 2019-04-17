(import 
  (chicken file)
  (chicken file posix)
  (chicken fixnum)
  (chicken process)
  (chicken process-context)
  (chicken sort)
  srfi-1
  srfi-69 
  typed-records)

; /* typedefs */
(define-type file (struct file))
(define-type ul (struct ul))

; /* types */
(define-type template (list-of (or string symbol)))
(define-type li (list symbol boolean string string))
(define-type ul-segment (or null (list-of (or string li))))
(define-type flat-ul (list-of (or string li)))

; /* structs */
(define-record file
  (name : string)
  (path : string)
  (output : string)
  (url : string)
  (directory? : boolean)
  (top-level? : boolean))

(define-record ul
  (head : ul-segment)
  (current : ul-segment)
  (foot : ul-segment))

; /* site settings from command-line arguments */
(: SETTINGS hash-table)
(define SETTINGS (make-hash-table #:size 10))

(for-each
  (lambda (x) (hash-table-set! SETTINGS x ""))
  '(name input output css inline-css hidden delimiter url minify markdown))

(define-syntax set?
  (syntax-rules ()
    ((_ x) (fx> (string-length (hash-table-ref SETTINGS 'x)) 0))))

(define-syntax opt
  (syntax-rules () ((_ x) (hash-table-ref SETTINGS 'x))))

(: arg->key (string --> symbol))
(define (arg->key arg)
  (if (fx> (string-length arg) 1)
    (string->symbol (substring arg 1 (string-length arg)))
    'failure))

(: assign-parameters ((list-of string) -> boolean))
(define (assign-parameters args)
  (if (not (null? args))
    (let ((key (arg->key (car args))))
      (cond ((not (hash-table-exists? SETTINGS key))
	     (error (string-append "Invalid parameter:" (car args))))
	    (else
	      (hash-table-set! SETTINGS key (cadr args))
	      (assign-parameters (cddr args)))))
    #t))

; /* HTML templating takes the form of a flattened list of strings and
;  * symbols, generated from the macros below. A _ symbol in the body of a
;  * template indicates a newline that will only be engaged if the
;  * minify setting is disabled. A ! symbol indicates a Scheme variable
;  * that needs to be printed. This variable is stored in a closure of type
;  * (lambda (output-port) (f variable output-port)) that is evaluated when
;  * (write-html template output-port . variable-procedures) is called. */

(: _ symbol)
(define _ '_)

(: ! symbol)
(define ! '!)

(define-syntax html
  (syntax-rules () ((_ xs ...) (flatten (list xs ...)))))

(define-syntax space
  (syntax-rules () ((_ xs ... y) (list (list xs " ") ... y))))

(define-syntax q
  (syntax-rules () ((_ xs ...) (list "\"" (space xs ...) "\""))))

(define-syntax qno
  (syntax-rules () ((_ xs ...) (list "\"" xs ... "\""))))

(define-syntax b
  (syntax-rules () ((_ xs ...) (list "<" (space xs ...) ">"))))

(define-syntax bno
  (syntax-rules () ((_ xs ...) (list "<" xs ... ">"))))

(define-syntax eq
  (syntax-rules () ((_ x xs ...) (list x "=" (q xs ...)))))

(define-syntax end
  (syntax-rules () ((_ x) (bno '/ x))))

(define-syntax id
  (syntax-rules () ((_ x y) (b x (eq 'id y)))))

(: displays (output-port #!rest (or template string symbol) -> noreturn))
(define (displays port . xs)
  (for-each (lambda (x) (display x port)) xs))

(define-syntax write-var
  (syntax-rules () ((_ xs ... ) (lambda (port) (displays port xs ...)))))

; /* templates */
(: HEAD template)
(define HEAD
  (html (b 'html) _ (b 'head) _ 
	(b 'meta (eq 'name 'viewport) (eq 'content 'width=device-width)
	   'initial-scale=1.0 'maximum-scale=12.0 'user-scalable=yes) _
	(b 'meta (eq 'http-equiv 'Content-Type)
	   (eq 'content "text/html;" 'charset=UTF-8)) _ ! _ ! _ (end 'head) _))

(: INLINE-CSS template)
(define INLINE-CSS
  (html (b 'style) ! (end 'style)))

(: LINKED-CSS template)
(define LINKED-CSS
  (html (b 'link (eq 'rel 'stylesheet) (eq 'href !))))

(: TITLE template)
(define TITLE
  (html (b 'title) ! ! (end 'title)))

(: BANNER template)
(define BANNER
  (html (id 'div 'banner) (b 'a (eq 'href !)) (id 'span 'sitename) !(end 'span)
	(id 'span 'delimiter) ! (end 'span) (id 'span 'pagename) ! (end 'span)
	(end 'a) (end 'div) _))

(: LI template)
(define LI
  (html (b 'li (eq 'class !)) (bno 'a " href=" (qno ! ! ".html")) ! ! (end 'a)
	(end 'li) _))

(: UL template)
(define UL
  (html ! _))

(: TOGGLE template)
(define TOGGLE
  (html (id 'div 'toggle) (b 'a (eq 'href "#nav")) ! (end 'a) (end 'div) _))

(: NAV template)
(define NAV
  (html (b 'body) ! (b 'div (eq 'class 'expand) (eq 'id 'nav))_ !(end 'div) _))

(: BODY template)
(define BODY
  (html (id 'div 'main) (b 'body) ! (end 'div) (end 'body) (end 'html)))

; /* li and ul */
(: make-li (boolean string string --> li))
(define (make-li dir? path name)
  (list 'unpath dir? path name))

(: activate-li (li --> li))
(define (activate-li li)
  (cons 'path (cdr li)))

(: li? (any --> boolean))
(define (li? x)
  (list? x))

(: li-dir? (li --> boolean))
(define (li-dir? li)
  (cadr li))

(: directory-file? (li --> boolean))
(define (directory-file? li)
  (char=? (string-ref (cadddr li) 0) #\space))

(: UL-OPEN string)
(define UL-OPEN (apply string-append (bno "ul")))

(: UL-CLOSE string)
(define UL-CLOSE (apply string-append (bno "/" "ul")))

(: make-lis ((list-of file) --> ul-segment))
(define (make-lis files)
  (cons UL-OPEN
	(append (map (lambda (x) (make-li (file-directory? x) (file-url x)
					  (file-name x)))
		     files)
		(cons UL-CLOSE '()))))

(: iterate-ul (ul --> ul))
(define (iterate-ul tree)
  (make-ul (cons (car (ul-current tree)) (ul-head tree))
	   (cdr (ul-current tree))
	   (ul-foot tree)))

(: recurse-ul (ul --> ul))
(define (recurse-ul tree)
  (make-ul (cons (activate-li (car (ul-current tree))) (ul-head tree))
	   '()
	   (append (cdr (ul-current tree)) (ul-foot tree))))

(: flatten-ul (ul --> flat-ul))
(define (flatten-ul tree)
  (append (reverse (cons (activate-li (car (ul-current tree))) (ul-head tree)))
	  (cdr (ul-current tree)) (ul-foot tree)))

; /* The file struct represents directories or plaintext files in the input
;  * tree. A given file's path, url, etc information is derived from the
;  * information contained in its parent directory's file struct. All
;  * plaintext files in a directory are annotated with file structs before
;  * any IO takes place */

(: annotate-file (file string --> file))
(define (annotate-file dir name)
  (let ((new-path (string-append (file-path dir) "/" name)))
    (make-file
      name
      new-path
      (string-append (file-output dir) "/" name)
      (string-append (file-url dir) "/" name)
      (directory? new-path)
      #f)))

; /* file IO: (write-text) is u-g-l-y, but it works */
(: write-text (input-port output-port -> boolean))
(define (write-text in out)
  (letrec ((open-tag (string->list "<code>"))
	   (close-tag (string->list "</code>"))
	   (minify? (set? minify))
	   (out-tag
	     (lambda (tag)
	       (if (null? tag)
		 (in-tag close-tag)
		 (let ((c (read-char in))
		       (ct (car tag)))
		   (cond ((eof-object? c) #t)
			 ((char=? c ct)
			  (display c out)
			  (if minify?
			    (out-tag (cdr tag))
			    (out-tag open-tag)))
			 ((and minify?
			      (or (char=? c #\newline) (char=? c #\tab)))
			  (out-tag open-tag))
			 (else
			   (display c out)
			   (out-tag open-tag)))))))
	   (in-tag
	     (lambda (tag)
	       (if (null? tag)
		 (out-tag open-tag)
		 (let ((c (read-char in))
		       (ct (car tag)))
		   (cond ((eof-object? c)
			  (error "Unclosed <code> tag detected."))
			 ((char=? c ct)
			  (display c out)
			  (in-tag (cdr tag)))
			 (else
			   (display c out)
			   (in-tag close-tag))))))))
    (out-tag open-tag)))

(: write-html (template output-port #!rest procedure -> null))
(define (write-html template out . fs)
  (foldl (lambda (fs x)
	   (cond
	     ((string? x) (display x out) fs)
	     ((eq? x '!) ((car fs) out) (cdr fs))
	     ((eq? x '_) (if (set? minify) fs (begin (newline out) fs)))
	     (else (display x out) fs)))
	 fs
	 template))

(: write-title (string output-port -> null))
(define (write-title name out)
  (write-html TITLE out
	      (if (set? name)
		(write-var (opt name) " - ")
		(write-var ""))
	      (write-var name)))

(: write-head (string output-port -> null))
(define (write-head name out)
  (write-html HEAD out
	      (if (set? inline-css)
		(lambda (p)
		  (write-html INLINE-CSS p (write-var (opt inline-css))))
		(if (set? css)
		  (lambda (p) (write-html LINKED-CSS p (write-var (opt css))))
		  (write-var "")))
	      (lambda (p) (write-title name p))))

(: write-li (li output-port -> null))
(define (write-li li out)
  (write-html LI out
	      (write-var (car li))
	      (write-var (caddr li))
	      (if (li-dir? li) (write-var "/ " (cadddr li)) (write-var ""))
	      (write-var (cadddr li))
	      (if (li-dir? li) (write-var "/") (write-var ""))))

(: write-ul (flat-ul output-port -> null))
(define (write-ul ul out)
  (write-html UL out
	      (lambda (p)
		(for-each (lambda (x)
			    (if (li? x)
			      (if (not (directory-file? x)) (write-li x p))
			      (display x p)))
			  ul))))

(: write-nav (flat-ul output-port -> noreturn))
(define (write-nav ul out)
  (write-html NAV out
	      (if (set? hidden)
		  (lambda (p) (write-html TOGGLE p (write-var (opt hidden))))
		  (lambda (q) (display "")))
		(lambda (p) (write-ul ul p))))

(: write-banner (string output-port -> null))
(define (write-banner name out)
  (write-html BANNER out
	      (write-var (opt url))
	      (write-var (if (set? name) (opt name) ""))
	      (write-var (if (set? delimiter) (opt delimiter) ""))
	      (write-var name)))

(: write-body (string output-port -> fixnum))
(define (write-body path out)
  (let ((in (open-input-pipe (string-append (opt markdown) " \"" path "\""))))
    (write-html BODY out (lambda (p) (write-text in p)))
    (close-input-pipe in)))

(: write-page (file flat-ul -> noreturn))
(define (write-page f tree)
  (display "Writing ") (display (file-name f)) (newline)
  (let ((out (open-output-file (string-append (file-output f) ".html"))))
    (write-head (file-name f) out)
    (write-nav tree out)
    (write-banner (file-name f) out)
    (write-body (file-path f) out)
    (close-output-port out)))

; /* writing loop */
(: alphabetize ((list-of string) --> (list-of string)))
(define (alphabetize xs)
  (sort xs (lambda (y x) (fx> (char->integer (string-ref x 0))
			      (char->integer (string-ref y 0))))))

(: directory-file-check (file -> noreturn))
(define (directory-file-check dir)
  (let ((f (string-append " " (file-name dir))))
    (if (null? (filter (lambda (x) (string=? x f))
		       (directory (file-path dir))))
      (let ((out (open-output-file (string-append (file-path dir) "/" f)))) 
	(display "Autogenerated input file. Edit me.\n" out)
	(close-output-port out)))))

(: directory-loop ((list-of file) ul -> noreturn))
(define (directory-loop files tree)
  (cond
    ((not (null? files))
     (let* ((x (car (ul-current tree)))
	    (f (car files)))
       (if (li? x)
	 (begin (if (file-directory? f)
		  (write-directory f (recurse-ul tree))
		  (write-page f (flatten-ul tree)))
		(directory-loop (cdr files) (iterate-ul tree)))
	 (directory-loop files (iterate-ul tree)))))))

(: write-directory (file ul -> noreturn))
(define (write-directory dir tree)
  (if (not (file-top-level? dir))
    (directory-file-check dir))
  (let* ((files (map (lambda (x) (annotate-file dir x))
		     (alphabetize (directory (file-path dir)))))
	 (new-tree (make-ul (ul-head tree) (make-lis files) (ul-foot tree))))
    (create-directory (file-output dir))
    (directory-loop files new-tree)))

; /* main */
(assign-parameters (command-line-arguments))
(if (not (set? input))
  (begin (display "No input specifed. Using current directory.\n")
	 (hash-table-set! SETTINGS 'input (current-directory))))
(if (not (set? output))
  (begin (create-directory "/tmp/anthill-output")
	 (hash-table-set! SETTINGS 'output "/tmp/anthill-output")
	 (display "No output specified. Writing to /tmp/anthill-output\n")))
(if (not (set? url))
  (hash-table-set! SETTINGS 'url (opt output)))
(if (not (set? markdown))
  (hash-table-set! SETTINGS 'markdown "markdown"))
(if (set? inline-css)
  (let ((css-string (open-output-string))
	(css-file (open-input-file (opt inline-css))))
    (write-text css-file css-string)
    (hash-table-set! SETTINGS 'inline-css (get-output-string css-string))
    (close-output-port css-string)
    (close-input-port css-file)))
(write-directory (make-file "null" (opt input) (opt output) (opt url) #t #t)
		 (make-ul '() '() '()))
