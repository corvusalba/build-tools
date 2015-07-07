#lang racket

(require racket/format)
(require racket/file)

(define postfix "-linux")
(define base-version "0.1.4")
(define build 101)
(define is-snapshot? #t)

(define temp-filename "temp.tmp")

(define (is-assembly-info? filename)
  (regexp-match #rx".*AssemblyInfo.cs$" filename))

(define assembly-info-files
  (find-files is-assembly-info? #f))

(define (version-line param value)
  (~a "[assembly: " param "(\"" value "\")]"))

(define padded-build
  (~r build #:min-width 4 #:pad-string "0"))

(define assembly-version
  (~a base-version ".0"))

(define assembly-file-version
  (~a base-version "." build))

(define build-number
  (~a base-version (if is-snapshot? "-snapshot-" "-release-") padded-build postfix))

(define package-version
  (if is-snapshot?
      build-number
      base-version))

(define (get-replacement line)
  (cond
    [(equal? line (version-line "AssemblyVersion" "0.0.0.0"))
     (version-line "AssemblyVersion" assembly-version)]
    [(equal? line (version-line "AssemblyFileVersion" "0.0.0.0"))
     (version-line "AssemblyFileVersion" assembly-file-version)]
    [(equal? line (version-line "AssemblyInformationalVersion" "0.0.0.0"))
     (version-line "AssemblyInformationalVersion" build-number)]
    [else line]))

(define (patch-versions-in-file filename)
  (let ((input (open-input-file filename))
        (output (open-output-file temp-filename)))
    (for ([l (in-lines input)])
      (displayln (get-replacement (string-normalize-spaces l)) output)))
  (delete-file filename)
  (rename-file-or-directory temp-filename filename))

(for-each patch-versions-in-file assembly-info-files)

(displayln
 (~a "##teamcity[buildNumber '" build-number "']"))

(displayln
 (~a "##teamcity[setParameter name='env.packageVersion' value='" package-version "']"))
