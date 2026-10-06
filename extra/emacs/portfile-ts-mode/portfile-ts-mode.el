;;; portfile-ts-mode.el --- Tree-sitter mode for Portfile -*- lexical-binding: t; -*-

;; Version: 0.2
;; Package-Requires: ((emacs "30.1"))
;; Keywords: languages, macports, portfile

;;; Commentary:

;;; Code:

(require 'json)
(require 'treesit)

;;; User options
;;  ------------

(defcustom portfile-ts-mode-indent-offset 4
  "Indentation inside { } blocks."
  :type 'integer)

(defcustom portfile-ts-mode-argument-indent-offset 24
  "Column where the value of a top-level command is aligned to.
The MacPorts convention is 24."
  :type 'integer)

;;; Core options
;;  ------------

;; TODO: `treesit-language-source-alist'
;; (add-to-list
;;  'treesit-language-source-alist
;;  '(cmake "https://github.com/judaew/tree-sitter-portfile"
;;          :commit "fake")
;;  t)

(defgroup portfile-ts nil
  "Tree-sitter support for MacPorts Portfiles."
  :group 'languages
  :prefix "portfile-ts-mode-")

(defvar-keymap portfile-ts-mode-map
  :parent prog-mode-map)

(defvar portfile-ts-mode--syntax-table
  (let ((table (make-syntax-table prog-mode-syntax-table)))
    (modify-syntax-entry ?#  "<" table)
    (modify-syntax-entry ?\n ">" table)
    (modify-syntax-entry ?\" "\"" table)
    (modify-syntax-entry ?\\ "\\" table)
    (modify-syntax-entry ?{ "(}" table)
    (modify-syntax-entry ?} "){" table)
    (modify-syntax-entry ?\[ "(]" table)
    (modify-syntax-entry ?\] ")[" table)
    table))

;;; Regular expressions
;;  -------------------

(defvar portfile-ts-mode--data
  (let* ((dir (file-name-directory
               (or (locate-library "portfile-ts-mode")
                   (error "The 'portfile-ts-mode' is not on load-path"))))
         (file (expand-file-name "keywords.json" dir)))
    (unless (file-exists-p file)
      (error "The 'keywords.json' not found next to portfile-ts-mode.el: %s" file))
    (with-temp-buffer
      (insert-file-contents file)
      (json-parse-buffer :object-type 'alist :array-type 'list)))
  "Contents of keywords.json.
The 'options' key holds section names (portmain, portfetch etc);
each section maps to a list of full option names.")

(defun portfile-ts-mode--kw (key)
  "Value of the array KEY from 'keywords.json'."
  (cdr (assq (intern key) portfile-ts-mode--data)))

(defconst portfile-ts-mode--options
  (delete-dups
   (apply #'append
          (mapcar #'portfile-ts-mode--kw
                  (append
                   (portfile-ts-mode--kw "options")
                   (portfile-ts-mode--kw "portgroups")))))
  "All Portfile keywords from 'keywords.json'.")

(defconst portfile-ts-mode--option-regexp
  (concat
   "\\`\\(?:"
   (regexp-opt portfile-ts-mode--options t)
   "\\)"
   ;; Optional modifier suffix (depends_lib-append etc)
   "\\(?:-" (regexp-opt (portfile-ts-mode--kw "modifiers") t) "\\)?"
   "\\'")
  "Regexp matching MacPorts Portfile option names.")

(defconst portfile-ts-mode--builtin-regexp
  (concat "\\`"
          (regexp-opt (delete-dups (portfile-ts-mode--kw "builtins")) t)
          "\\'")
  "Regexp matching built-in Tcl and Port command names.")

(defconst portfile-ts-mode--checksum-type-regexp
  (concat "\\`" (regexp-opt (portfile-ts-mode--kw "checksums_type") t) "\\'")
  "Regexp matching checksum types (rmd160, sha256, size etc).")

(defconst portfile-ts-mode--defun-regexp
  (rx (or "phase_hook" "variant_command" "platform_command"
          "subport_command" "proc_command")))

;;; Font lock
;;  ---------

(defvar portfile-ts-mode--font-lock-rules
  (treesit-font-lock-rules
   :default-language 'portfile

   :feature 'comment
   '((comment) @font-lock-comment-face)

   :feature 'string
   '((quoted_word) @font-lock-string-face
     (braced_word_simple) @font-lock-string-face
     (((command name: (simple_word) @cmd
                arguments: (word_list) @font-lock-string-face))
      (:match "\\`\\(?:long_\\)?description\\'" @cmd)))

   :feature 'keyword
   '((portsystem_command "PortSystem" @font-lock-keyword-face)
     (portgroup_command "PortGroup" @font-lock-keyword-face)
     (variant_command "variant" @font-lock-keyword-face)
     (variant_command "requires" @font-lock-keyword-face)
     (variant_command "conflicts" @font-lock-keyword-face)
     (variant_command "description" @font-lock-keyword-face)
     (platform_command "platform" @font-lock-keyword-face)
     (subport_command "subport" @font-lock-keyword-face)
     (phase_hook name: (phase_name) @font-lock-keyword-face)
     (if_command "if" @font-lock-keyword-face)
     (elseif_clause "elseif" @font-lock-keyword-face)
     (else_clause "else" @font-lock-keyword-face)
     (foreach_command "foreach" @font-lock-keyword-face)
     (while_command "while" @font-lock-keyword-face)
     (for_command "for" @font-lock-keyword-face)
     (switch_command "switch" @font-lock-keyword-face)
     (proc_command "proc" @font-lock-keyword-face))

   ;; Fallback: anything not matched by builtin/property below.
   :feature 'function
   '((command name: (simple_word) @font-lock-function-call-face
              arguments: (word_list)))

   :feature 'builtin
   :override t
   `(((command name: (simple_word) @font-lock-builtin-face
               arguments: (word_list))
      (:match ,portfile-ts-mode--builtin-regexp
              @font-lock-builtin-face)))

   :feature 'property
   :override t
   `((command "license" @font-lock-property-name-face)
     (command "platforms" @font-lock-property-name-face)
     (command "maintainers" @font-lock-property-name-face)
     (((command name: (simple_word) @font-lock-property-name-face
                arguments: (word_list)))
      (:match ,portfile-ts-mode--option-regexp
              @font-lock-property-name-face)))

   :feature 'variable
   :override t
   `((variable_substitution) @font-lock-variable-name-face
     ;; Target variable of `set foo ...`
     (((command name: (simple_word) @cmd
                arguments: (word_list (simple_word)
                                      @font-lock-variable-name-face)))
      (:match "\\`set\\'" @cmd)))

   :feature 'escape
   :override t
   '((escaped_character) @font-lock-escape-face)

   :feature 'number
   '(((simple_word) @font-lock-number-face
      (:match "\\`[0-9][0-9.]*\\'" @font-lock-number-face)))

   :feature 'operator
   '((unpack) @font-lock-operator-face
     (command_substitution ["[" "]"] @font-lock-operator-face))

   :feature 'link
   '(((simple_word) @link
      (:match "\\`\\(?:https?\\|ftp\\|rsync\\)://" @link)))

   :feature 'checksum
   `(((command name: (simple_word) @cmd
               arguments: (word_list (simple_word) @font-lock-type-face))
      (:match "\\`checksums\\'" @cmd)
      (:match ,portfile-ts-mode--checksum-type-regexp
              @font-lock-type-face)))

   :feature 'definition
   '((proc_command proc_name: (simple_word) @font-lock-function-name-face)
     (variant_command variant: (simple_word) @font-lock-constant-face)
     (subport_command subport: (simple_word) @font-lock-constant-face)
     (portgroup_command group: (simple_word) @font-lock-type-face))

   :feature 'error
   :override t
   '((ERROR) @font-lock-warning-face)))

;;; Indentation
;;  ----------

(defun portfile-ts-mode--argument-indent (node parent _bol)
  "Indent NODE or PARENT portfile-ts-mode-argument-indent-offset column after the command."
  (let ((node (or node parent)))
    (when-let ((command (treesit-parent-until node "command")))
      (while (not (treesit-node-eq (treesit-node-parent node) command))
        (setq node (treesit-node-parent node)))
      (unless (member (treesit-node-field-name node) '("name" "body"))
        (cons (treesit-node-start command)
              portfile-ts-mode-argument-indent-offset)))))

(defun portfile-ts-mode--indent-tab ()
  "Indent line or align command arguments."
  (interactive)
  (let ((bol (line-beginning-position)))
    (cond
     ;; Continuation line
     ((save-excursion
        (goto-char bol)
        (forward-line -1)
        (end-of-line)
        (eq (char-before) ?\\))
      (treesit-indent))

     ;; Line indentation
     ((<= (point) (+ bol (current-indentation)))
      (treesit-indent))

     ;; Align after command name
     ((let* ((node (save-excursion
                     (goto-char bol)
                     (skip-chars-forward " \t")
                     (treesit-node-at (point))))
             (command (and node
                           (treesit-parent-until node "command")))
             (name (and command
                        (treesit-node-child-by-field-name command "name"))))
        (and command name (>= (point) (treesit-node-end name))
             (save-excursion
               (skip-chars-backward " \t")
               (= (point) (treesit-node-end name)))))
      (indent-to (+ (current-indentation)
                    portfile-ts-mode-argument-indent-offset)))
     (t (indent-relative)))))

;;; Imenu
;;  -----

;; TODO: [WIP]

;;; Completion
;;  ----------

(defconst portfile-ts-mode--completion-candidates
  (let* ((phases (portfile-ts-mode--kw "phases"))
         (mods   (portfile-ts-mode--kw "modifiers"))
         (opts   portfile-ts-mode--options))
    (delete-dups
     (append
      opts
      ;; option + modifier variants (depends_lib-append and etc)
      (apply #'append
             (mapcar (lambda (o)
                       (mapcar (lambda (m) (concat o "-" m)) mods))
                     opts))
      (portfile-ts-mode--kw "portgroups")
      (delete-dups (portfile-ts-mode--kw "builtins"))
      (append phases
              (mapcar (lambda (p) (concat "pre-" p)) phases)
              (mapcar (lambda (p) (concat "post-" p)) phases)))))
  "Completion candidates built from `keywords.json'.")

(defun portfile-ts-mode-completion-at-point ()
  "Complete Portfile keywords at point."
  (let ((start (save-excursion (skip-chars-backward "[:alnum:]_.-") (point))))
    (list start (point) portfile-ts-mode--completion-candidates
          :exclusive 'no)))

;;; Mode
;;  ----

;;;###autoload
(define-derived-mode portfile-ts-mode prog-mode "Portfile"
  "Major mode for editing MacPorts Portfiles using tree-sitter."
  :syntax-table portfile-ts-mode--syntax-table
  (unless (treesit-ready-p 'portfile)
    (error "Tree-sitter grammar for portfile is not available"))

  (setq-local indent-tabs-mode nil)
  (setq-local tab-width portfile-ts-mode-indent-offset)
  (setq-local comment-start "# ")
  (setq-local comment-end "")

  (setq-local completion-at-point-functions
              (cons #'portfile-ts-mode-completion-at-point
                    completion-at-point-functions))

  (treesit-parser-create 'portfile)

  ;; font-lock in 4 levels
  (setq-local treesit-font-lock-feature-list
              '((comment)
                (keyword string function)
                (builtin property variable definition
                         escape number operator link checksum)
                (error)))

  (setq-local treesit-font-lock-settings portfile-ts-mode--font-lock-rules)

  (setq-local treesit-simple-indent-rules
              '((portfile
                 ((node-is "}") parent-bol 0)
                 portfile-ts-mode--argument-indent
                 ((parent-is "braced_word") parent-bol
                  portfile-ts-mode-indent-offset)
                 ((parent-is "source_file") column-0 0))))

  (setq-local treesit-thing-settings
              `((portfile (defun ,portfile-ts-mode--defun-regexp))))
  (setq-local treesit-outline-predicate portfile-ts-mode--defun-regexp)

  ;; Clickable URLs (homepage, master_sites etc)
  (goto-address-prog-mode 1)

  (treesit-major-mode-setup)

  (setq-local indent-tabs-mode nil)
  (setq-local indent-line-function #'portfile-ts-mode--indent-tab)
  (setq-local indent-region-function #'treesit-indent-region))

;; A Portfile starts with a vim modeline (mode: tcl); don't offer it
;; as file local variables, it would override this major mode
(add-to-list 'inhibit-local-variables-regexps "\\(?:^\\|/\\)Portfile\\'")

;;;###autoload
(add-to-list 'auto-mode-alist '("/Portfile\\'" . portfile-ts-mode))

(provide 'portfile-ts-mode)

;;; portfile-ts-mode.el ends here
