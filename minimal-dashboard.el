;;; minimal-dashboard.el --- A very minimal dashboard plugin -*- lexical-binding: t; -*-

;; Copyright (C) 2025 Dheeraj Vittal Shenoy

;; Author: Dheeraj Vittal Shenoy <dheerajshenoy22@gmail.com>
;; Maintainer: Dheeraj Vittal Shenoy <dheerajshenoy22@gmail.com>
;; URL: https://github.com/dheerajshenoy/minimal-dashboard.el
;; Version: 0.1.5
;; Package-Requires: ((emacs "27.1"))
;; Keywords: startup, screen, tools, dashboard


;; This file is NOT part of GNU Emacs.


;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or (at
;; your option) any later version.
;;
;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.
;;
;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <https://www.gnu.org/licenses/>.

;;; Commentary:

;; A very minimal dashboard plugin for Emacs — displays a centered
;; image and message when Emacs starts, with optional window resize
;; responsiveness and layout control.

;;; Code:

(defgroup minimal-dashboard nil
  "Group for `minimal-dashboard'."
  :prefix "minimal-dashboard-"
  :group 'applications)

;;; Faces

(defface minimal-dashboard-text-face
  '((t :inherit shadow))
  "Face used for dashboard text."
  :group 'minimal-dashboard)

;;; Forward declarations (the setters below run while the options are defined)

(defvar minimal-dashboard-text)
(defvar minimal-dashboard-buffer-name)
(defvar minimal-dashboard-enable-resize-handling)
(defvar minimal-dashboard-modeline-shown)

;;; Internal state

(defvar minimal-dashboard--cached-image nil
  "Cached `minimal-dashboard' image.")

(defvar minimal-dashboard--cached-image-path nil
  "File path of the currently cached dashboard image.")

(defvar minimal-dashboard--cached-image-size nil
  "Size of the cached image as (WIDTH . HEIGHT), in pixels.")

(defvar minimal-dashboard--cached-text nil
  "Cached `minimal-dashboard' text.")

(defvar minimal-dashboard--resolved-buffer-name nil
  "Resolved name of the dashboard buffer.")

(defvar minimal-dashboard--image-mouse-map nil
  "Cached keymap for dashboard image mouse clicks.")

(defvar minimal-dashboard--text-mouse-map nil
  "Cached keymap for dashboard text mouse clicks.")

(defvar-local minimal-dashboard--last-size nil
  "Metrics (BODY-W BODY-H CHAR-W CHAR-H), in pixels, at the last render.")

(defconst minimal-dashboard--grid
  '(top-left top-center top-right
    center-left center center-right
    bottom-left bottom-center bottom-right)
  "Positions available on the 3x3 layout grid.")

;;; Helpers (must precede the options: `:set' functions run at definition time)

(defun minimal-dashboard--build-mouse-map (handler)
  "Return a keymap bound to all three mouse buttons calling HANDLER, or nil."
  (when handler
    (let ((map (make-sparse-keymap)))
      (dolist (btn '(mouse-1 mouse-2 mouse-3))
        (define-key map (vector btn)
                    (lambda (event)
                      (interactive "e")
                      (funcall handler event))))
      map)))

(defun minimal-dashboard--invalidate-image ()
  "Invalidate the cached image so it is rebuilt on the next render."
  (setq minimal-dashboard--cached-image nil
        minimal-dashboard--cached-image-path nil
        minimal-dashboard--cached-image-size nil))

(defun minimal-dashboard--refresh-cached-text ()
  "Re-evaluate `minimal-dashboard-text' and cache the result."
  (setq minimal-dashboard--cached-text
        (if (functionp minimal-dashboard-text)
            (funcall minimal-dashboard-text)
          minimal-dashboard-text)))

(defun minimal-dashboard--refresh-buffer-name ()
  "Resolve and return the dashboard buffer name, caching it in an internal var."
  (setq minimal-dashboard--resolved-buffer-name
        (if (functionp minimal-dashboard-buffer-name)
            (funcall minimal-dashboard-buffer-name)
          minimal-dashboard-buffer-name)))

(defun minimal-dashboard--buffer ()
  "Return the live dashboard buffer, or nil."
  (and minimal-dashboard--resolved-buffer-name
       (get-buffer minimal-dashboard--resolved-buffer-name)))

(defun minimal-dashboard--resize-handler ()
  "Set up or tear down resize handling for the current buffer."
  (if minimal-dashboard-enable-resize-handling
      (add-hook 'window-size-change-functions #'minimal-dashboard--on-resize nil t)
    (remove-hook 'window-size-change-functions #'minimal-dashboard--on-resize t)))

(defun minimal-dashboard--set-and-redraw (symbol value)
  "Set SYMBOL to VALUE, then redraw the dashboard if it is visible."
  (set-default symbol value)
  ;; Runs at definition time too, before `minimal-dashboard--redraw' exists.
  (when (fboundp 'minimal-dashboard--redraw)
    (minimal-dashboard--redraw)))

;;; Custom variables

(defcustom minimal-dashboard-image-scale 1.0
  "Scale of the dashboard image."
  :type 'float
  :group 'minimal-dashboard
  :set (lambda (symbol value)
         (set-default symbol value)
         (minimal-dashboard--invalidate-image)))

(defcustom minimal-dashboard-buffer-name "*My Dashboard*"
  "Name of the `minimal-dashboard' buffer.

Can be a string or a function returning a string."
  :type '(choice
          (string :tag "Buffer name")
          (function :tag "Function returning a buffer name"))
  :group 'minimal-dashboard
  :set (lambda (symbol value)
         (set-default symbol value)
         (minimal-dashboard--refresh-buffer-name)))

(defcustom minimal-dashboard-enable-resize-handling t
  "If non-nil, re-center information in dashboard buffer when window is resized."
  :type 'boolean
  :group 'minimal-dashboard
  :set (lambda (symbol value)
         (set-default symbol value)
         (when-let* ((buf (minimal-dashboard--buffer)))
           (with-current-buffer buf
             (minimal-dashboard--resize-handler)))))

(defcustom minimal-dashboard-image-path
  (expand-file-name "images/splash.svg" data-directory)
  "Path to the image displayed in the dashboard.

Can be a string (path) or a function returning a path.
If nil, no image is shown."
  :type '(choice
          (string :tag "Path to image")
          (function :tag "Function returning a path")
          (const :tag "No image" nil))
  :group 'minimal-dashboard
  :set (lambda (symbol value)
         (set-default symbol value)
         (minimal-dashboard--invalidate-image)))

(defcustom minimal-dashboard-modeline-shown nil
  "Visibility of the mode-line in the dashboard buffer."
  :type 'boolean
  :group 'minimal-dashboard)

(defcustom minimal-dashboard-text "Welcome to Emacs"
  "Text displayed in the dashboard.

If it's a string, it will be inserted directly.
If it's a function, it should return a string.  A function is
re-evaluated every time `minimal-dashboard' is called."
  :type '(choice
          (string :tag "Static text")
          (function :tag "Function returning text"))
  :group 'minimal-dashboard
  :set (lambda (symbol value)
         (set-default symbol value)
         (setq minimal-dashboard--cached-text nil)))

(defcustom minimal-dashboard-image-position 'center
  "Position of the dashboard image on a 3x3 grid.

One of `top-left', `top-center', `top-right', `center-left',
`center', `center-right', `bottom-left', `bottom-center' or
`bottom-right'."
  :type `(choice ,@(mapcar (lambda (s) (list 'const s))
                           minimal-dashboard--grid))
  :group 'minimal-dashboard
  :set #'minimal-dashboard--set-and-redraw)

(defcustom minimal-dashboard-text-position 'below-image
  "Position of the dashboard text.

Either one of the grid positions accepted by
`minimal-dashboard-image-position', or:
- `below-image': text is attached below the image.
- `above-image': text is attached above the image.

Attached text moves together with the image, and is aligned the
same way horizontally."
  :type `(choice (const below-image)
                 (const above-image)
                 ,@(mapcar (lambda (s) (list 'const s))
                           minimal-dashboard--grid))
  :group 'minimal-dashboard
  :set #'minimal-dashboard--set-and-redraw)

(defcustom minimal-dashboard-gap 1
  "Blank rows between the image and attached text."
  :type 'integer
  :group 'minimal-dashboard
  :set #'minimal-dashboard--set-and-redraw)

(defcustom minimal-dashboard-image-click-handler nil
  "Function to call when the dashboard image is clicked.

Supports `mouse-1' (left), `mouse-2' (middle), and `mouse-3' (right).
The function receives the mouse event as its argument.

Example:

\(setq `minimal-dashboard-image-click-handler'
      (lambda (event)
        (pcase (event-basic-type event)
          (`mouse-1 (function1))
          (`mouse-2 (function2))
          (`mouse-3 (function3)))))"
  :type '(choice (const nil) function)
  :group 'minimal-dashboard
  :set (lambda (symbol value)
         (set-default symbol value)
         (setq minimal-dashboard--image-mouse-map
               (minimal-dashboard--build-mouse-map value))))

(defcustom minimal-dashboard-text-click-handler nil
  "Function to call when the dashboard text is clicked.

Supports `mouse-1' (left), `mouse-2' (middle), and `mouse-3' (right).
The function receives the mouse event as its argument.

Example:

\(setq `minimal-dashboard-text-click-handler'
      (lambda (event)
        (pcase (event-basic-type event)
          (`mouse-1 (function1))
          (`mouse-2 (function2))
          (`mouse-3 (function3)))))"
  :type '(choice (const nil) function)
  :group 'minimal-dashboard
  :set (lambda (symbol value)
         (set-default symbol value)
         (setq minimal-dashboard--text-mouse-map
               (minimal-dashboard--build-mouse-map value))))

;;; Mode

(defvar minimal-dashboard-mode-map
  (let ((map (make-sparse-keymap)))
    (define-key map (kbd "q") #'kill-current-buffer)
    map)
  "Keymap for `minimal-dashboard-mode'.")

(define-derived-mode minimal-dashboard-mode special-mode "Dashboard"
  "Major mode of the `minimal-dashboard' buffer."
  (unless minimal-dashboard-modeline-shown
    (setq-local mode-line-format nil))
  (setq-local cursor-type nil
              truncate-lines t
              display-line-numbers nil
              show-trailing-whitespace nil
              global-hl-line-mode nil
              revert-buffer-function
              (lambda (&rest _)
                (minimal-dashboard--refresh-cached-text)
                (minimal-dashboard--redraw)))
  (minimal-dashboard--resize-handler)
  ;; Zooming changes the cell size without resizing the window.
  (add-hook 'text-scale-mode-hook #'minimal-dashboard--redraw nil t))

;;; Core functions

(defun minimal-dashboard--get-cached-image ()
  "Return the cached dashboard image, rebuilding it if the path changed."
  (let ((path (if (functionp minimal-dashboard-image-path)
                  (funcall minimal-dashboard-image-path)
                minimal-dashboard-image-path)))
    (if (not (and path (file-exists-p path)))
        (progn (minimal-dashboard--invalidate-image) nil)
      (unless (and minimal-dashboard--cached-image
                   (equal path minimal-dashboard--cached-image-path))
        (let ((img (create-image path nil nil
                                 :scale minimal-dashboard-image-scale)))
          (setq minimal-dashboard--cached-image img
                minimal-dashboard--cached-image-path path
                minimal-dashboard--cached-image-size (image-size img t))))
      minimal-dashboard--cached-image)))

(defun minimal-dashboard--get-cached-text ()
  "Return the cached text, computing and caching it if needed."
  (or minimal-dashboard--cached-text
      (minimal-dashboard--refresh-cached-text)))

(defun minimal-dashboard--split-pos (pos)
  "Return (VERTICAL . HORIZONTAL) for grid position POS."
  (if (eq pos 'center)
      '(center . center)
    (let ((parts (split-string (symbol-name pos) "-")))
      (cons (intern (car parts)) (intern (cadr parts))))))

(defun minimal-dashboard--row (vertical win-h height)
  "Start row of a block of HEIGHT rows at VERTICAL within WIN-H rows."
  (max 0 (floor (pcase vertical
                  ('top 0)
                  ('bottom (- win-h height))
                  (_ (/ (- win-h height) 2))))))

(defun minimal-dashboard--col (horizontal win-w width)
  "Start column of a block of WIDTH columns at HORIZONTAL within WIN-W."
  (max 0 (floor (pcase horizontal
                  ('left 0)
                  ('right (- win-w width))
                  (_ (/ (- win-w width) 2))))))

(defun minimal-dashboard--image-string (image col)
  "Return IMAGE as a string indented by COL columns."
  (concat (make-string col ?\s)
          (apply #'propertize " " 'display image
                 (when minimal-dashboard--image-mouse-map
                   (list 'mouse-face 'highlight
                         'keymap minimal-dashboard--image-mouse-map)))))

(defun minimal-dashboard--text-string (lines horizontal win-w)
  "Return LINES as one string, each aligned at HORIZONTAL within WIN-W."
  (mapconcat
   (lambda (line)
     (let ((s (copy-sequence line)))
       ;; APPEND = t so faces already present in the string win.
       (add-face-text-property 0 (length s) 'minimal-dashboard-text-face t s)
       (when minimal-dashboard--text-mouse-map
         (add-text-properties 0 (length s)
                              (list 'mouse-face 'highlight
                                    'keymap minimal-dashboard--text-mouse-map)
                              s))
       (concat (make-string (minimal-dashboard--col horizontal win-w
                                                    (string-width line))
                            ?\s)
               s)))
   lines "\n"))

(defun minimal-dashboard--layout (win-w win-h img-w img-h lines)
  "Return a list of (ROW HEIGHT KIND COL-OR-ALIGN) blocks, sorted by row.

WIN-W and WIN-H are the window body size, IMG-W and IMG-H the image
size (0 when there is no image) and LINES the text lines."
  (let* ((has-img (> img-h 0))
         (n (length lines))
         (gap (if (and has-img lines) minimal-dashboard-gap 0))
         (ipos (minimal-dashboard--split-pos minimal-dashboard-image-position))
         (tpos minimal-dashboard-text-position)
         (attached (memq tpos '(below-image above-image)))
         (img-row 0) (txt-row 0) (txt-horiz (cdr ipos))
         blocks)
    (if attached
        (let ((top (minimal-dashboard--row
                    (car ipos) win-h (+ img-h gap n))))
          (if (eq tpos 'below-image)
              (setq img-row top txt-row (+ top img-h gap))
            (setq txt-row top img-row (+ top n gap))))
      (let ((tp (minimal-dashboard--split-pos tpos)))
        (setq img-row (minimal-dashboard--row (car ipos) win-h img-h)
              txt-row (minimal-dashboard--row (car tp) win-h n)
              txt-horiz (cdr tp))))
    (when has-img
      (push (list img-row img-h 'image
                  (minimal-dashboard--col (cdr ipos) win-w img-w))
            blocks))
    (when lines
      (push (list txt-row n 'text txt-horiz) blocks))
    (sort blocks (lambda (a b) (< (car a) (car b))))))

(defun minimal-dashboard--metrics (window)
  "Return (BODY-W BODY-H CHAR-W CHAR-H) in pixels for WINDOW.

The character size is taken from the default face as displayed in
WINDOW, so it follows `text-scale-adjust' zooming."
  (list (window-body-width window t) (window-body-height window t)
        (window-font-width window) (window-font-height window)))

(defun minimal-dashboard--render (window)
  "Insert the dashboard contents for WINDOW into the current buffer."
  (pcase-let* ((metrics (minimal-dashboard--metrics window))
               (`(,body-w ,body-h ,cw ,ch) metrics)
               (cw (max 1 cw))
               (ch (max 1 ch))
               ;; Window size and image size in (zoomed) character cells.
               (win-w (/ body-w (float cw)))
               (win-h (/ body-h (float ch)))
               (image (when (display-images-p) (minimal-dashboard--get-cached-image)))
               (img-w (if image (/ (car minimal-dashboard--cached-image-size)
                                   (float cw))
                        0))
               (img-h (if image (ceiling (/ (cdr minimal-dashboard--cached-image-size)
                                            (float ch)))
                        0))
               (text (minimal-dashboard--get-cached-text))
               (lines (when (and (stringp text) (not (string-empty-p text)))
                        (split-string text "\n")))
               (cur 0)
               (first t))
    (dolist (block (minimal-dashboard--layout win-w win-h img-w img-h lines))
      (pcase-let ((`(,row ,height ,kind ,arg) block))
        ;; The first block starts on buffer line 0 (row 0).  Afterwards we sit
        ;; on the last line of the previous block, so one more newline is
        ;; needed to reach the row where the previous block ended.
        (insert-char ?\n (if first row (max 1 (1+ (- row cur)))))
        (insert (if (eq kind 'image)
                    (minimal-dashboard--image-string image arg)
                  (minimal-dashboard--text-string lines arg win-w)))
        (setq cur (+ (max row cur) height)
              first nil)))
    (setq minimal-dashboard--last-size metrics)
    (goto-char (point-min))))

(defun minimal-dashboard--redraw (&optional only-if-resized)
  "Redraw the dashboard buffer if it is displayed.

With ONLY-IF-RESIZED, do nothing when the window body size and
character size are unchanged since the last render."
  (when-let* ((buf (minimal-dashboard--buffer))
              (win (get-buffer-window buf)))
    (with-current-buffer buf
      (unless (and only-if-resized
                   (equal minimal-dashboard--last-size
                          (minimal-dashboard--metrics win)))
        (let ((inhibit-read-only t))
          (erase-buffer)
          (minimal-dashboard--render win))))))

(defun minimal-dashboard--on-resize (&optional _frame)
  "Redraw the dashboard when its window is resized."
  (minimal-dashboard--redraw t))

;;; Entry point

;;;###autoload
(defun minimal-dashboard ()
  "Show the minimal dashboard buffer."
  (interactive)
  (minimal-dashboard--refresh-cached-text)
  (let ((buf (get-buffer-create (minimal-dashboard--refresh-buffer-name))))
    (delete-other-windows)
    (switch-to-buffer buf)
    (with-current-buffer buf
      (minimal-dashboard-mode)
      (minimal-dashboard--redraw))
    buf))

(provide 'minimal-dashboard)

;;; minimal-dashboard.el ends here
