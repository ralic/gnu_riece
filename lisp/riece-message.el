;;; riece-message.el --- generate and display message line
;; Copyright (C) 1999-2003 Daiki Ueno

;; Author: Daiki Ueno <ueno@unixuser.org>
;; Keywords: message

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

(require 'riece-identity)
(require 'riece-channel)
(require 'riece-user)
(require 'riece-display)
(require 'riece-misc)

(defgroup riece-message nil
  "Messages"
  :tag "Message"
  :prefix "riece-"
  :group 'riece)

(defcustom riece-message-make-open-bracket-function
  #'riece-message-make-open-bracket
  "Function which makes `open-bracket' string for each message."
  :type 'function
  :group 'riece-message)

(defcustom riece-message-make-close-bracket-function
  #'riece-message-make-close-bracket
  "Function which makes `close-bracket' string for each message."
  :type 'function
  :group 'riece-message)

(defcustom riece-message-make-name-function
  #'riece-message-make-name
  "Function which makes local identity for each message."
  :type 'function
  :group 'riece-message)

(defcustom riece-message-make-global-name-function
  #'riece-message-make-global-name
  "Function which makes global identity for each message."
  :type 'function
  :group 'riece-message)

(defun riece-message-make-open-bracket (message)
  "Makes `open-bracket' string for MESSAGE."
  (riece-message-make-bracket message t))

(defun riece-message-make-close-bracket (message)
  "Makes `close-bracket' string for MESSAGE."
  (riece-message-make-bracket message nil))

(defun riece-message-make-bracket (message open-p)
  (if (eq open-p (riece-message-own-p message))
      (if (eq (riece-message-type message) 'notice)
	  "-"
	(if (riece-message-private-p message)
	    (if (riece-message-own-p message)
		">"
	      "=")
	  (if (riece-message-external-p message)
	      ")"
	    ">")))
    (if (eq (riece-message-type message) 'notice)
	"-"
      (if (riece-message-private-p message)
	  (if (riece-message-own-p message)
	      "<"
	    "=")
	(if (riece-message-external-p message)
	    "("
	  "<")))))

(defun riece-message-make-name (message)
  "Makes local identity for MESSAGE."
  (riece-identity-prefix
   (if (and (riece-message-private-p message)
	    (riece-message-own-p message))
       (riece-message-target message)
     (riece-message-speaker message))))

(defun riece-message-make-global-name (message)
  "Makes global identity for MESSAGE."
  (if (riece-message-private-p message)
      (if (riece-message-own-p message)
	  (riece-identity-prefix (riece-message-target message))
	(riece-identity-prefix (riece-message-speaker message)))
    (concat (riece-identity-prefix (riece-message-target message)) ":"
	    (riece-identity-prefix (riece-message-speaker message)))))

(defun riece-message-buffer (message)
  "Return the buffer where MESSAGE should appear."
  (let* ((target (if (riece-identity-equal-no-server
		      (riece-message-target message)
		      (riece-current-nickname))
		     (riece-message-speaker message)
		   (riece-message-target message)))
	 (entry (riece-identity-assoc-no-server
		 target riece-channel-buffer-alist)))
    (unless entry
      (riece-join-channel target)
      ;; If you are not joined any channel,
      ;; switch to the target immediately.
      (unless riece-current-channel
	(riece-switch-to-channel target))
      (riece-redisplay-buffers)
      (setq entry (riece-identity-assoc-no-server
		   target riece-channel-buffer-alist)))
    (cdr entry)))

(defun riece-message-parent-buffers (message buffer)
  "Return the parents of BUFFER where MESSAGE should appear.
Normally they are *Dialogue* and/or *Others*."
  (if (or (and buffer (riece-frozen buffer))
	  (and riece-current-channel
	       (not (riece-identity-equal-no-server
		     (riece-message-target message)
		     riece-current-channel))))
      (list riece-dialogue-buffer riece-others-buffer)
    riece-dialogue-buffer))

(defun riece-display-message (message)
  "Display MESSAGE object."
  (let* ((open-bracket
	  (funcall riece-message-make-open-bracket-function message))
	 (close-bracket
	  (funcall riece-message-make-close-bracket-function message))
	 (name
	  (funcall riece-message-make-name-function message))
	 (global-name
	  (funcall riece-message-make-global-name-function message))
	 (buffer (riece-message-buffer message))
	 (parent-buffers (riece-message-parent-buffers message buffer)))
    (riece-insert buffer
		  (concat open-bracket name close-bracket
			  " " (riece-message-text message) "\n"))
    (riece-insert parent-buffers
		  (concat
		   (riece-concat-server-name
		    (concat open-bracket global-name close-bracket
			    " " (riece-message-text message)))
		   "\n"))
    (run-hook-with-args 'riece-after-display-message-functions message)))

(defun riece-make-message (speaker target text &optional type own-p)
  "Make an instance of message object.
Arguments are appropriate to the sender, the receiver, and text
content, respectively.
Optional 4th argument TYPE specifies the type of the message.
Currently possible values are `action' and `notice'.
Optional 5th argument is the flag to indicate that this message is not
from the network."
  (vector speaker target text type own-p))

(defun riece-message-speaker (message)
  "Return the sender of MESSAGE."
  (aref message 0))

(defun riece-message-target (message)
  "Return the receiver of MESSAGE."
  (aref message 1))

(defun riece-message-text (message)
  "Return the text part of MESSAGE."
  (aref message 2))

(defun riece-message-type (message)
  "Return the type of MESSAGE.
Currently possible values are `action' and `notice'."
  (aref message 3))

(defun riece-message-own-p (message)
  "Return t if MESSAGE is not from the network."
  (aref message 4))

(defun riece-message-private-p (message)
  "Return t if MESSAGE is a private message."
  (if (riece-message-own-p message)
      (not (riece-channel-p (riece-message-target message)))
    (riece-identity-equal-no-server
     (riece-message-target message)
     (riece-current-nickname))))

(defun riece-message-external-p (message)
  "Return t if MESSAGE is from outside the channel."
  (not (riece-identity-member-no-server
	(riece-message-target message)
	(mapcar #'riece-make-identity
		(riece-user-get-channels (riece-message-speaker message))))))

(defun riece-own-channel-message (message &optional channel type)
  "Display MESSAGE as you sent to CHNL."
  (riece-display-message
   (riece-make-message (riece-current-nickname)
		       (or channel riece-current-channel)
		       message type t)))

(provide 'riece-message)

;;; riece-message.el ends here