;;; orgpx.el --- Organize your favorite places in Org Mode -*- lexical-binding: t; -*-

;;; Commentary:

;; More information is available in the README.org file.

;;; Code:

(defcustom orgpx-files nil
  "Files in which orgpx should look for favorite locations.
It should be a list of file names or a function that returns a list of
file names.")

(defun orgpx-location-files ()
  "Return the list of Org files in which to look for favorite locations."
  (if (functionp orgpx-files)
      (funcall orgpx-files)
    orgpx-files))
