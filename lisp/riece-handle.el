;;; riece-handle.el --- basic message handlers
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

(eval-when-compile (require 'riece-inlines))

(require 'riece-misc)
(require 'riece-message)
(require 'riece-channel)
(require 'riece-naming)
(require 'riece-display)

(defun riece-handle-nick-message (prefix string)
  (let* ((old (riece-prefix-nickname prefix))
	 (new (car (riece-split-parameters string)))
	 (channels (riece-user-get-channels old))
	 (visible (riece-identity-member-no-server
		   riece-current-channel channels)))
    (riece-naming-assert-rename old new)
    (let ((pointer (riece-identity-member-no-server
		    (riece-make-identity old)
		    riece-current-channels)))
      (when pointer
	(setcar pointer (riece-make-identity new))
	(setcar (riece-identity-assoc-no-server (riece-make-identity old)
						riece-channel-buffer-alist)
		(riece-make-identity new))
	(setcar (riece-identity-assoc-no-server (riece-make-identity old)
						riece-user-list-buffer-alist)
		(riece-make-identity new))
	(if (riece-identity-equal-no-server (riece-make-identity old)
					    riece-current-channel)
	    (riece-switch-to-channel (riece-make-identity new)))
	(setq channels (cons (riece-make-identity new) channels))))
    (riece-insert-change (mapcar
			  (lambda (channel)
			    (cdr (riece-identity-assoc-no-server
				  (riece-make-identity channel)
				  riece-channel-buffer-alist)))
			  channels)
			 (format "%s -> %s\n" old new))
    (riece-insert-change (if visible
			     riece-dialogue-buffer
			   (list riece-dialogue-buffer riece-others-buffer))
			 (concat
			  (riece-concat-server-name
			   (format "%s -> %s" old new))
			  "\n"))
    (riece-redisplay-buffers)))

(defun riece-handle-privmsg-message (prefix string)
  (let* ((user (riece-prefix-nickname prefix))
	 (parameters (riece-split-parameters string))
	 (targets (split-string (car parameters) ","))
	 (message (nth 1 parameters)))
    (unless (equal message "")		;not ignored by server?
      (riece-display-message
       (riece-make-message user (riece-make-identity (car targets))
			   message)))))

(defun riece-handle-notice-message (prefix string)
  (let* ((user (if prefix
		   (riece-prefix-nickname prefix)))
	 (parameters (riece-split-parameters string))
	 (targets (split-string (car parameters) ","))
	 (message (nth 1 parameters)))
    (unless (equal message "")		;not ignored by server?
      (if user
	  (riece-display-message
	   (riece-make-message user (riece-make-identity (car targets))
			       message 'notice))
	;; message from server
	(riece-insert-notice
	 (list riece-dialogue-buffer riece-others-buffer)
	 (concat (riece-concat-server-name message) "\n"))))))

(defun riece-handle-ping-message (prefix string)
  (riece-send-string (format "PONG :%s\r\n"
			     (if (eq (aref string 0) ?:)
				 (substring string 1)
			       string))))

(defun riece-handle-join-message (prefix string)
  (let ((user (riece-prefix-nickname prefix))
	(channels (split-string (car (riece-split-parameters string)) ",")))
    (while channels
      (riece-naming-assert-join user (car channels))
      ;;XXX
      (if (string-equal-ignore-case user riece-real-nickname)
	  (riece-switch-to-channel (riece-make-identity (car channels))))
      (let ((buffer (cdr (riece-identity-assoc-no-server
			  (riece-make-identity (car channels))
			  riece-channel-buffer-alist))))
	(riece-insert-change
	 buffer
	 (format "%s (%s) has joined %s\n"
		 user
		 (riece-user-get-user-at-host user)
		 (car channels)))
	(riece-insert-change
	 (if (and riece-channel-buffer-mode
		  (not (eq buffer riece-channel-buffer)))
	     (list riece-dialogue-buffer riece-others-buffer)
	   riece-dialogue-buffer)
	 (concat
	  (riece-concat-server-name
	   (format "%s (%s) has joined %s"
		   user
		   (riece-user-get-user-at-host user)
		   (car channels)))
	  "\n")))
      (setq channels (cdr channels)))
    (riece-redisplay-buffers)))

(defun riece-handle-part-message (prefix string)
  (let* ((user (riece-prefix-nickname prefix))
	 (parameters (riece-split-parameters string))
	 (channels (split-string (car parameters) ","))
	 (message (nth 1 parameters)))
    (while channels
      (riece-naming-assert-part user (car channels))
      (let ((buffer (cdr (riece-identity-assoc-no-server
			  (riece-make-identity (car channels))
			  riece-channel-buffer-alist))))
	(riece-insert-change
	 buffer
	 (concat
	  (riece-concat-message
	   (format "%s has left %s" user (car channels))
	   message)
	  "\n"))
	(riece-insert-change
	 (if (and riece-channel-buffer-mode
		  (not (eq buffer riece-channel-buffer)))
	     (list riece-dialogue-buffer riece-others-buffer)
	   riece-dialogue-buffer)
	 (concat
	  (riece-concat-server-name
	   (riece-concat-message
	    (format "%s has left %s" user (car channels))
	    message))
	  "\n")))
      (setq channels (cdr channels)))
    (riece-redisplay-buffers)))

(defun riece-handle-kick-message (prefix string)
  (let* ((kicker (riece-prefix-nickname prefix))
	 (parameters (riece-split-parameters string))
	 (channel (car parameters))
	 (user (nth 1 parameters))
	 (message (nth 2 parameters)))
    (riece-naming-assert-part user channel)
    (let ((buffer (cdr (riece-identity-assoc-no-server
			(riece-make-identity channel)
			riece-channel-buffer-alist))))
      (riece-insert-change
       buffer
       (concat
	(riece-concat-message
	 (format "%s kicked %s out from %s" kicker user channel)
	 message)
	"\n"))
      (riece-insert-change
       (if (and riece-channel-buffer-mode
		(not (eq buffer riece-channel-buffer)))
	   (list riece-dialogue-buffer riece-others-buffer)
	 riece-dialogue-buffer)
       (concat
	(riece-concat-server-name
	 (riece-concat-message
	  (format "%s kicked %s out from %s\n" kicker user channel)
	  message))
	"\n")))
    (riece-redisplay-buffers)))

(defun riece-handle-quit-message (prefix string)
  (let* ((user (riece-prefix-nickname prefix))
	 (channels (copy-sequence (riece-user-get-channels user)))
	 (pointer channels)
	 (message (car (riece-split-parameters string))))
    ;; If you are quitting, no need to cleanup.
    (unless (string-equal-ignore-case user riece-real-nickname)
      ;; You were talking with the user.
      (if (riece-identity-member-no-server (riece-make-identity user)
					   riece-current-channels)
	  (riece-part-channel user)) ;XXX
      (setq pointer channels)
      (while pointer
	(riece-naming-assert-part user (car pointer))
	(setq pointer (cdr pointer)))
      (let ((buffers
	     (mapcar
	      (lambda (channel)
		(cdr (riece-identity-assoc-no-server
		      (riece-make-identity channel)
		      riece-channel-buffer-alist)))
	      channels)))
	(riece-insert-change buffers
			     (concat (riece-concat-message
				      (format "%s has left IRC" user)
				      message)
				     "\n"))
	(riece-insert-change (if (and riece-channel-buffer-mode
				      (not (memq riece-channel-buffer
						 buffers)))
				 (list riece-dialogue-buffer
				       riece-others-buffer)
			       riece-dialogue-buffer)
			     (concat
			      (riece-concat-server-name
			       (riece-concat-message
				(format "%s has left IRC" user)
				message))
			      "\n"))))
    (riece-redisplay-buffers)))

(defun riece-handle-kill-message (prefix string)
  (let* ((killer (riece-prefix-nickname prefix))
	 (parameters (riece-split-parameters string))
	 (user (car parameters))
	 (message (nth 1 parameters))
	 (channels (copy-sequence (riece-user-get-channels user)))
	 pointer)
    ;; You were talking with the user.
    (if (riece-identity-member-no-server (riece-make-identity user)
					 riece-current-channels)
	(riece-part-channel user)) ;XXX
    (setq pointer channels)
    (while pointer
      (riece-naming-assert-part user (car pointer))
      (setq pointer (cdr pointer)))
    (let ((buffers
	   (mapcar
	    (lambda (channel)
	      (cdr (riece-identity-assoc-no-server
		    (riece-make-identity channel)
		    riece-channel-buffer-alist)))
	    channels)))
      (riece-insert-change buffers
			   (concat (riece-concat-message
				    (format "%s killed %s" killer user)
				    message)
				   "\n"))
      (riece-insert-change (if (and riece-channel-buffer-mode
				    (not (memq riece-channel-buffer
					       buffers)))
			       (list riece-dialogue-buffer
				     riece-others-buffer)
			     riece-dialogue-buffer)
			   (concat
			    (riece-concat-server-name
			     (riece-concat-message
			      (format "%s killed %s" killer user)
			     message))
			    "\n")))
    (riece-redisplay-buffers)))

(defun riece-handle-invite-message (prefix string)
  (let* ((user (riece-prefix-nickname prefix))
	 (parameters (riece-split-parameters string))
	 (channel (car parameters)))
    (riece-insert-info
     (list riece-dialogue-buffer riece-others-buffer)
     (concat
      (riece-concat-server-name
       (format "%s invites you to %s" user channel))
      "\n"))))

(defun riece-handle-topic-message (prefix string)
  (let* ((user (riece-prefix-nickname prefix))
	 (parameters (riece-split-parameters string))
	 (channel (car parameters))
	 (topic (nth 1 parameters)))
    (riece-channel-set-topic (riece-get-channel channel) topic)
    (let ((buffer (cdr (riece-identity-assoc-no-server
			(riece-make-identity channel)
			riece-channel-buffer-alist))))
      (riece-insert-change
       buffer
       (format "Topic by %s: %s\n" user topic))
      (riece-insert-change
       (if (and riece-channel-buffer-mode
		(not (eq buffer riece-channel-buffer)))
	   (list riece-dialogue-buffer riece-others-buffer)
	 riece-dialogue-buffer)
       (concat
	(riece-concat-server-name
	 (format "Topic on %s by %s: %s" channel user topic))
	"\n"))
      (riece-redisplay-buffers))))

(defsubst riece-parse-channel-modes (string channel)
  (while (string-match "^[-+]\\([^ ]*\\) *" string)
    (let ((toggle (aref string 0))
	  (modes (string-to-list (match-string 1 string))))
      (setq string (substring string (match-end 0)))
      (while modes
	(if (and (memq (car modes) '(?O ?o ?v ?k ?l ?b ?e ?I))
		 (string-match "\\([^-+][^ ]*\\) *" string))
	    (let ((parameter (match-string 1 string)))
	      (setq string (substring string (match-end 0)))
	      (cond
	       ((eq (car modes) ?o)
		(riece-channel-toggle-operator channel parameter
					       (eq toggle ?+)))
	       ((eq (car modes) ?v)
		(riece-channel-toggle-speaker channel parameter
					      (eq toggle ?+)))
	       ((eq (car modes) ?b)
		(riece-channel-toggle-banned channel parameter
					     (eq toggle ?+)))
	       ((eq (car modes) ?e)
		(riece-channel-toggle-uninvited channel parameter
						(eq toggle ?+)))
	       ((eq (car modes) ?I)
		(riece-channel-toggle-invited channel parameter
					      (eq toggle ?+)))))
	  (riece-channel-toggle-mode channel (car modes)
				     (eq toggle ?+)))
	(setq modes (cdr modes))))))

(defun riece-handle-mode-message (prefix string)
  (let ((user (riece-prefix-nickname prefix))
	channel)
    (when (string-match "\\([^ ]+\\) *:?" string)
      (setq channel (match-string 1 string)
	    string (substring string (match-end 0)))
      (riece-parse-channel-modes string channel)
      (let ((buffer (cdr (riece-identity-assoc-no-server
			  (riece-make-identity channel)
			  riece-channel-buffer-alist))))
	(riece-insert-change
	 buffer
	 (format "Mode by %s: %s\n" user string))
	(riece-insert-change
	 (if (and riece-channel-buffer-mode
		  (not (eq buffer riece-channel-buffer)))
	     (list riece-dialogue-buffer riece-others-buffer)
	   riece-dialogue-buffer)
	 (concat
	  (riece-concat-server-name
	   (format "Mode on %s by %s: %s" channel user string))
	  "\n"))
	(riece-redisplay-buffers)))))

(provide 'riece-handle)

;;; riece-handle.el ends here