- [PropL Introduction to Property-Based Testing](#propl-introduction-to-property-based-testing)
  - [`(defun sort ...)`](#`(defun-sort-...)`)
  - [Examples](#examples)
  - [Unit Tests](#unit-tests)
    - [`(deftestgen sort ...)`](#`(deftestgen-sort-...)`)
  - [Property Tests](#property-tests)
    - [`(defprop ordered ...)`](#`(defprop-ordered-...)`)
    - [`(defprop same-length ...)`](#`(defprop-same-length-...)`)
    - [`(defprop same-length-conditional-check ...)`](#`(defprop-same-length-conditional-check-...)`)
    - [`(defprop same-length-distinct ...)`](#`(defprop-same-length-distinct-...)`)
    - [`(defprop equiv-usort ...)`](#`(defprop-equiv-usort-...)`)
    - [`(deftestgen properties ... )`](#`(deftestgen-properties-...-)`)
  - [The Finished `my-sort` Module](#the-finished-`my-sort`-module)
    - [`noweb` Magic](#`noweb`-magic)
  - [Running Properties Tests](#running-properties-tests)
  - [Running the EUnit Tests](#running-the-eunit-tests)


# PropL Introduction to Property-Based Testing<a id="orgheadline16"></a>

An [LFE](https://github.com/rvirding/lfe) (and [PropL](https://github.com/quasiquoting/propl)) translation of Kostis Sagonas's [PropEr introduction to
Property-Based Testing](http://proper.softlab.ntua.gr/Tutorials/PropEr_introduction_to_Property-Based_Testing.html).

## `(defun sort ...)`<a id="orgheadline1"></a>

Define the [quicksort](http://algs4.cs.princeton.edu/23quicksort/)​-inspired `sort/1`.

```lfe
;; -spec sort([T]) -> [T].
(defun sort
  (['()] '())
  ([`(,p . ,xs)]
   (++ (sort (lc ((<- x xs) (< x p)) x))
       `(,p)
       (sort (lc ((<- x xs) (< p x)) x)))))
```

## Examples<a id="orgheadline2"></a>

Try a few examples.

```lfe
(sort '[17 42])
```

    (17 42)

```lfe
(sort '[42 17])
```

    (17 42)

```lfe
(sort '[3 1 4 2])
```

    (1 2 3 4)

## Unit Tests<a id="orgheadline4"></a>

In order to include the EUnit headers and use `deftest` and `deftestgen`,
include the [ltest](https://github.com/lfex/ltest) macros.

```lfe
(include-lib "ltest/include/ltest-macros.lfe")
```

For `->` and `->>`, include [clj](https://github.com/lfex/clj)'s composition macros.

```lfe
(include-lib "clj/include/compose.lfe")
```

To make writing tests more succinct, define a helper function, `expect/2` that
takes an `expected` result and a list `to-sort` (or those same values, wrapped
in tuples, preceded by a title) and returns an [annotated test](http://www.erlang.org/doc/apps/eunit/chapter.html#Titles).

```lfe
(defun expect
  "Given an `expected` result and a list `to-sort`, return an annotated test.

`expected` and `to-sort` may also be wrapped in tuples, preceded by titles.
If no titles are given, generate them with [[when-sorted/2]]."
  ([`#(,expected-title ,expected) `#(,to-sort-title ,to-sort)]
   `#(,(when-sorted to-sort-title expected-title)
      ,(_assertEqual expected (sort to-sort))))
  ([expected to-sort]
   (expect `#(,expected ,expected) `#(,to-sort ,to-sort))))
```

`when-sorted/2`, when given terms `x` and `y` returns a string like `​"x when
sorted is equal to y."​` where `x` and `y` are [pretty printed](https://github.com/rvirding/lfe/blob/develop/src/lfe_io_pretty.erl) (unless strings).

```lfe
(defun when-sorted (x y)
  "Given terms `x` and `y`, return a test title."
  (->> (-> (lambda (x) (if (clj-p:string? x) x (lfe_io_pretty:term x)))
           (lists:map `(,x ,y)))
       (io_lib:format "~s, when sorted, is equal to ~s.")
       (lists:flatten)))
```

### `(deftestgen sort ...)`<a id="orgheadline3"></a>

```lfe
(deftestgen sort `[,(test_zero) ,(test_two) ,(test_four)])

(defun test_zero () (expect #("the empty list" []) #("The empty list" [])))

(defun test_two ()
  (lc ((<- `#(,x ,y) '[#(17 42) #(42 17)]))
    (expect '[17 42] `(,x ,y))))

(defun test_four () (expect '[1 2 3 4] '[3 1 4 2]))
```

N.B. EUnit gets very upset with kebab case, so use snake for test generators

## Property Tests<a id="orgheadline12"></a>

Now, for some property-based testing!

```lfe
(include-lib "proper/include/proper.hrl")
```

N.B. This needs to come **before** including `eunit.hrl` since [they both define
some macros with the same names](http://proper.softlab.ntua.gr/User_Guide.html#using_proper_in_conjunction_with_eunit).

For convenience, include the [propl macros](https://github.com/quasiquoting/propl/blob/master/include/propl-macros.lfe).

```lfe
(include-lib "propl/include/propl-macros.lfe")
```

To ensure the following examples work, `slurp` the [tangled module](#orgheadline5).

```lfe
(slurp "src/my-sort.lfe")
```

### `(defprop ordered ...)`<a id="orgheadline6"></a>

Define the `ordered` property.

```lfe
(defprop ordered
  (FORALL xs (list-of (integer)) (ordered (sort xs))))
```

```lfe
(defun ordered
  (['()]           'true)
  ([`(,_)]         'true)
  ([`(,a ,b . ,t)] (andalso (=< a b) (ordered `(,b . ,t)))))
```

Check `prop_ordered`.

```lfe
(proper:quickcheck (prop_ordered))
```

    ....................................................................................................
    OK: Passed 100 test(s).
    true

There also exists `proper:quickcheck/2` which accepts an option or list of
options, namely a number of tests (`numtests`) to run when testing a property.

```lfe
(proper:quickcheck (prop_ordered) 4711)
```

N.B. Evaluating the form above will take a while and print 4711 `.` before `OK`
or `Failed`.

### `(defprop same-length ...)`<a id="orgheadline7"></a>

Define the `same-length` property.

```lfe
(defprop same-length ()
  (FORALL xs (any-list) (=:= (length xs) (length (sort xs)))))
```

Check `prop_same_length` and watch it fail and shrink.

```lfe
(proper:quickcheck (prop_same_length))
```

    ............!
    Failed: After 13 test(s).
    [[],{-11,{}},[],<<254,196>>]
    
    Shrinking ..(2 time(s))
    [[],[]]
    false

Confirm the failures.

```lfe
(sort '[[] #(-11 #()) [] #b(254 196)])
```

    (#(-11 #()) () #B(254 196))

```lfe
(sort '[[] []])
```

    (())

### `(defprop same-length-conditional-check ...)`<a id="orgheadline8"></a>

Define the `same-length-conditional-check` property.

```lfe
(defprop same-length-conditional-check
  (FORALL xs (list-of (integer))
          (IMPLIES (distinct? xs) (=:= (length xs) (length (sort xs))))))
```

Define the `unless` macro, as seen in Common Lisp and Scheme.

```lfe
(defmacro unless
  (`[,test . ,body] `(if ,test 'false (progn ,@body))))
```

Define the `distinct?/1` predicate, which given a list, returns `​'true` iff
its elements are distinct.

```lfe
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
```

Check `prop_same_length_conditional_check`.

```lfe
(proper:quickcheck (prop_same_length_conditional_check))
```

    ............x.....x...x......x...x....x.x.xx..x.xxxx..xx.x..xx..xxx.xx.xxx.x...x.xx.xxxxx..x...xxxxx.xxxxx.xx.xxxx.x.x.x.xxx.x.xxxxx.x.x.xx.x...x.x.x..x.xx xxxx.xxx.xx.xx.xx.xx...xxx.xxx.xxxx..xx..x.x.xxxxx.xx.x..x.
    OK: Passed 100 test(s).
    true

### `(defprop same-length-distinct ...)`<a id="orgheadline9"></a>

Define the `same-length-distinct` property.

```lfe
(defprop same-length-distinct
  (FORALL xs (list-distinct (integer))
          (=:= (length xs) (length (sort xs)))))
```

Define the `list-distinct` generator.

```lfe
(defun list-distinct (type)
  (prop-let xs (list-of type) (distinct xs)))
```

Define `distinct/1`, which given a list `xs`, returns a list of the elements of
`xs` with duplicates removed.

```lfe
(defun distinct
  (['()] '())
  ([xs]  (-distinct xs (sets:new))))

(defun -distinct
  (['() _seen] '())
  ([`(,x . ,xs) seen]
   (if (sets:is_element x seen)
     (-distinct xs seen)
     `(,x . ,(-distinct xs (sets:add_element x seen))))))
```

Check `prop_same_length_distinct`.

```lfe
(proper:quickcheck (prop_same_length_distinct))
```

    ....................................................................................................
    OK: Passed 100 test(s).
    true

### `(defprop equiv-usort ...)`<a id="orgheadline10"></a>

Define the `equiv-usort` property, which checks that `sort/1` is equivalent to
`lists:usort/1`.

```lfe
(defprop equiv-usort
  (FORALL xs (list-of (integer)) (=:= (sort xs) (lists:usort xs))))
```

Check `prop_equiv_usort`.

```lfe
(proper:quickcheck (prop_equiv_usort))
```

    ....................................................................................................
    OK: Passed 100 test(s).
    true

### `(deftestgen properties ... )`<a id="orgheadline11"></a>

Define [EUnit](http://erlang.org/doc/apps/eunit/chapter.html) tests that check the previously defined properties, excluding
`prop_same_length`, which is known not to hold.

N.B. Since [EUnit captures standard output](http://erlang.org/doc/apps/eunit/chapter.html#Running_EUnit), we use `proper:quickcheck/2` with
`​'[#(to_file user)]` to [make PropEr properties visible when invoked from EUnit](http://proper.softlab.ntua.gr/User_Guide.html#using_proper_in_conjunction_with_eunit).

Define the `properties` test generator, which checks the desired properties.

```lfe
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
```

## The Finished `my-sort` Module<a id="orgheadline5"></a>

Define the `my-sort` module and save ([tangle](./ob-lfe.el)) it to [src/my-sort.lfe](./src/my-sort.lfe) by pressing
`C-c C-v t` or `C-c C-v C-t`.

Compile the finished module.

```sh
rebar3 compile
```

### `noweb` Magic<a id="orgheadline13"></a>

Open [README.org](README.md) in Emacs to look [behind the curtain](http://www.criticalcommons.org/Members/pcote/clips/the_wizard_of_oz-title1_2.mp4/view).

## Running Properties Tests<a id="orgheadline14"></a>

To check the properties defined in a particular module, use
`proper:module/{1,2}`.

```lfe
(proper:module 'my-sort)
```

    Testing 'my-sort':prop_ordered/0
    ....................................................................................................
    OK: Passed 100 test(s).
    
    Testing 'my-sort':prop_same_length_conditional_check/0
    .............x.......x....x...........x.x.x.x.x...x.x.x....xx.xx..xx.x.xx..xx.xx.....x.x.x..xxxx.xxxxxxxx..xx.xxx..x.x.xxxxxxxxx.xxxx.xx..x.xxxxxxxxxx..x.. xxx.xxxx.x.x.x.xxxxxx.x.xxxxxxxx.xxxxx.xx....x..x.xxxxx.xxx.
    OK: Passed 100 test(s).
    
    Testing 'my-sort':prop_same_length_distinct/0
    ....................................................................................................
    OK: Passed 100 test(s).
    
    Testing 'my-sort':prop_equiv_usort/0
    ....................................................................................................
    OK: Passed 100 test(s).
    
    ()

## Running the EUnit Tests<a id="orgheadline15"></a>

Run the EUnit tests in an LFE shell.

```lfe
(eunit:test 'my-sort '[verbose])
```

    ======================== EUnit ========================
    .module 'my-sort'
    .  .my-sort:68: properties_test_ (Each element in a sorted list is less than or equal to its successor.)................................................... .................................................
    OK: Passed 100 test(s).
    .[0.004 s] ok
    .  .my-sort:68: properties_test_ (Every list of integers, if its elements are distinct, has the same length as itself sorted.)............x..............x. .x..x..xx.x.x.x....x......x......x.xxxxx.xx.....x.x.xx..x....xxxx..xxxxx.x....x.xxxxxxxx.x..x...xxx.x.xxxx.x.x.xx...xx.x.xxxxx.xxxxxxxx.xx.xx..xxx...xx..
    OK: Passed 100 test(s).
    .[0.012 s] ok
    .  .my-sort:68: properties_test_ (Every list of distinct integers has the same length as itself sorted.)................................................... .................................................
    OK: Passed 100 test(s).
    .[0.006 s] ok
    .  .my-sort:68: properties_test_ (my-sort:sort/1 is equivalent to lists:usort/1.).......................................................................... ..........................
    OK: Passed 100 test(s).
    [0.006 s] ok
      my-sort:131: expect (The empty list, when sorted, is equal to the empty list.)...ok
      my-sort:131: expect ((17 42), when sorted, is equal to (17 42).)...ok
      my-sort:131: expect ((42 17), when sorted, is equal to (17 42).)...ok
      my-sort:131: expect ((3 1 4 2), when sorted, is equal to (1 2 3 4).)...ok
      [done in 0.052 s]
    =======================================================
      All 8 tests passed.
    ok

Run the EUnit tests with [rebar3](http://www.rebar3.org).

```sh
rebar3 eunit -v
```
