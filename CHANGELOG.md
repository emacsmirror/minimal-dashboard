# CHANGELOG

## 0.1.5

- Add `minimal-dashboard-image-position`, `minimal-dashboard-text-position` and `minimal-dashboard-gap`: place image and text independently on a 3x3 grid, or attach text above/below the image
- Add `minimal-dashboard-mode` (derived from `special-mode`); `minimal-dashboard-mode-hook` now runs when the mode is enabled, before the contents are drawn
- Fix: `keymap-set` required Emacs 29 although Emacs 27.1 is declared; use `define-key`
- Fix: resize redraw used the selected window's size instead of the dashboard window's
- Fix: function values of `minimal-dashboard-text` are re-evaluated on every call instead of being frozen
- Fix: setters no longer call the text function at configuration time
- Fix: layout uses window body size (excludes mode-line); line numbers, `hl-line` and line truncation are disabled locally
- Layout is computed in pixels using the window's (zoomed) default-face character size, and redraws on `text-scale-mode-hook`, so `text-scale-adjust` keeps everything aligned
- Skip redraws when the window body size did not change; drop the per-buffer `kill-buffer-hook` lambda

## 0.1.4

- Update the resizing gif in README
- Add note about package installation in README from MELPA
- Fix `minimal-dashboard--resize-handler`: correctly add buffer-local `window-size-change-functions` hook and clean it up via `kill-buffer-hook`; removing resize handling when disabled now works
- Fix `minimal-dashboard--refresh-buffer-name`: resolved name is now stored in an internal variable instead of overwriting the user-facing `minimal-dashboard-buffer-name`, preserving function values across calls
- Fix `minimal-dashboard-mode-hook`: now runs after the buffer is fully set up (read-only, keymaps, resize hook) rather than before
- Cache mouse keymaps for image and text click handlers; maps are built once on `defcustom` change instead of on every render/resize
- Cache image pixel size alongside the image object to avoid redundant `image-size` calls on resize
- Unify duplicated text-line insertion loop into a single `dolist`
- Remove redundant bare `defvar` declarations shadowed by `defcustom` definitions
- Remove commented-out dead code

## 0.1.3

- User option to customize the scale of the dashboard image

## 0.1.2

- Allow function/string for image-path
- Mouse button click callback on text and image

## 0.1.1

- Add customization options for changing image and text
- Propertize the text with face
- Allow function/string for text

## 0.1

- Display image and text with center alignment
