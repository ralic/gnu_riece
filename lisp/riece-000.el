;;; riece-000.el --- handlers for 000 replies
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
(require 'riece-filter)			;riece-default-handle-message
(require 'riece-version)

(eval-when-compile
  (autoload 'riece-default-handle-numeric-reply "riece-filter"))
(defun riece-handle-default-000-message (prefix number name string)
  (setq riece-nick-accepted 'ok)
  (riece-default-handle-numeric-reply
   riece-info-prefix prefix number name string))

(defun riece-handle-001-message (prefix number name string)
  "RPL_WELCOME \"Welcome to the Internet Relay Network <nick>!<user>@<host>\""
  (setq riece-real-server-name prefix
	riece-real-nickname name
	riece-real-userhost nil)
  (riece-send-string (format "USERHOST %s\r\n" riece-real-nickname))
  (riece-insert-info
   (list riece-dialogue-buffer riece-others-buffer)
   (concat (substring string 1) "\n")))

(defun riece-handle-004-message (prefix number name string)
  "RPL_MYINFO \"<umodes> <chnlmodes>\""
  (if (string-match "^[^ ]+ +[^ ]+ +\\([^ ]+\\) +" string)
      (setq riece-supported-user-modes
	    (string-to-list (match-string 1 string))
	    riece-supported-channel-modes
	    (string-to-list (substring string (match-end 0))))
    (riece-insert-info
     (list riece-dialogue-buffer riece-others-buffer)
     (concat string "\n"))))

(provide 'riece-000)

;;; riece-000.el ends here