;;; portfile-ts-mode.el --- Tree-sitter mode for Portfile -*- lexical-binding: t; -*-

;;; Commentary:
;;; Code:

(require 'treesit)

(defgroup portfile-ts nil
  "Tree-sitter support for MacPorts Portfiles."
  :group 'languages)

(define-derived-mode portfile-ts-mode prog-mode "Portfile"
  "Major mode for MacPorts Portfiles."

  ;; Portfiles use spaces for indentation
  (setq-local indent-tabs-mode nil)
  (setq-local tab-width 4)

  (treesit-parser-create 'portfile)

  (setq-local treesit-font-lock-feature-list
              '((comment)
                (command)
                (variable)
                (string)
                (escape)))

  (setq-local treesit-font-lock-settings
              (treesit-font-lock-rules

               :feature 'comment
               :language 'portfile
               '((comment) @font-lock-comment-face)

               :feature 'command
               :language 'portfile
               '((command
                  name: _ @font-lock-keyword-face))

               :feature 'variable
               :language 'portfile
               '((variable_substitution)
                 @font-lock-variable-name-face)

               :feature 'string
               :language 'portfile
               '((quoted_word) @font-lock-string-face
                 (braced_word_simple) @font-lock-string-face)

               :feature 'escape
               :language 'portfile
               '((escaped_character) @font-lock-escape-face)

               ))

  (treesit-major-mode-setup))

(add-to-list 'inhibit-local-variables-regexps
             "\\(?:^\\|/\\)Portfile\\'")

(add-to-list 'auto-mode-alist
             '("/Portfile\\'" . portfile-ts-mode))

(provide 'portfile-ts-mode)

;;; portfile-ts-mode.el ends here
