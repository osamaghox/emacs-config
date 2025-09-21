;;; orgdoc-mouse.el --- Display Org link content on mouse hover -*- lexical-binding: t; -*-

;; Author: Prototype based on eldoc-mouse by Huang Feiyu
;; Version: 0.3
;; Package-Requires: ((emacs "30.1") (posframe "1.4.0") (org "9.6"))
;; Keywords: tools, convenience, org, mouse, hover
;; License: GPL-3.0-or-later

(require 'org)
(require 'posframe)
(require 'cl-lib)

(defgroup orgdoc-mouse nil
  "Display Org link content on mouse hover."
  :prefix "orgdoc-mouse-"
  :group 'org)

(defcustom orgdoc-mouse-idle-time 0.3
  "Idle seconds before showing Org link content."
  :type 'number
  :group 'orgdoc-mouse)

(defcustom orgdoc-mouse-posframe-buffer "*orgdoc-posframe*"
  "Buffer name for posframe display."
  :type 'string
  :group 'orgdoc-mouse)

(defcustom orgdoc-mouse-posframe-max-width 80
  "Maximum number of characters per line in posframe."
  :type 'number
  :group 'orgdoc-mouse)

(defcustom orgdoc-mouse-posframe-min-height 3
  "Minimum number of lines for the posframe."
  :type 'number
  :group 'orgdoc-mouse)

(defvar orgdoc-mouse-timer nil
  "Idle timer for mouse hover.")

(defvar-local orgdoc-mouse-overlay nil
  "Overlay for the link under mouse.")

(defvar-local orgdoc-mouse-last-bounds nil
  "Last processed bounds for hover.")

(defun orgdoc-mouse--extract-content (link)
  "Return the content of LINK (org-element)."
  (let ((type (org-element-property :type link))
        (path (org-element-property :path link)))
    (cond
     ((and (string= type "file") path (file-readable-p path))
      (with-temp-buffer
        (insert-file-contents path)
        (buffer-string)))
     ((string= type "id")
      (when-let* ((target (org-id-find path 'marker)))
        (with-current-buffer (marker-buffer target)
          (save-excursion
            (goto-char target)
            (if (org-at-heading-p)
                (prog1
                    (progn
                      (org-narrow-to-subtree)
                      (buffer-string))
                  (widen))
              (buffer-string))))))
     (t (format "Link: %s:%s" type path)))))

(defun orgdoc-mouse--posframe-quit ()
  "Close the orgdoc-mouse posframe safely."
  (interactive)
  (when orgdoc-mouse-overlay
    (delete-overlay orgdoc-mouse-overlay)
    (setq orgdoc-mouse-overlay nil))
  (when orgdoc-mouse-timer
    (cancel-timer orgdoc-mouse-timer)
    (setq orgdoc-mouse-timer nil))
  (posframe-hide orgdoc-mouse-posframe-buffer))

(defun orgdoc-mouse--show-doc-at (pos)
  "Show Org doc preview at POS if it's a link."
  (when (and pos (number-or-marker-p pos))
    (save-excursion
      (goto-char pos)
      (when-let* ((ctx (org-element-context))
                  (type (org-element-type ctx))
                  (begin (org-element-property :begin ctx)))
        (when (eq type 'link)
          ;; reset last bounds
          (setq orgdoc-mouse-last-bounds nil)
          (let* ((content (orgdoc-mouse--extract-content ctx))
                 (border-color (face-foreground 'default)))
            (when orgdoc-mouse-overlay
              (delete-overlay orgdoc-mouse-overlay))
            (setq orgdoc-mouse-overlay
                  (make-overlay (org-element-property :begin ctx)
                                (org-element-property :end ctx)))
            (overlay-put orgdoc-mouse-overlay 'face 'highlight)
            (when content
              (condition-case err
                  (progn
                    (posframe-show
                     orgdoc-mouse-posframe-buffer
                     :string content
                     :position (window-absolute-pixel-position pos)
                     :width orgdoc-mouse-posframe-max-width
                     :min-height orgdoc-mouse-posframe-min-height
                     :border-width 1
                     :border-color border-color
                     :accept-focus t
                     :keymap (let ((map (make-sparse-keymap)))
                               (define-key map (kbd "q") #'orgdoc-mouse--posframe-quit)
                               (define-key map (kbd "<wheel-up>") #'scroll-down-command)
                               (define-key map (kbd "<wheel-down>") #'scroll-up-command)
                               (define-key map (kbd "RET")
                                 (lambda ()
                                   (interactive)
                                   (org-open-at-point)))
                               map))
                    ;; تفعيل Org mode للعرض داخل posframe
                    (with-current-buffer orgdoc-mouse-posframe-buffer
                      (org-mode)
                      (read-only-mode 1)))
                (error
                 (message "orgdoc-mouse: posframe error %s" err)
                 (posframe-delete-all))))))))))

(defun orgdoc-mouse--on-mouse (event)
  "Trigger doc popup on mouse EVENT."
  (interactive "e")
  (let ((pos (posn-point (event-start event))))
    (when (and pos (number-or-marker-p pos) (derived-mode-p 'org-mode))
      (when orgdoc-mouse-timer
        (cancel-timer orgdoc-mouse-timer))
      (setq orgdoc-mouse-timer
            (run-with-idle-timer
             orgdoc-mouse-idle-time nil #'orgdoc-mouse--show-doc-at pos)))))

;;;###autoload
(defun orgdoc-mouse-enable ()
  "Enable orgdoc-mouse in Org buffers."
  (interactive)
  (setq track-mouse t)
  (local-set-key [mouse-movement] #'orgdoc-mouse--on-mouse))

;;;###autoload
(defun orgdoc-mouse-disable ()
  "Disable orgdoc-mouse."
  (interactive)
  (setq track-mouse nil)
  (local-unset-key [mouse-movement])
  (when orgdoc-mouse-timer
    (cancel-timer orgdoc-mouse-timer)
    (setq orgdoc-mouse-timer nil))
  (when orgdoc-mouse-overlay
    (delete-overlay orgdoc-mouse-overlay)
    (setq orgdoc-mouse-overlay nil))
  (posframe-hide orgdoc-mouse-posframe-buffer))

(provide 'orgdoc-mouse)

;;; orgdoc-mouse.el ends here


من هنا تمسح النصوص كامل ومنزل
;; ------------------------------
;; posframe (ضروري للـ hover)
;; ------------------------------
(use-package posframe
  :ensure t)

;; ------------------------------
;; eldoc-box (اختياري، لتحسين popups)
;; ------------------------------
(use-package eldoc-box
  :ensure t
  :hook (after-init . eldoc-box-hover-mode))

;; ------------------------------
;; eldoc-mouse-denote (hover للروابط)
;; ------------------------------
;; ضع الملف eldoc-mouse-denote.el في ~/.emacs.d/lisp/
(add-to-list 'load-path "~/.emacs.d/lisp/") ;; عدّل المسار إذا لزم
(require 'orgdoc-mouse)

;; تفعيل hover على روابط Denote في org-mode
(add-hook 'org-mode-hook #'orgdoc-mouse-enable)
