;;; riece-display.el --- buffer arrangement
;; Copyright (C) 1998-2003 Daiki Ueno

;; Author: Daiki Ueno <ueno@unixuser.org>
;; Created: 1998-09-28
;; Keywords: IRC, riece

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
;; Free Software Foundation, Inc., 59 Temple Place - Suite 330,
;; Boston, MA 02111-1307, USA.

;;; Code:

(require 'riece-options)
(require 'riece-channel)
(require 'riece-misc)

(defvar riece-update-buffer-functions
  '(riece-user-list-update-buffer
    riece-channel-list-update-buffer
    riece-update-channel-indicator
    riece-update-channel-list-indicator))

(defcustom riece-configure-windows-function #'riece-configure-windows
  "Function to configure windows."
  :type 'function
  :group 'riece-looks)

(defcustom riece-configure-windows-predicate
  #'riece-configure-windows-predicate
  "Function to check whether window reconfiguration is needed."
  :type 'function
  :group 'riece-looks)

(defun riece-configure-windows ()
  (let ((buffer (current-buffer))
	(show-user-list
	 (and riece-user-list-buffer-mode
	      riece-current-channel
	      ;; User list buffer is nuisance for private conversation.
	      (riece-channel-p riece-current-channel))))
    (delete-other-windows)
    (if (and riece-current-channel
	     (or show-user-list riece-channel-list-buffer-mode))
	(let ((rest-window (split-window (selected-window)
					 (/ (window-width) 5) t)))
	  (if (and show-user-list riece-channel-list-buffer-mode)
	      (progn
		(set-window-buffer (split-window)
				   riece-channel-list-buffer)
		(set-window-buffer (selected-window)
				   riece-user-list-buffer))
	    (if show-user-list
		(set-window-buffer (selected-window)
				   riece-user-list-buffer)
	      (if riece-channel-list-buffer-mode
		  (set-window-buffer (selected-window)
				     riece-channel-list-buffer))))
	  (select-window rest-window)))
    (if (and riece-current-channel
	     riece-channel-buffer-mode)
	(let ((rest-window (split-window)))
	  (set-window-buffer (selected-window)
			     riece-channel-buffer)
	  (set-window-buffer (split-window rest-window 4)
			     riece-others-buffer)
	  (with-current-buffer riece-channel-buffer
	    (setq truncate-partial-width-windows nil))
	  (with-current-buffer riece-others-buffer
	    (setq truncate-partial-width-windows nil))
	  (set-window-buffer rest-window
			     riece-command-buffer))
      (set-window-buffer (split-window (selected-window) 4)
			 riece-dialogue-buffer)
      (set-window-buffer (selected-window)
			 riece-command-buffer))
    (riece-set-window-points)
    (select-window (or (get-buffer-window buffer)
		       (get-buffer-window riece-command-buffer)))))

(defun riece-set-window-points ()
  (if (and riece-user-list-buffer
	   (get-buffer-window riece-user-list-buffer))
      (with-current-buffer riece-user-list-buffer
	(unless (riece-frozen riece-user-list-buffer)
	  (set-window-start (get-buffer-window riece-user-list-buffer)
			    (point-min)))))
  (if (get-buffer-window riece-channel-list-buffer)
      (with-current-buffer riece-channel-list-buffer
	(unless (riece-frozen riece-channel-list-buffer)
	  (set-window-start (get-buffer-window riece-channel-list-buffer)
			    (point-min))))))

(defun riece-user-list-update-buffer ()
  (if (get-buffer riece-user-list-buffer)
      (save-excursion
	(set-buffer riece-user-list-buffer)
	(when (and riece-current-channel
		   (riece-channel-p riece-current-channel))
	  (let ((inhibit-read-only t)
		buffer-read-only
		(users (riece-channel-get-users riece-current-channel))
		(operators (riece-channel-get-operators riece-current-channel))
		(speakers (riece-channel-get-speakers riece-current-channel)))
	    (erase-buffer)
	    (while users
	      (if (member (car users) operators)
		  (insert "@" (car users) "\n")
		(if (member (car users) speakers)
		    (insert "+" (car users) "\n")
		  (insert " " (car users) "\n")))
	      (setq users (cdr users))))))))

(defun riece-channel-list-update-buffer ()
  (if (get-buffer riece-channel-list-buffer)
      (save-excursion
	(set-buffer riece-channel-list-buffer)
	(let ((inhibit-read-only t)
	      buffer-read-only
	      (index 1)
	      (channels riece-current-channels))
	  (erase-buffer)
	  (while channels
	    (if (car channels)
		(insert (format "%2d:%s\n" index (car channels))))
	    (setq index (1+ index)
		  channels (cdr channels)))))))

(defsubst riece-update-channel-indicator ()
  (setq riece-channel-indicator
	(if riece-current-channel
	    (riece-concat-current-channel-modes
	     (if (and riece-current-channel
		      (riece-channel-p riece-current-channel)
		      (riece-channel-get-topic riece-current-channel))
		 (concat riece-current-channel ": "
			 (riece-channel-get-topic riece-current-channel))
	       riece-current-channel))
	  "None"))
  (with-current-buffer riece-command-buffer
    (force-mode-line-update)))

(defun riece-update-channel-list-indicator ()
  (if (and riece-current-channels
	   ;; There is at least one channel.
	   (delq nil (copy-sequence riece-current-channels)))
      (let ((index 1))
	(setq riece-channel-list-indicator
	      (mapconcat
	       #'identity
	       (delq nil
		     (mapcar
		      (lambda (channel)
			(prog1 (if channel
				   (format "%d:%s" index channel))
			  (setq index (1+ index))))
		      riece-current-channels))
	       ",")))
    (setq riece-channel-list-indicator "No channel")))

(defun riece-update-buffers ()
  (run-hooks 'riece-update-buffer-functions)
  (force-mode-line-update t))

(eval-when-compile
  (autoload 'riece-channel-mode "riece"))
(defun riece-channel-buffer-create (identity)
  (with-current-buffer
      (riece-get-buffer-create (format riece-channel-buffer-format identity))
    (unless (eq major-mode 'riece-channel-mode)
      (riece-channel-mode)
      (let (buffer-read-only)
	(riece-insert-info (current-buffer)
			   (concat "Created on "
				   (funcall riece-format-time-function
					    (current-time))
				   "\n"))))
    (current-buffer)))

(eval-when-compile
  (autoload 'riece-user-list-mode "riece"))
(defun riece-user-list-buffer-create (identity)
  (with-current-buffer
      (riece-get-buffer-create (format riece-user-list-buffer-format identity))
    (unless (eq major-mode 'riece-user-list-mode)
      (riece-user-list-mode))
    (current-buffer)))

(defun riece-switch-to-channel (identity)
  (setq riece-last-channel riece-current-channel
	riece-current-channel identity
	riece-channel-buffer
	(cdr (riece-identity-assoc-no-server
	      identity riece-channel-buffer-alist))
	riece-user-list-buffer 
	(cdr (riece-identity-assoc-no-server
	      identity riece-user-list-buffer-alist))))

(defun riece-join-channel (channel-name)
  (let ((identity (riece-make-identity channel-name)))
    (unless (riece-identity-member-no-server
	     identity riece-current-channels)
      (setq riece-current-channels
	    (riece-identity-assign-binding
	     identity riece-current-channels
	     riece-default-channel-binding)))
    (unless (riece-identity-assoc-no-server
	     identity riece-channel-buffer-alist)
      (let ((buffer (riece-channel-buffer-create identity)))
	(setq riece-channel-buffer-alist
	      (cons (cons identity buffer)
		    riece-channel-buffer-alist))))
    (unless (riece-identity-assoc-no-server
	     identity riece-user-list-buffer-alist)
      (let ((buffer (riece-user-list-buffer-create identity)))
	(setq riece-user-list-buffer-alist
	      (cons (cons identity buffer)
		    riece-user-list-buffer-alist))))))

(defun riece-switch-to-nearest-channel (pointer)
  (let ((start riece-current-channels)
	identity)
    (while (and start (not (eq start pointer)))
      (if (car start)
	  (setq identity (car start)))
      (setq start (cdr start)))
    (unless identity
      (while (and pointer
		  (null (car pointer)))
	(setq pointer (cdr pointer)))
      (setq identity (car pointer)))
    (if identity
	(riece-switch-to-channel identity)
      (setq riece-last-channel riece-current-channel
	    riece-current-channel nil))))

(defun riece-part-channel (channel-name)
  (let* ((identity (riece-make-identity channel-name))
	 (pointer (riece-identity-member-no-server
		   identity riece-current-channels)))
    (if pointer
	(setcar pointer nil))
    ;;XXX
    (if (riece-identity-equal-no-server identity riece-current-channel)
	(riece-switch-to-nearest-channel pointer))))

(defun riece-configure-windows-predicate ()
  ;; The current channel is changed, and some buffers are visible.
  (unless (equal riece-last-channel riece-current-channel)
    (let ((buffers riece-buffer-list))
      (catch 'found
	(while buffers
	  (if (and (buffer-live-p (car buffers))
		   (get-buffer-window (car buffers)))
	      (throw 'found t)
	    (setq buffers (cdr buffers))))))))

(defun riece-redisplay-buffers (&optional force)
  (riece-update-buffers)
  (if (or force
	  (funcall riece-configure-windows-predicate))
      (funcall riece-configure-windows-function)))

(provide 'riece-display)