;;; orgpx-open.el --- Open locations in Emacs or elsewhere  -*- lexical-binding: t; -*-

;;; Commentary:

;; This library is part of the package `orgpx'; it's not a standalone
;; library.  It allows to open your favorite locations in Emacs using
;; osm.el, or elsewhere like Google Maps

;;; Code:

(require 'org)
(require 'org-ql)
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


(defun orgpx-haversine-km (lat1 lon1 lat2 lon2)
  "Return distance in kilometers between LAT1/LON1 and LAT2/LON2."
  (let* ((r 6371.0) ; Earth radius in km
         (dlat (degrees-to-radians (- lat2 lat1)))
         (dlon (degrees-to-radians (- lon2 lon1)))
         (a (+ (expt (sin (/ dlat 2.0)) 2)
               (* (cos (degrees-to-radians lat1))
                  (cos (degrees-to-radians lat2))
                  (expt (sin (/ dlon 2.0)) 2))))
         (c (* 2.0 (atan (sqrt a) (sqrt (- 1.0 a))))))
    (* r c)))

(defun orgpx-locations-nearby (latitude longitude radius-km tags)
  "Return locations within a radius of a reference.
Return markers for locations within RADIUS-KM km of the coordinates given by
LATITUDE and LONGITUDE, and with any of the tags given by the TAGS list."
  (org-ql-select (orgpx-location-files)
    `(and (tags ,@tags)
          (property "LATITUDE")
          (property "LATITUDE")
          (let ((lat (string-to-number (org-entry-get (point) "LATITUDE")))
                (lon (string-to-number (org-entry-get (point) "LONGITUDE"))))
            (<= (my/org-haversine-km
                 lat lon ,latitude ,longitude)
                ,radius-km)))
    :action #'point-marker))

(defun orgpx-osm-open (latitude longitude radius tags)
  "Open with osm.el locations within a radius of some reference coordinates.
The reference coordinates is given by LATITUDE and LONGITUDE, the radius
by RADIUS, and a list of tags TAGS can also be specified so that only
locations matching any of those tags are selected."
  (let ((file (make-temp-file "orgpx-" nil ".gpx"))
        (markers (orgpx-locations-nearby latitude longitude radius tags)))
    (orgpx-export file markers)
    (osm-open file)))


(provide 'orgpx-open)
;;; orgpx-open.el ends here
