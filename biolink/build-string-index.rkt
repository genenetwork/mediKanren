#lang racket/base
(require
  "repr.rkt"
  "string-search.rkt"
  racket/stream
  racket/vector)

(define argv (current-command-line-arguments))
(define argv-expected '#(DATA_DIR GRAPH_DIR))

(when (not (= (vector-length argv-expected) (vector-length argv)))
  (error "command line argument mismatch:" argv-expected argv))

(define data-dir (vector-ref argv 0))
(define graph-dir (vector-ref argv 1))
(define (graph-path fname)
  (expand-user-path (build-path data-dir graph-dir fname)))
(define (assert-file-absent! fnout)
  (when (file-exists? (graph-path fnout))
    (error "file already exists:"
           (path->string (simplify-path (graph-path fnout))))))

(define (fname-offset fname) (string-append fname ".offset"))
(define fnin-concepts             "concepts.scm")
(define fnout-concept-name-corpus "concept-name-corpus.scm")
(define fnout-concept-name-index  "concept-name-index.bytes")
(assert-file-absent! fnout-concept-name-corpus)
(assert-file-absent! fnout-concept-name-index)

(printf "loading concepts...\n")
(define concept*
  (time (call-with-input-file
          (graph-path fnin-concepts)
          (lambda (in-concepts)
            (list->vector
              (stream->list
                (stream-map cdr (port->stream-offset&values in-concepts))))))))
(printf "loaded ~a concepts\n" (vector-length concept*))
(printf "building name search corpus...\n")
(define corpus
  (time (vector-map (lambda (c) (let ((name (concept-name c)))
                                  (if name (string/searchable name) "")))
                    concept*)))
(printf "building name search index...\n")
(define index (time (corpus->index corpus)))
(printf "indexed ~a suffixes\n" (vector-length index))
(printf "writing name search corpus...\n")
(call-with-output-file
  (graph-path fnout-concept-name-corpus)
  (lambda (out) (time (for ((s (in-vector corpus))) (write-scm out s)))))
(printf "writing name search index...\n")
(call-with-output-file
  (graph-path fnout-concept-name-index)
  (lambda (out) (time (write-suffix-keys out index))))
