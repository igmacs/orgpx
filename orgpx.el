;;; orgpx.el --- Organize your favorite places in Org Mode -*- lexical-binding: t; -*-

;; Version: 0.1.0
;; Package-Requires: ((emacs "30.2") (org "9.8") (osm "2.4") (org-ql "0.8.10"))
;; URL: https://github.com/igmacs/orgpx

;;; Commentary:

;; More information is available in the README.org file.

;;; Code:

(require 'org)
(require 'osm)

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
  (let* ((element (org-element-at-point))
         (begin (org-element-property :contents-begin element))
         (end   (org-element-property :contents-end element)))
    (save-excursion
      (goto-char begin)
      (while
          (re-search-forward org-drawer-regexp end t)
        nil)
      (string-trim-right (buffer-substring-no-properties (+ (point) 1) end)))))


(defun orgpx-get-places ()
  "Collect orgpx places for exporting."
  (let (markers)
    (org-map-entries
     (lambda () (push (point-marker) markers))
     "+LATITUDE={.+}" (orgpx-location-files) 'archive 'comment)
    (nreverse markers)))

(defun orgpx-export-place (marker)
  "Return as a string the gpx entry corresponding to the place at MARKER."
  (with-current-buffer (marker-buffer marker)
    (save-excursion
      (goto-char marker)
      (let ((name (org-entry-get (point) "ITEM"))
            (lat (org-entry-get (point) "LATITUDE"))
            (lon (org-entry-get (point) "LONGITUDE"))
            (type (car (reverse
                        (delete "ATTACH" (org-get-tags)))))
            (desc (orgpx--get-entry-description)))
         (with-temp-buffer
           (insert
            (concat
             (format "<wpt lat=\"%s\" lon=\"%s\">\n" lat lon)
             (format "<name>%s</name>\n" name)
             (format "<type>%s</type>\n" type)
             (format "<desc><![CDATA[\n%s\n]]></desc>\n" desc)
             "</wpt>\n"))
           (buffer-string))))))

;;;###autoload
(defun orgpx-export (file &optional markers)
  "Collect favorite locations and export them to gpx file FILE.
By default, collect all locations, but optional argument MARKERS
allows to specify a only a subset of them as a list of their markers."
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
    (dolist (marker (or markers (orgpx-get-places)))
      (insert (orgpx-export-place marker)))
    (goto-char (point-max))
    (insert "</gpx>")
    (indent-region (point-min) (point-max))
    (write-file file)
    (kill-current-buffer)))


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


(defvar orgpx--collected-tags nil)

(defun orgpx--collect-tags ()
  "Collect all tags currently being used by locations."
  (if orgpx--collected-tags
      orgpx--collected-tags
    (setq
     orgpx--collected-tags
     (delete-dups
      (flatten-list
       (org-map-entries
        (lambda () (org-get-tags))
        "+LATITUDE={.+}" (orgpx-location-files) 'archive 'comment))))))

;;;###autoload
(defun orgpx-add-tag ()
  "Add tag to location, offering completion from alredy used tags."
  (interactive)
  (let ((tag (completing-read "Add tag: " (orgpx--collect-tags) nil t)))
    (org-back-to-heading t) ; ensure we are on a heading
    (org-set-tags (cons tag (org-get-tags nil t)))))

(provide 'orgpx)

;;; orgpx.el ends here
