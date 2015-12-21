(defmodule my-sort
  ;; API
  (export (sort 1))
  ;; Property tests
  (export (prop_ordered 0)
          ;; prop_same_length deliberately excluded
          (prop_same_length_conditional_check 0)
          (prop_same_length_distinct 0)
          (prop_equiv_usort 0))
  ;; EUnit tests
  (export (properties_test_ 0) (sort_test_ 0))
  ;; Import Prop{Er,L} helper functions
  (import (from proper_types (integer 0))
          (from propl        (any-list 0) (list-of 1))))

;;;===================================================================
;;; Includes
;;;===================================================================

(include-lib "proper/include/proper.hrl")

(include-lib "propl/include/propl-macros.lfe")

(include-lib "ltest/include/ltest-macros.lfe")

(include-lib "clj/include/compose.lfe")


;;;===================================================================
;;; API
;;;===================================================================

;; -spec sort([T]) -> [T].
(defun sort
  (['()] '())
  ([`(,p . ,xs)]
   (++ (sort (lc ((<- x xs) (< x p)) x))
       `(,p)
       (sort (lc ((<- x xs) (< p x)) x)))))


;;;===================================================================
;;; Property Tests
;;;===================================================================

(defprop ordered
  (FORALL xs (list-of (integer)) (ordered (sort xs))))

;; N.B. This property is known not to hold, so it's neither exported,
;;      nor included in the EUnit tests.
(defprop same-length ()
  (FORALL xs (any-list) (=:= (length xs) (length (sort xs)))))

(defprop same-length-conditional-check
  (FORALL xs (list-of (integer))
          (IMPLIES (distinct? xs) (=:= (length xs) (length (sort xs))))))

(defprop same-length-distinct
  (FORALL xs (list-distinct (integer))
          (=:= (length xs) (length (sort xs)))))

(defun list-distinct (type)
  (prop-let xs (list-of type) (distinct xs)))

(defprop equiv-usort
  (FORALL xs (list-of (integer)) (=:= (sort xs) (lists:usort xs))))

(deftestgen properties
  (let ((opts  '[#(to_file user)])
        (tests `(#("Each element in a sorted list is less than or equal to its successor."
                   ,(prop_ordered))
                 #("Every list of integers, if its elements are distinct, has the same length as itself sorted."
                   ,(prop_same_length_conditional_check))
                 #("Every list of distinct integers has the same length as itself sorted."
                   ,(prop_same_length_distinct))
                 #("my-sort:sort/1 is equivalent to lists:usort/1."
                   ,(prop_equiv_usort)))))
    (lc ((<- `#(,title ,prop) tests))
      `#(,title ,(_assert (proper:quickcheck prop '[#(to_file user)]))))))


;;;===================================================================
;;; Unit Tests
;;;===================================================================

(deftestgen sort `[,(test_zero) ,(test_two) ,(test_four)])

(defun test_zero () (expect #("the empty list" []) #("The empty list" [])))

(defun test_two ()
  (lc ((<- `#(,x ,y) '[#(17 42) #(42 17)]))
    (expect '[17 42] `(,x ,y))))

(defun test_four () (expect '[1 2 3 4] '[3 1 4 2]))


;;;===================================================================
;;; Internal Functions
;;;===================================================================

(defmacro unless
  (`[,test . ,body] `(if ,test 'false (progn ,@body))))

(defun distinct
  (['()] '())
  ([xs]  (-distinct xs (sets:new))))

(defun -distinct
  (['() _seen] '())
  ([`(,x . ,xs) seen]
   (if (sets:is_element x seen)
     (-distinct xs seen)
     `(,x . ,(-distinct xs (sets:add_element x seen))))))

;; Shout out to Clojure!
(defun distinct?
  (['()]      'true)
  ([`(,_)]    'true)
  ([`(,x ,y)] (/= x y))
  ([`(,x ,y . ,more)]
   (if (/= x y)
     (-distinct? (sets:from_list `(,x ,y)) more)
     'false)))

(defun -distinct?
  ([_seen '()]  'true)
  ([seen `(,x . ,xs)]
   (unless (sets:is_element x seen)
     (-distinct? (sets:add_element x seen) xs))))

(defun expect
  "Given an `expected` result and a list `to-sort`, return an annotated test.

`expected` and `to-sort` may also be wrapped in tuples, preceded by titles.
If no titles are given, generate them with [[when-sorted/2]]."
  ([`#(,expected-title ,expected) `#(,to-sort-title ,to-sort)]
   `#(,(when-sorted to-sort-title expected-title)
      ,(_assertEqual expected (sort to-sort))))
  ([expected to-sort]
   (expect `#(,expected ,expected) `#(,to-sort ,to-sort))))

(defun ordered
  (['()]           'true)
  ([`(,_)]         'true)
  ([`(,a ,b . ,t)] (andalso (=< a b) (ordered `(,b . ,t)))))

(defun when-sorted (x y)
  "Given terms `x` and `y`, return a test title."
  (->> (-> (lambda (x) (if (clj-p:string? x) x (lfe_io_pretty:term x)))
           (lists:map `(,x ,y)))
       (io_lib:format "~s, when sorted, is equal to ~s.")
       (lists:flatten)))
