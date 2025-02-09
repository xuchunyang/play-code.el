;;; play-code.el --- Play code with online playgrounds -*- lexical-binding: t; -*-

;; Copyright (C) 2019 Gong Qijian <gongqijian@gmail.com>

;; Author: Gong Qijian <gongqijian@gmail.com>
;; Created: 2019/10/11
;; Version: 0.1.0
;; Package-Requires: ((emacs "24.4") (json "1.2") (dash "2.1"))
;; URL: https://github.com/twlz0ne/play-code.el
;; Keywords: tools

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <https://www.gnu.org/licenses/>.

;;; Commentary:

;; Play code with online playgrounds:
;;
;; - play-code-region
;; - play-code-buffer
;; - play-code-block (require org-mode / markdown)
;;
;; See README.md for more information.

;;; Change Log:

;;  0.1.0  2019/10/11  Initial version.

;;; Code:

(require 'url-util)
(require 'json)
(require 'dash)

(defvar org-babel-src-block-regexp)
(declare-function org-src--get-lang-mode "org")
(declare-function org-element-at-point "org")
(declare-function org-element-property "org")
(declare-function org-babel-where-is-src-block-head "org")
(declare-function markdown-code-block-lang "markdown-mode")
(declare-function markdown-get-lang-mode "markdown-mode")
(declare-function markdown-get-enclosing-fenced-block-construct "markdown-mode")

(defcustom play-code-buffer-name "*play-code*"
  "The name of the buffer to show output."
  :type 'string
  :group 'play-code)

(defcustom play-code-focus-p t
  "Whether to move focus to output buffer after `url-retrieve' responsed."
  :type 'boolean
  :group 'play-code)

(defcustom play-code-output-to-buffer-p t
  "Show output in buffer or not."
  :type 'boolean
  :group 'play-code)

;;; playgrounds

(defconst play-code-ground-alist
  '((play-code-rextester-languages . play-code-send-to-rextester)
    (play-code-labstack-languages  . play-code-send-to-labstack)))

(defconst play-code-rextester-languages
  '((ada-mode          . (("39" . "Ada")))
    (bash-mode         . (("38" . "Bash")))
    (brainfuck-mode    . (("44" . "Brainfuck")))
    (c-mode            . (("26" . "C (clang)")
                          ("6"  . "C (gcc)")
                          ("29" . "C (vc)")))
    (common-lisp-mode  . (("18" . "Common Lisp")))
    (cpp-mode          . (("27" . "C++ (clang)")
                          ("7"  . "C++ (gcc)")
                          ("28" . "C++ (vc++)")))
    (csharp-mode       . (("1"  . "C#")))
    (d-mode            . (("30" . "D")))
    (elixir-mode       . (("41" . "Elixir")))
    (erlang-mode       . (("40" . "Erlang")))
    (fortran-mode      . (("45"  . "F#")))
    (fsharp-mode       . (("3" . "Fortran")))
    (go-mode           . (("20" . "Go")))
    (haskell-mode      . (("11" . "Haskell")))
    (java-mode         . (("4"  . "Java")))
    (javascript-mode   . (("17" . "Javascript")
                          ("23" . "Node.js")))
    (js-mode           . javascript-mode)
    (js2-mode          . javascript-mode)
    (js:node-mode      . (("23" . "Node.js")))
    (kotlin-mode       . (("43" . "Kotlin")))
    (lua-mode          . (("14" . "Lua")))
    (nasm-mode         . (("15" . "Assembly")))
    (objc-mode         . (("10" . "Objective-C")))
    (ocaml-mode        . (("42" . "Ocaml")))
    (octave-mode       . (("25" . "Octave")))
    (oracle-mode       . (("35" . "Oracle")))
    (pascal-mode       . (("9"  . "Pascal")))
    (perl-mode         . (("13" . "Perl")))
    (php-mode          . (("8"  . "Php")))
    (prolog-mode       . (("19" . "Prolog")))
    (python-mode       . (("24" . "Python 3")
                          ("5"  . "Python")))
    (python:3-mode     . (("24" . "Python 3")))
    (python:2-mode     . (("5"  . "Python")))
    (r-mode            . (("31" . "R")))
    (ruby-mode         . (("12" . "Ruby")))
    (scala-mode        . (("21" . "Scala")))
    (scheme-mode       . (("22" . "Scheme")))
    (sql-mode          . (("33" . "MySql")
                          ("34" . "PostgreSQL")
                          ("16" . "Sql Server")))
    (swift-mode        . (("37" . "Swift")))
    (tcl-mode          . (("32" . "Tcl")))
    (visual-basic-mode . (("2"  . "Visual Basic")))
    ))

(defconst play-code-rextester-compiler-args
  `((,(caadr (assoc 'go-mode play-code-rextester-languages)) . "-o a.out source_file.go")))

(defconst play-code-labstack-languages
  '((sh-mode           . (("bash"         . "Bash")))
    (c-mode            . (("c"            . "C")))
    (clojure-mode      . (("clojure"      . "Clojure")))
    (coffeescript-mode . (("coffeescript" . "CoffeeScript")))
    (c++-mode          . (("c++"          . "C++")))
    (crystal-mode      . (("crystal"      . "Crystal")))
    (csharp-mode       . (("csharp"       . "C#")))
    (d-mode            . (("d"            . "D")))
    (dart-mode         . (("dart"         . "Dart")))
    (elixir-mode       . (("elixir"       . "Elixir")))
    (erlang-mode       . (("erlang"       . "Erlang")))
    (fsharp-mode       . (("fsharp"       . "F#")))
    (groovy-mode       . (("groovy"       . "Groovy")))
    (go-mode           . (("go"           . "Go")))
    (hack-mode         . (("hack"         . "Hack")))
    (haskell-mode      . (("haskell"      . "Haskell")))
    (java-mode         . (("java"         . "Java")))
    (javascript-mode   . (("javascript"   . "JavaScript")
                          ("node"         . "Node")))
    (js-mode           . javascript-mode)
    (js2-mode          . javascript-mode)
    (js:node-mode      . (("node"         . "Node")))
    (julia-mode        . (("julia"        . "Julia")))
    (kotlin-mode       . (("kotlin"       . "Kotlin")))
    (lua-mode          . (("lua"          . "Lua")))
    (nim-mode          . (("nim"          . "Nim")))
    (objc-mode         . (("objective-c"  . "Objective-C")))
    (ocaml-mode        . (("ocaml"        . "OCaml")))
    (octave-mode       . (("octave"       . "Octave")))
    (perl-mode         . (("perl"         . "Perl")))
    (php-mode          . (("php"          . "PHP")))
    (powershell-mode   . (("powershell"   . "PowerShell")))
    (python:3-mode     . (("python"       . "Python")))
    (ruby-mode         . (("ruby"         . "Ruby")))
    (r-mode            . (("r"            . "R")))
    (reason-mode       . (("reason"       . "Reason")))
    (rust-mode         . (("rust"         . "Rust")))
    (scala-mode        . (("scala"        . "Scala")))
    (swift-mode        . (("swift"        . "Swift")))
    (tcl-mode          . (("tcl"          . "TCL")))
    (typescript-mode   . (("typescript"   . "TypeScript")))
    ))

(defun play-code-send-to-rextester (lang-id code)
  "Send CODE to `rextester.com', return the execution result.
LANG-ID to specific the language."
  (let* ((url-request-method "POST")
         (url-request-extra-headers
           `(("content-type"    . "application/x-www-form-urlencoded; charset=UTF-8")
             ("accept"          . "text/plain, */*; q=0.01")
             ("accept-encoding" . "gzip")))
         (url-request-data
           (concat "LanguageChoiceWrapper="
                   lang-id
                   "&EditorChoiceWrapper=1&LayoutChoiceWrapper=1&Program="
                   (url-encode-url code)
                   "&CompilerArgs="
                   (assoc-default lang-id play-code-rextester-compiler-args)
                   "&IsInEditMode=False&IsLive=False"))
         (content-buf (url-retrieve-synchronously
                       "https://rextester.com/rundotnet/run")))
    (play-code--handle-json-response
     content-buf
     (lambda (resp)
       ;; (message "==> resp object:\n%S" resp)
       (let* ((warnings (assoc-default 'Warnings resp))
              (errors (assoc-default 'Errors resp))
              (result (assoc-default 'Result resp)))
         (concat (unless (eq warnings :null) warnings)
                 (unless (eq errors :null) errors)
                 (unless (eq result :null) result)))))))

(defun play-code-send-to-labstack (lang-id code)
  "Send CODE to `code.labstack.com', return the execution result.
LANG-ID to specific the language."
  (let* ((name (capitalize lang-id))
         (url-request-method "POST")
         (url-request-extra-headers
           '(("content-type"     . "application/json;charset=UTF-8")
             ("accept"           . "application/json, text/plain, */*")
             ("accept-encoding"  . "gzip")))
         (url-request-data (json-encode-plist
                            `(:notes ""
                              :language (:id ,(format "%s" lang-id)
                                         :name ,(format "%s" name)
                                         :version ""
                                         :code ,code
                                         :text ,(format "%s (<version>)" name))
                              :content ,code)))
         (content-buf (url-retrieve-synchronously
                       "https://code.labstack.com/api/v1/run")))
    (play-code--handle-json-response
     content-buf
     (lambda (resp)
       (if (assoc-default 'code resp)
           (assoc-default 'message resp)
         (concat (assoc-default 'stdout resp)
                 (assoc-default 'stderr resp)))))))

;;; 

(defun play-code--pop-to-buffer (buf)
  "Display buffer specified by BUF and select its window."
  (let ((win (selected-window)))
    (pop-to-buffer buf)
    (unless play-code-focus-p
      (select-window win))))

(defun play-code--handle-json-response (url-content-buf callback)
  "Handle json response in URL-CONTENT-BUF.
Function CALLBACK accept an alist, and return output string."
  (with-current-buffer url-content-buf
    (goto-char (point-min))
    (re-search-forward "\n\n")
    ;; (message "==> resp string:\n%s" (buffer-substring (point) (point-max)))
    (let* ((resp (json-read-from-string (buffer-substring (point) (point-max))))
           (output (funcall callback resp))
           (output-buf (get-buffer-create play-code-buffer-name)))
      (cond (play-code-output-to-buffer-p
             (with-current-buffer output-buf
               (read-only-mode -1)
               (erase-buffer)
               (insert output)
               (read-only-mode 1)
               (play-code--pop-to-buffer output-buf)))
            (t output)))))

(defun play-code--get-shebang-command ()
  "Get shabang program."
  (save-excursion
    (goto-char (point-min))
    (when (looking-at "#![^ \t]* \\(.*\\)$")
      (match-string-no-properties 1))))

(defun play-code--nodejs-p ()
  "Detect require / exports statment in buffer."
  (save-excursion
    (goto-char (point-min))
    (and
     (or
      (re-search-forward
       "^[ \t]*\\(var\\|const\\)[ \t]*[[:word:]]+[ \t]*=[ \t]*require[ \t]*("
       nil t 1)
      (re-search-forward
       "^[ \t]*\\(module\\.\\|\\)[ \t]*exports[ \t]*="
       nil t 1))
     t)))

(defun play-code--get-mode-alias (&optional mode)
  "Return alias of MODE.
The alias naming in the form of `foo:<specifier>-mode' to
opposite a certain version of lang in `play-code-xxx-languags'."
  (let ((mode (or mode major-mode)))
    (pcase mode
      ('python-mode
       (pcase (list (play-code--get-shebang-command)
                    (file-name-extension (or (buffer-file-name) (buffer-name))))
         ((or `("python3" ,_) `(,_ "py3")) 'python:3-mode)
         ((or `("python2" ,_) `(,_ "py2")) 'python:2-mode)
         (_ mode)))
      ((or 'js-mode 'js2-mode 'javascript-mode)
       (if (play-code--nodejs-p) 'js:node-mode mode))
      (_ mode))))

(defun play-code--get-ground (mode)
  "Return (((lang-id . lang-name) ...) . send-function) for MODE."
  (catch 'break
    (mapc
     (lambda (ground)
       (let ((lang (assoc mode (symbol-value (car ground)))))
         (let ((symbol (cdr lang)))
           (when (symbolp symbol)
             (setq lang (assoc symbol (symbol-value (car ground))))))
         (when lang
           (throw 'break (cons (cdr lang) (cdr ground))))))
     play-code-ground-alist)
    nil))

(defun play-code--get-lang-and-function (mode)
  "Return (lang function) for MODE."
  (pcase-let*
      ((`(,langs . ,func) (play-code--get-ground mode))
       (`(,lang . ,_desc)
         (cond ((> (length langs) 1)
                (rassoc
                 (completing-read "Choose: " (mapcar (lambda (it) (cdr it)) langs))
                 langs))
               (t (car langs)))))
    ;; (message "==> lang: %s, func: %s" lang func)
    (list lang func)))

(defun play-code-orgmode-src-block ()
  "Return orgmode src block in the form of (mode code bounds)."
  (require 'org)
  (-if-let* ((src-element (org-element-at-point)))
      (list (org-src--get-lang-mode (org-element-property :language src-element))
            (org-element-property :value src-element)
            (save-excursion
              (goto-char (org-babel-where-is-src-block-head src-element))
              (looking-at org-babel-src-block-regexp)
              (list (match-beginning 5) (match-end 5))))))

(defun play-code-markdown-src-block ()
  "Return markdown src block in the form of (mode code bounds)."
  (require 'markdown-mode)
  (save-excursion
    (-if-let* ((lang (markdown-code-block-lang))
               (bounds (markdown-get-enclosing-fenced-block-construct))
               (begin (progn
                        (goto-char (nth 0 bounds)) (point-at-bol 2)))
               (end (progn
                      (goto-char (nth 1 bounds)) (point-at-bol 1))))
        (list (markdown-get-lang-mode lang)
              (buffer-substring-no-properties begin end)
              (list begin end)))))

;;;

;;;###autoload
(defun play-code-block ()
  "Send code block of orgmode / markdown to the playground."
  (interactive)
  (pcase-let*
      ((`(,mode ,code ,bounds)
         (pcase major-mode
           (`org-mode
            (or (play-code-orgmode-src-block)
                (error "No code block at point")))
           (`markdown-mode
            (or (play-code-markdown-src-block)
                (error "No code block at point")))
           (_ (error "Don't know how to detect the block, please use `play-code-region' instead"))))
       (`(,lang ,func)
           (play-code--get-lang-and-function
            (save-restriction
              (apply 'narrow-to-region bounds)
              (play-code--get-mode-alias mode)))))
    (funcall func lang code)))

;;;###autoload
(defun play-code-region (start end)
  "Send the region between START and END to the Playground."
  (interactive "r")
  (pcase-let*
      ((`(,mode ,_ ,bounds)
         (pcase major-mode
           (`org-mode
            (or (play-code-orgmode-src-block)
                (error "No code in region")))
           (`markdown-mode
            (or (play-code-markdown-src-block)
                (error "No code in region")))
           (_ (list major-mode nil nil))))
       (`(,lang ,func)
         (play-code--get-lang-and-function
          (save-restriction
            (when bounds
              (apply 'narrow-to-region bounds))
            (play-code--get-mode-alias mode)))))
    (funcall func lang (buffer-substring-no-properties start end))))

;;;###autoload
(defun play-code-buffer ()
  "Like `play-code-region', but acts on the entire buffer."
  (interactive)
  (play-code-region (point-min) (point-max)))

(provide 'play-code)

;;; play-code.el ends here
