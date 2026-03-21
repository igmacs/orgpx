;;; orgpx.el --- Organize your favorite places in Org Mode -*- lexical-binding: t; -*-

;;; Commentary:

;; More information is available in the README.org file.

;;; Code:

(require 'org)

(defcustom orgpx-files nil
  "Files in which orgpx should look for favorite locations.
It should be a list of file names or a function that returns a list of
file names.")

(defun orgpx-location-files ()
  "Return the list of Org files in which to look for favorite locations."
  (if (functionp orgpx-files)
      (funcall orgpx-files)
    orgpx-files))


(defun orgpx--get-entry-description ()
  "Get the description of a favorite location entry (i.e., its body)."
  (interactive)
  (let* ((element (org-element-at-point))
         (begin (org-element-property :contents-begin element))
         (end   (org-element-property :contents-end element)))
    (save-excursion
      (goto-char begin)
      (while
          (re-search-forward org-drawer-regexp end t)
        nil)
      (string-trim-right (buffer-substring-no-properties (+ (point) 1) end)))))


(defun orgpx-export (file)
  "Collect favorite locations and export them to gpx file FILE."
  (interactive)
  (save-window-excursion
    (switch-to-buffer (generate-new-buffer "orgpx-export"))
    (xml-mode)
    (insert
     (concat
      ;; Just copied verbatim the header of the gpx file exported by
      ;; OsmAnd in my phone
      "<?xml version='1.0' encoding='UTF-8' standalone='yes' ?>\n"
      "<gpx version=\"1.1\" creator=\"OsmAnd~ 4.0.9\" xmlns=\"http://www.topografix.com/GPX/1/1\" xmlns:osmand=\"https://osmand.net\" xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\" xsi:schemaLocation=\"http://www.topografix.com/GPX/1/1 http://www.topografix.com/GPX/1/1/gpx.xsd\">\n"
      "  <metadata>\n"
      "    <name>favourites</name>\n"
      "  </metadata>\n"))
    (org-map-entries
     (lambda ()
       (let ((name (org-entry-get (point) "ITEM"))
             (lat (org-entry-get (point) "LATITUDE"))
             (lon (org-entry-get (point) "LONGITUDE"))
             (type (car (reverse
                         (delete "ATTACH" (org-get-tags)))))
             (desc (orgpx--get-entry-description)))
         (with-current-buffer "orgpx-export"
           (insert
            (concat
             (format "<wpt lat=\"%s\" lon=\"%s\">\n" lat lon)
             (format "<name>%s</name>\n" name)
             (format "<type>%s</type>\n" type)
             (format "<desc><![CDATA[\n%s\n]]></desc>\n" desc)
             "</wpt>\n")))))
     "+LATITUDE={.+}" (orgpx-location-files) 'archive 'comment)
    (goto-char (point-max))
    (insert "</gpx>")
    (indent-region (point-min) (point-max))
    (write-file file)
    (kill-current-buffer)))


(defun orgpx-open-with-osm ()
  "Open location at point with osm."
  (interactive)
  (let ((lat (org-entry-get (point) "LATITUDE"))
        (lon (org-entry-get (point) "LONGITUDE")))
    (browse-url (format "geo:%s,%s;z=10" lat lon))))


(defun orgpx-open-with-google ()
  "Open location at point using Google Maps."
  (interactive)
  (let ((lat (org-entry-get (point) "LATITUDE"))
        (lon (org-entry-get (point) "LONGITUDE")))
    (browse-url (format "https://www.google.com/maps/search/?api=1&query=%s,%s" lat lon))))


(defun orgpx--get-coordinates-from-current-kill ()
  "Get location coordinates from current kill (usually a link)."
  (let ((k (current-kill 0 t)))
    (or

     ;; Option 1: delegate to osm.el which already does this well
     (condition-case _
         (cl-letf (((symbol-function #'osm--goto)
                    (lambda (lat long &rest _)
                      (list (number-to-string lat) (number-to-string long)))))
           (osm-url k))
       ('user-error nil))


     ;; --- Pattern 1: simple 'lat, lon' like '41.37418, 2.13877'
     (when (string-match
            "^\\([+-]?[0-9.]+\\)[ ,]+\\([+-]?[0-9.]+\\)$"
            k)
       (list (match-string 1 k) (match-string 2 k)))

     ;; --- Pattern 2: Telegram shared locations: 🌐 41.378907N, 2.154296E
     (when (string-match
            " \\([+-]?[0-9.]+\\)N[ ,] \\([+-]?[0-9.]+\\)E"
            k)
       (list
        (match-string 1 k)
        (match-string 2 k))))))


(defun orgpx-get-latitude-from-current-kill ()
  "Return latitude if valid, else empty string (which will force prompting)."
  (let ((coordinates (orgpx--get-coordinates-from-current-kill)))
    (if coordinates (car coordinates) "")))

(defun orgpx-get-longitude-from-current-kill ()
  "Return longitude if valid, else empty string (which will force prompting)."
  (let ((coordinates (orgpx--get-coordinates-from-current-kill))) ;; TODO: don't compute this again
    (if coordinates (car (cdr coordinates)) "")))

(provide 'orgpx)

;;; orgpx.el ends here
