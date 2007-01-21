;;; riece-mcat.el --- message catalog
;; Copyright (C) 2007 Daiki Ueno

;; Author: Daiki Ueno <ueno@unixuser.org>

;; This file is part of Riece.

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation; either version 2, or (at your option)
;; any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.	 See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with GNU Emacs; see the file COPYING.  If not, write to the
;; Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
;; Boston, MA 02110-1301, USA.

;;; Code:

(require 'pp)

(defun riece-mcat (string)
  "Translate STRING in the current language environment."
  (let ((feature (get-language-info current-language-environment
				    'riece-mcat-feature)))
    (if feature
	(progn
	  (require feature)
	  (or (cdr (assoc string
			  (symbol-value
			   (intern (concat (symbol-name feature) "-alist")))))
	      string))
      string)))

(defun riece-mcat-extract-from-form (form)
  (if (and form (listp form) (listp (cdr form)))
      (if (eq (car form) 'riece-mcat)
	  (cdr form)
	(delq nil (apply #'nconc
			 (mapcar #'riece-mcat-extract-from-form form))))))

(defun riece-mcat-extract (files alist)
  (save-excursion
    (let (message-list)
      (while files
	(with-temp-buffer
	  (insert-file-contents (car files))
	  (goto-char (point-min))
	  (while (progn
		   (while (progn (skip-chars-forward " \t\n\f")
				 (looking-at ";"))
		     (forward-line 1))
		   (not (eobp)))
	    (setq message-list
		  (nconc message-list
			 (riece-mcat-extract-from-form
			  (read (current-buffer)))))))
	(setq files (cdr files)))
      (setq message-list (sort message-list #'string-lessp))
      (while message-list
	(if (equal (car message-list)
		   (nth 1 message-list))
	    (setq message-list (nthcdr 2 message-list))
	  (unless (assoc (car message-list) alist)
	    (setq alist (cons (list (car message-list)) alist)))
	  (setq message-list (cdr message-list))))
      alist)))

(defun riece-mcat-update (files mcat-file mcat-alist-symbol)
  "Update MCAT-FILE."
  (let ((pp-escape-newlines t)
	alist)
    (save-excursion
      (set-buffer (find-file-noselect mcat-file))
      (goto-char (point-min))
      (if (re-search-forward (concat "^\\s-*(\\(defvar\\|defconst\\)\\s-+"
				     (regexp-quote (symbol-name
						    mcat-alist-symbol)))
			     nil t)
	  (progn
	    (goto-char (match-beginning 0))
	    (save-excursion
	      (eval (read (current-buffer))))
	    (delete-region (point) (progn (forward-sexp) (point))))
	(set mcat-alist-symbol nil))
      (setq alist (riece-mcat-extract files (symbol-value mcat-alist-symbol)))
      (insert "(defconst " (symbol-name mcat-alist-symbol) "\n  '(")
      (while alist
	(insert "(" (pp-to-string (car (car alist))) " . "
		(pp-to-string (cdr (car alist))) ")")
	(if (cdr alist)
	    (insert "\n    "))
	(setq alist (cdr alist)))
      (insert "))")
      (save-buffer))))

(defconst riece-mcat-description "Translate messages")

(defun riece-mcat-insinuate ()
  (set-language-info "Japanese" 'riece-mcat-feature 'riece-mcat-japanese))

(defun riece-mcat-uninstall ()
  (set-language-info "Japanese" 'riece-mcat-feature nil))

(provide 'riece-mcat)

;;; riece-mcat.el ends here
