#lang racket

(require racket/format)
(require racket/file)
(require racket/cmdline)

(define postfix (make-parameter ""))
(define base-version (make-parameter ""))
(define build (make-parameter 0))
(define is-snapshot? (make-parameter #t))

(define temp-filename "temp.tmp")

(command-line
 #:program "patch-version"
 #:once-each
 [("-s" "--stable") "" (is-snapshot? #f)]
 [("-p" "--postfix") p "" (postfix (~a "-" p))]
 [("-v" "--base-version") v "" (base-version v)]
 [("-b" "--build") b "" (build (string->number b))])

(define (is-assembly-info? filename)
  (regexp-match #rx".*AssemblyInfo.cs$" filename))

(define assembly-info-files
  (find-files is-assembly-info? #f))

(define (version-line param value)
  (~a "[assembly: " param "(\"" value "\")]"))

(define padded-build
  (~r (build) #:min-width 4 #:pad-string "0"))

(define assembly-version
  (~a (base-version) ".0"))

(define assembly-file-version
  (~a (base-version) "." (build)))

(define build-number
  (~a (base-version) (if (is-snapshot?) "-snapshot-" "-stable-") padded-build (postfix)))

(define package-version
  (if (is-snapshot?)
      (~a (base-version) "-snapshot-"  padded-build)
      (base-version)))

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
 (~a build-number))
