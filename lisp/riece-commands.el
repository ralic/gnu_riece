;;; riece-commands.el --- commands available in command buffer
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

(require 'riece-channel)
(require 'riece-complete)
(require 'riece-layout)
(require 'riece-display)
(require 'riece-server)
(require 'riece-misc)
(require 'riece-identity)
(require 'riece-message)

(autoload 'derived-mode-class "derived")

;;; Channel movement:
(defun riece-command-switch-to-channel (channel)
  (interactive (list (riece-completing-read-identity
		      "Switch to channel/user: "
		      riece-current-channels nil t)))
  (unless (equal channel riece-current-channel)
    (riece-switch-to-channel channel)))

(defun riece-command-switch-to-channel-by-number (number)
  (interactive
   (let ((command-name (symbol-name this-command)))
     (if (string-match "[0-9]+$" command-name)
	 (list (string-to-number (match-string 0 command-name)))
       (list (string-to-number (read-string "Switch to number: "))))))
  (let ((channel (nth (1- number) riece-current-channels)))
    (if channel
	(riece-command-switch-to-channel channel)
      (error "No such number!"))))

(eval-and-compile
  (let ((number 1))
    (while (<= number 20)
      (defalias (intern (concat "riece-command-switch-to-channel-by-number-"
				(number-to-string number)))
	'riece-command-switch-to-channel-by-number)
      (setq number (1+ number)))))

(defun riece-command-next-channel ()
  "Select the next channel."
  (interactive)
  (when (> (length riece-current-channels) 1)
    (let ((pointer (cdr (riece-identity-member
			 riece-current-channel
			 riece-current-channels))))
      (while (and pointer
		  (null (car pointer)))
	(setq pointer (cdr pointer)))
      (when (null pointer)
	(setq pointer riece-current-channels)
	(while (and pointer
		    (null (car pointer)))
	  (setq pointer (cdr pointer))))
      (if (car pointer)
	  (riece-command-switch-to-channel (car pointer))
	(error "No such channel!")))))

(defun riece-command-previous-channel ()
  "Select the previous channel."
  (interactive)
  (when (> (length riece-current-channels) 1)
    (let ((pointer (riece-identity-member
		    riece-current-channel
		    riece-current-channels))
	  (start riece-current-channels)
	  channel)
      (while (and start (not (eq start pointer)))
	(if (car start)
	    (setq channel (car start)))
	(setq start (cdr start)))
      (when (null channel)
	(setq start (copy-sequence riece-current-channels))
	(setq start (delq nil start))
	(and (> (length start) 1)
	     (setq channel (nth (1- (length start)) start))))
      (if channel
	  (riece-command-switch-to-channel channel)
	(error "No such channel!")))))

(defun riece-command-select-command-buffer ()
  "Select the command buffer."
  (interactive)
  (let ((window (get-buffer-window riece-command-buffer)))
    (if window
	(select-window window))))

(defun riece-command-configure-windows ()
  (interactive)
  (riece-redisplay-buffers t))

(defun riece-command-change-layout (name)
  "Select a layout-name from all current available layouts and change
the layout to the selected layout-name."
  (interactive (list (completing-read "Change layout: " riece-layout-alist)))
  (setq riece-layout name
	riece-save-variables-are-dirty t)
  (riece-command-configure-windows))

(defun riece-command-toggle-channel-buffer-mode ()
  (interactive)
  (setq riece-channel-buffer-mode
	(not riece-channel-buffer-mode)
	riece-save-variables-are-dirty t)
  (riece-command-configure-windows))

(defun riece-command-toggle-user-list-buffer-mode ()
  (interactive)
  (setq riece-user-list-buffer-mode
	(not riece-user-list-buffer-mode)
	riece-save-variables-are-dirty t)
  (riece-command-configure-windows))

(defun riece-command-toggle-channel-list-buffer-mode ()
  (interactive)
  (setq riece-channel-list-buffer-mode
	(not riece-channel-list-buffer-mode)
	riece-save-variables-are-dirty t)
  (riece-command-configure-windows))

(defun riece-command-finger (user &optional recurse)
  (interactive
   (let* ((completion-ignore-case t)
	  (user (riece-completing-read-identity
		 "Finger user: "
		 (riece-get-users-on-server (riece-current-server-name))
		 nil nil nil nil nil t)))
     (list user current-prefix-arg)))
  (if recurse
      (riece-send-string (format "WHOIS %s %s\r\n"
				 (riece-identity-prefix user)
				 (riece-identity-prefix user)))
    (riece-send-string (format "WHOIS %s\r\n" (riece-identity-prefix user)))))

(defun riece-command-topic (topic)
  (interactive
   (progn
     (riece-check-channel-commands-are-usable t)
     (list (read-from-minibuffer
	    "Set topic: " (cons (or (riece-with-server-buffer
				     (riece-identity-server
				      riece-current-channel)
				     (riece-channel-get-topic
				      (riece-identity-prefix
				       riece-current-channel)))
				    "")
				0)))))
  (riece-send-string (format "TOPIC %s :%s\r\n"
			     (riece-identity-prefix riece-current-channel)
			     topic)))

(defun riece-command-invite (user)
  (interactive
   (let ((completion-ignore-case t))
     (riece-check-channel-commands-are-usable t)
     (list (riece-completing-read-identity
	    "Invite user: "
	    (riece-get-users-on-server (riece-current-server-name))
	    nil nil nil nil nil t))))
  (riece-send-string (format "INVITE %s %s\r\n"
			     (riece-identity-prefix user)
			     (riece-identity-prefix riece-current-channel))))

(defun riece-command-kick (user &optional message)
  (interactive
   (let ((completion-ignore-case t))
     (riece-check-channel-commands-are-usable t)
     (list (completing-read
	    "Kick user: "
	    (riece-with-server-buffer
		(riece-identity-server riece-current-channel)
	      (riece-channel-get-users (riece-identity-prefix
					riece-current-channel))))
	   (if current-prefix-arg
	       (read-string "Message: ")))))
  (riece-send-string
   (if message
       (format "KICK %s %s :%s\r\n"
	       (riece-identity-prefix riece-current-channel)
	       user message)
     (format "KICK %s %s\r\n"
	     (riece-identity-prefix riece-current-channel)
	     user))))

(defun riece-command-names (pattern)
  (interactive
   (let ((completion-ignore-case t))
     (list (read-from-minibuffer
	    "NAMES pattern: "
	    (if (and riece-current-channel
		     (riece-channel-p (riece-identity-prefix
				       riece-current-channel)))
		(cons (riece-identity-prefix riece-current-channel)
		      0))))))
  (if (or (not (equal pattern ""))
	  (yes-or-no-p "Really want to query NAMES without argument? "))
      (riece-send-string (format "NAMES %s\r\n" pattern))))

(defun riece-command-who (pattern)
  (interactive
   (let ((completion-ignore-case t))
     (list (read-from-minibuffer
	    "WHO pattern: "
	    (if (and riece-current-channel
		     (riece-channel-p (riece-identity-prefix
				       riece-current-channel)))
		(cons (riece-identity-prefix riece-current-channel)
		      0))))))
  (if (or (not (equal pattern ""))
	  (yes-or-no-p "Really want to query WHO without argument? "))
      (riece-send-string (format "WHO %s\r\n" pattern))))

(defun riece-command-list (pattern)
  (interactive
   (let ((completion-ignore-case t))
     (list (read-from-minibuffer
	    "LIST pattern: "
	    (if (and riece-current-channel
		     (riece-channel-p (riece-identity-prefix
				       riece-current-channel)))
		(cons (riece-identity-prefix riece-current-channel)
		      0))))))
  (if (or (not (equal pattern ""))
	  (yes-or-no-p "Really want to query LIST without argument? "))
      (riece-send-string (format "LIST %s\r\n" pattern))))

(defun riece-command-change-mode (channel change)
  (interactive
   (let* ((completion-ignore-case t)
	  (channel
	   (if current-prefix-arg
	       (riece-completing-read-identity
		"Change mode for channel/user: "
		(riece-get-identities-on-server (riece-current-server-name))
		nil nil nil nil nil t)
	     (riece-check-channel-commands-are-usable t)
	     riece-current-channel))
	  (riece-overriding-server-name (riece-identity-server channel))
	  (riece-temp-minibuffer-message
	   (concat "[Available modes: "
		   (riece-with-server-buffer (riece-identity-server channel)
		     (if (riece-channel-p (riece-identity-prefix channel))
			 (if riece-supported-channel-modes
			     (apply #'string riece-supported-channel-modes))
		       (if riece-supported-user-modes
			   (apply #'string riece-supported-user-modes))))
		   "]")))
     (list channel
	   (read-from-minibuffer
	    (concat (riece-concat-channel-modes
		     channel "Mode (? for help)") ": ")
	    nil riece-minibuffer-map))))
  (riece-send-string (format "MODE %s :%s\r\n" (riece-identity-prefix channel)
			     change)))

(defun riece-command-set-operators (users &optional arg)
  (interactive
   (progn
     (riece-check-channel-commands-are-usable t)
     (let ((completion-ignore-case t))
       (list (riece-completing-read-multiple
	      (if current-prefix-arg
		  "Unset +o for users"
		"Set +o for users")
	      (riece-with-server-buffer
		  (riece-identity-server riece-current-channel)
		(riece-channel-get-users (riece-identity-prefix
					 riece-current-channel)))
	      (if current-prefix-arg
		  (lambda (user)
		    (memq ?o (cdr user)))
		(lambda (user)
		  (not (memq ?o (cdr user))))))
	     current-prefix-arg))))
  (let (group)
    (while users
      (setq group (cons (car users) group)
	    users (cdr users))
      (when (or (= (length group) 3)
		(null users))
	(riece-send-string
	 (format "MODE %s %c%s %s\r\n"
		 (riece-identity-prefix riece-current-channel)
		 (if current-prefix-arg
		     ?-
		   ?+)
		 (make-string (length group) ?o)
		 (mapconcat #'identity (nreverse group) " ")))
	(setq group nil)))))

(defun riece-command-set-speakers (users &optional arg)
  (interactive
   (progn
     (riece-check-channel-commands-are-usable t)
     (let ((completion-ignore-case t))
       (list (riece-completing-read-multiple
	      (if current-prefix-arg
		  "Unset +v for users"
		"Set +v for users")
	      (riece-with-server-buffer
		  (riece-identity-server riece-current-channel)
		(riece-channel-get-users (riece-identity-prefix
					  riece-current-channel)))
	      (if current-prefix-arg
		  (lambda (user)
		    (memq ?v (cdr user)))
		(lambda (user)
		  (not (memq ?v (cdr user))))))
	     current-prefix-arg))))
  (let (group)
    (while users
      (setq group (cons (car users) group)
	    users (cdr users))
      (when (or (= (length group) 3)
		(null users))
	(riece-send-string
	 (format "MODE %s %c%s %s\r\n"
		 (riece-identity-prefix riece-current-channel)
		 (if current-prefix-arg
		     ?-
		   ?+)
		 (make-string (length group) ?v)
		 (mapconcat #'identity (nreverse group) " ")))
	(setq group nil)))))

(defun riece-command-send-message (message notice)
  "Send MESSAGE to the current channel."
  (if (equal message "")
      (error "No text to send"))
  (riece-check-channel-commands-are-usable)
  (if notice
      (progn
	(riece-send-string
	 (format "NOTICE %s :%s\r\n"
		 (riece-identity-prefix riece-current-channel)
		 message))
	(riece-display-message
	 (riece-make-message (riece-current-nickname) riece-current-channel
			     message 'notice t)))
    (riece-send-string
     (format "PRIVMSG %s :%s\r\n"
	     (riece-identity-prefix riece-current-channel)
	     message))
    (riece-display-message
     (riece-make-message (riece-current-nickname) riece-current-channel
			 message nil t))))

(defun riece-command-enter-message ()
  "Send the current line to the current channel."
  (interactive)
  (riece-command-send-message (buffer-substring
			       (riece-line-beginning-position)
			       (riece-line-end-position))
			      nil)
  (let ((next-line-add-newlines t))
    (next-line 1)))

(defun riece-command-enter-message-as-notice ()
  "Send the current line to the current channel as NOTICE."
  (interactive)
  (riece-command-send-message (buffer-substring
			       (riece-line-beginning-position)
			       (riece-line-end-position))
			      t)
  (let ((next-line-add-newlines t))
    (next-line 1)))

(defun riece-command-enter-message-to-user (user)
  "Send the current line to USER."
  (interactive
   (let ((completion-ignore-case t))
     (list (riece-completing-read-identity
	    "Message to user: "
	    (riece-get-users-on-server (riece-current-server-name))
	    nil nil nil nil nil t))))
  (let ((text (buffer-substring
	       (riece-line-beginning-position)
	       (riece-line-end-position))))
    (riece-send-string
     (format "PRIVMSG %s :%s\r\n" (riece-identity-prefix user) text))
    (riece-display-message
     (riece-make-message (riece-current-nickname) user text nil t)))
  (let ((next-line-add-newlines t))
    (next-line 1)))

(defun riece-command-join-channel (target key)
  (let ((process (riece-server-process (riece-identity-server target))))
    (unless process
      (error "%s" (substitute-command-keys
		   "Type \\[riece-command-open-server] to open server.")))
    (riece-process-send-string process
			       (if key
				   (format "JOIN %s :%s\r\n"
					   (riece-identity-prefix target)
					   key)
				 (format "JOIN %s\r\n"
					 (riece-identity-prefix target))))))

(defun riece-command-join-partner (target)
  (let ((pointer (riece-identity-member target riece-current-channels)))
    (if pointer
	(riece-command-switch-to-channel (car pointer))
      (riece-join-channel target)
      (riece-switch-to-channel target))))

(defun riece-command-join (target &optional key)
  (interactive
   (let* ((completion-ignore-case t)
	  (target
	   (if riece-join-channel-candidate
	       (let ((default (riece-format-identity
			       riece-join-channel-candidate)))
		 (riece-completing-read-identity
		  (format "Join channel/user (default %s): " default)
		  (riece-get-identities-on-server (riece-current-server-name))
		  nil nil nil nil default))
	     (riece-completing-read-identity
	      "Join channel/user: "
	      (riece-get-identities-on-server (riece-current-server-name)))))
	  key)
     (if (and current-prefix-arg
	      (riece-channel-p (riece-identity-prefix target)))
	 (setq key
	       (riece-read-passwd (format "Key for %s: "
					  (riece-format-identity target)))))
     (list target key)))
  (let ((pointer (riece-identity-member target riece-current-channels)))
    (if pointer
	(riece-command-switch-to-channel (car pointer))
      (if (riece-channel-p (riece-identity-prefix target))
	  (riece-command-join-channel target key)
	(riece-command-join-partner target)))))

(defun riece-command-part-channel (target message)
  (let ((process (riece-server-process (riece-identity-server target))))
    (riece-process-send-string process
			       (if message
				   (format "PART %s :%s\r\n"
					   (riece-identity-prefix target)
					   message)
				 (format "PART %s\r\n"
					 (riece-identity-prefix target))))))

(defun riece-command-part (target &optional message)
  (interactive
   (progn
     (riece-check-channel-commands-are-usable)
     (let* ((completion-ignore-case t)
	    (target
	     (riece-completing-read-identity
	      (format "Part from channel/user (default %s): "
		      (riece-format-identity riece-current-channel))
	      riece-current-channels nil nil nil nil
	      (riece-format-identity riece-current-channel)))
	    message)
       (if (and current-prefix-arg
		(riece-channel-p (riece-identity-prefix target)))
	   (setq message (read-string "Message: ")))
       (list target message))))
  (if (riece-identity-member target riece-current-channels)
      (if (riece-channel-p (riece-identity-prefix target))
	  (riece-command-part-channel target message)
	(riece-part-channel target))
    (error "You are not talking with %s" target)))

(defun riece-command-change-nickname (nickname)
  "Change your nickname to NICK."
  (interactive "sEnter your nickname: ")
  (riece-send-string (format "NICK %s\r\n" nickname)))

(defun riece-command-scroll-down (lines)
  "Scroll LINES down dialogue buffer from command buffer."
  (interactive "P")
  (let ((buffer (if (and riece-channel-buffer-mode
			 riece-current-channel)
		    riece-channel-buffer
		  riece-dialogue-buffer)))
    (if (get-buffer-window buffer)
	(condition-case nil
	    (let ((other-window-scroll-buffer buffer))
	      (scroll-other-window-down lines))
	  (beginning-of-buffer
	   (message "Beginning of buffer"))))))

(defun riece-command-scroll-up (lines)
  "Scroll LINES up dialogue buffer from command buffer."
  (interactive "P")
  (let ((buffer (if (and riece-channel-buffer-mode
			 riece-current-channel)
		    riece-channel-buffer
		  riece-dialogue-buffer)))
    (if (get-buffer-window buffer)
	(condition-case nil
	    (let ((other-window-scroll-buffer buffer))
	      (scroll-other-window lines))
	  (end-of-buffer
	   (message "End of buffer"))))))

(defun riece-command-user-list-scroll-down (lines)
  "Scroll LINES down user list buffer from command buffer."
  (interactive "P")
  (if (get-buffer-window riece-user-list-buffer)
      (condition-case nil
	  (let ((other-window-scroll-buffer riece-user-list-buffer))
	    (scroll-other-window-down lines))
	(beginning-of-buffer
	 (message "Beginning of buffer")))))

(defun riece-command-user-list-scroll-up (lines)
  "Scroll LINES up user list buffer from command buffer."
  (interactive "P")
  (if (get-buffer-window riece-user-list-buffer)
      (condition-case nil
	  (let ((other-window-scroll-buffer riece-user-list-buffer))
	    (scroll-other-window lines))
	(end-of-buffer
	 (message "End of buffer")))))

(defun riece-command-toggle-away (&optional message)
  "Mark yourself as being away."
  (interactive
   (if (and (not (riece-with-server-buffer (riece-identity-server
					    (riece-current-nickname))
		   (riece-user-get-away (riece-identity-prefix
					 (riece-current-nickname)))))
	    current-prefix-arg)
       (list (read-from-minibuffer
	      "Away message: " (cons (or riece-away-message "") 0)))))
  (if (riece-with-server-buffer (riece-identity-server
				 (riece-current-nickname))
	(riece-user-get-away (riece-identity-prefix
			      (riece-current-nickname))))
      (riece-send-string "AWAY\r\n")
    (riece-send-string (format "AWAY :%s\r\n" (or message
						  riece-away-message)))))

(defun riece-command-toggle-freeze (&optional arg)
  "Prevent automatic scrolling of the dialogue window.
If prefix argument ARG is non-nil, toggle frozen status."
  (interactive "P")
  (with-current-buffer (if (eq (derived-mode-class major-mode)
			       'riece-dialogue-mode)
			   (current-buffer)
			 (if (and riece-channel-buffer-mode
				  riece-channel-buffer)
			     riece-channel-buffer
			   riece-dialogue-buffer))
    (setq riece-freeze (if arg
			   (< 0 (prefix-numeric-value arg))
			 (not riece-freeze)))
    (riece-emit-signal 'buffer-freeze-changed
		       (current-buffer) riece-freeze)))

(defun riece-command-toggle-own-freeze (&optional arg)
  "Prevent automatic scrolling of the dialogue window.
The difference from `riece-command-freeze' is that your messages are hidden.
If prefix argument ARG is non-nil, toggle frozen status."
  (interactive "P")
  (with-current-buffer (if (eq (derived-mode-class major-mode)
			       'riece-dialogue-mode)
			   (current-buffer)
			 (if (and riece-channel-buffer-mode
				  riece-channel-buffer)
			     riece-channel-buffer
			   riece-dialogue-buffer))
    (if (if arg
	    (< 0 (prefix-numeric-value arg))
	  (not (eq riece-freeze 'own)))
	(setq riece-freeze 'own)
      (setq riece-freeze nil))
    (riece-emit-signal 'buffer-freeze-changed
		       (current-buffer) riece-freeze)))

(eval-when-compile
  (autoload 'riece-exit "riece"))
(defun riece-command-quit (&optional arg)
  "Quit IRC."
  (interactive "P")
  (if (null riece-server-process-alist)
      (progn
	(message "No server process")
	(ding))
    (if (y-or-n-p "Really quit IRC? ")
	(let ((message
	       (if arg
		   (read-string "Message: ")
	       riece-quit-message))
	      (alist riece-server-process-alist))
	  (while alist
	    (riece-quit-server-process (cdr (car alist)) message)
	    (setq alist (cdr alist)))))))

(defun riece-command-raw (command)
  "Enter raw IRC command, which is sent to the server."
  (interactive "sIRC command: ")
  (riece-send-string (concat command "\r\n")))

(defun riece-command-end-of-buffer ()
  "Get end of the dialogue buffer."
  (interactive)
  (let (buffer window)
    (setq buffer (if riece-channel-buffer-mode
		     riece-channel-buffer
		   riece-dialogue-buffer))
    (or (setq window (get-buffer-window buffer))
	(setq window (get-buffer-window riece-dialogue-buffer)
	      buffer riece-dialogue-buffer))
    (when window
      (save-selected-window
	(select-window window)
	(goto-char (point-max))))))

(defun riece-command-copy-region (start end)
  "Move current region between START and END to `kill-ring'."
  (interactive "r")
  (kill-new (buffer-substring-no-properties start end)))

(defun riece-command-complete-user ()
  "Complete a user name in the current buffer."
  (interactive)
  (let* ((completion-ignore-case t)
	 (table (mapcar (lambda (user)
			  (list (riece-format-identity user t)))
			(riece-get-users-on-server
			 (riece-current-server-name))))
	 (current (current-word))
	 (completion (try-completion current table))
	 (all (all-completions current table)))
    (if (eq completion t)
	nil
      (if (null completion)
	  (message "Can't find completion for \"%s\"" current)
	(if (equal current completion)
	    (with-output-to-temp-buffer "*Help*"
	      (display-completion-list all))
	  (delete-region (point) (- (point) (length current)))
	  (insert completion))))))

(defun riece-command-open-server (server-name)
  (interactive
   (list (completing-read "Open server: " riece-server-alist)))
  (if (riece-server-process server-name)
      (error "%s is already opened" server-name))
  (riece-open-server
   (riece-server-name-to-server server-name)
   server-name))

(defun riece-command-close-server (server-name &optional message)
  (interactive
   (list (completing-read "Close server: " riece-server-process-alist)
	 (if current-prefix-arg
	     (read-string "Message: ")
	   riece-quit-message)))
  (riece-quit-server-process (riece-server-process server-name) message))

(defun riece-command-universal-server-name-argument ()
  (interactive)
  (let* ((riece-overriding-server-name
	  (completing-read "Server: " riece-server-process-alist))
	 (command
	  (key-binding (read-key-sequence
			(format "Command to execute on \"%s\":"
				riece-overriding-server-name)))))
    (message "")
    (call-interactively command)))

(provide 'riece-commands)

;;; riece-commands.el ends here
