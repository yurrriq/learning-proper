(defmodule my-sort
  (export (sort 1))
  ;; Lazy hack to ensure properties are accesible.
  (export all)
  (import
    (from propl
      (any-list 0)
      (list-of 1))))

(include-lib "proper/include/proper.hrl")

(include-lib "propl/include/propl-macros.lfe")

(include-lib "eunit/include/eunit.hrl")

(include-lib "ltest/include/ltest-macros.lfe")

;; -spec sort([T]) -> [T].
(defun sort
  (['()]         '())
  ([`(,p . ,xs)] (++ (sort (lc ((<- x xs) (< x p)) x))
                     `(,p)
                     (sort (lc ((<- x xs) (< p x)) x)))))

(defprop ordered
  (FORALL xs (list-of (proper_types:integer)) (ordered (sort xs))))

(defun ordered
  (['()]           'true)
  ([`(,_)]         'true)
  ([`(,a ,b . ,t)] (andalso (=< a b) (ordered `(,b . ,t)))))

(defprop same-length ()
  (FORALL xs (any-list) (=:= (length xs) (length (sort xs)))))

(defprop same-length-conditional-check
  (FORALL xs (list-of (proper_types:integer))
          (IMPLIES (distinct? xs) (=:= (length xs) (length (sort xs))))))

(defmacro unless
  (`[,test . ,body] `(if ,test 'false (progn ,@body))))

;; Shout out to Clojure!
(defun distinct?
  (['()]      'true)
  ([`(,_)]    'true)
  ([`(,x ,y)] (/= x y))
  ([`(,x ,y . ,more)]
   (if (/= x y)
     (fletrec ((loop
                ([_seen '()]  'true)
                ([seen `(,x . ,xs)]
                 (unless (sets:is_element x seen)
                   (loop (sets:add_element x seen) xs)))))
       (loop (sets:from_list `(,x ,y)) more))
     'false)))

(defun list-distinct (type)
  (prop-let xs (list-of type) (distinct xs)))

(defprop same-length-distinct
  (FORALL xs (list-distinct (proper_types:integer))
          (=:= (length xs) (length (sort xs)))))

;; (defun distinct
;;   (['()]  'true)
;;   ([coll] (distinct coll (sets:new))))

;; (defun distinct
;;   (['() _seen] '())
;;   ([`(,x . ,xs) seen]
;;    (if (sets:is_element x seen)
;;      (distinct xs seen)
;;      (cons x (distinct xs (sets:add_element x seen))))))

(defun distinct
  (['()] '())
  ([`(,h . ,t)]
   (if (lists:member h t)
     (distinct t)
     (cons h (distinct t)))))

(defprop equiv-usort
  (FORALL xs (list-of (proper_types:integer)) (=:= (sort xs) (lists:usort xs))))

(deftestgen sort ()
  `[,(test_zero) ,(test_two) ,(test_four)])

(defun test_zero ()
  `#("the empty list"
     ,(_assertEqual '[] (sort '[]))))

(defun test_two ()
  (lc ((<- `#(,x ,y) '[#(17 42) #(42 17)]))
    `#(,(lists:flatten (io_lib:format "~p" `([,x ,y])))
       ,(_assertEqual '[17 42] (sort `(,x ,y))))))

(defun test_four ()
  `#("[3,1,4,2]"
     ,(_assertEqual '[1 2 3 4] (sort '[3 1 4 2]))))

;; See http://proper.softlab.ntua.gr/User_Guide.html#using_proper_in_conjunction_with_eunit
(deftestgen properties
  (let ((opts  '[#(to_file user)])
        (tests `(#("ordered"
                   ,(my-sort:prop_ordered))
                 #("same length conditional"
                   ,(my-sort:prop_same_length_conditional_check))
                 #("same length distinct"
                   ,(my-sort:prop_same_length_distinct)))))
    (lc ((<- `#(,title ,prop) tests))
      `#(,title ,(_assert (proper:quickcheck prop))))))
