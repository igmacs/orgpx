;;; orgpx-open.el --- Open locations in Emacs or elsewhere  -*- lexical-binding: t; -*-

;;; Commentary:

;; This library is part of the package `orgpx'; it's not a standalone
;; library.  It allows to open your favorite locations in Emacs using
;; osm.el, or elsewhere like Google Maps

;;; Code:

(require 'org)
(require 'osm)
(require 'orgpx)

;;;###autoload
(defun orgpx-open-with-osm ()
  "Open location at point with osm."
  (interactive)
  (let ((lat (org-entry-get (point) "LATITUDE"))
        (lon (org-entry-get (point) "LONGITUDE")))
    (browse-url (format "geo:%s,%s;z=10" lat lon))))


;;;###autoload
(defun orgpx-open-with-google ()
  "Open location at point using Google Maps."
  (interactive)
  (let ((lat (org-entry-get (point) "LATITUDE"))
        (lon (org-entry-get (point) "LONGITUDE")))
    (browse-url (format "https://www.google.com/maps/search/?api=1&query=%s,%s" lat lon))))

;;;###autoload
(defun orgpx-osm-open-locations-in-file ()
  "Open with osm.el all locations in current file."
  (interactive)
  (let ((file (make-temp-file "orgpx-" nil ".gpx"))
        (orgpx-files (list buffer-file-name)))
    (orgpx-export file)
    (osm-open file)))


(provide 'orgpx-open)
;;; orgpx-open.el ends here
