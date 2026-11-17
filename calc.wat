;; Destroyer of Worlds: the calculator's maths, written by hand in WebAssembly text.
;; JavaScript writes the sum into memory as ASCII ("2+3*4", "-5+2", "50%"), calls eval(length), then reads status().
;;   status 0 = fine, 1 = the sum is not valid, 2 = the result is not a number (divide by zero, overflow).
;; Memory map: 0..999 the sum, 1024.. number stack (8 bytes each, up to 100), 2048.. operator stack (1 byte each, up to 100).
;; Operators: + - * /   Percent after a number divides it by 100. A minus at the start or after an operator makes the next number negative.
;; Order of operations comes from the shunting-yard method: * and / bind tighter than + and -.
(module
  (memory (export "mem") 1)
  (global $status (mut i32) (i32.const 0))
  (global $nn (mut i32) (i32.const 0))     ;; numbers on the stack
  (global $no (mut i32) (i32.const 0))     ;; operators on the stack
  (global $pos (mut i32) (i32.const 0))    ;; where the last number ended

  (func (export "status") (result i32) (global.get $status))

  (func $isdigit (param $c i32) (result i32)
    (i32.lt_u (i32.sub (local.get $c) (i32.const 48)) (i32.const 10)))

  (func $prec (param $op i32) (result i32)
    (select (i32.const 2) (i32.const 1)
      (i32.or (i32.eq (local.get $op) (i32.const 42)) (i32.eq (local.get $op) (i32.const 47)))))

  ;; take the top operator and the top two numbers, put the answer back
  (func $apply
    (local $a f64) (local $b f64) (local $op i32) (local $r f64)
    (local.set $b (f64.load (i32.add (i32.const 1024) (i32.shl (i32.sub (global.get $nn) (i32.const 1)) (i32.const 3)))))
    (local.set $a (f64.load (i32.add (i32.const 1024) (i32.shl (i32.sub (global.get $nn) (i32.const 2)) (i32.const 3)))))
    (local.set $op (i32.load8_u (i32.add (i32.const 2048) (i32.sub (global.get $no) (i32.const 1)))))
    (global.set $no (i32.sub (global.get $no) (i32.const 1)))
    (global.set $nn (i32.sub (global.get $nn) (i32.const 1)))
    (if (i32.eq (local.get $op) (i32.const 43)) (then (local.set $r (f64.add (local.get $a) (local.get $b)))))
    (if (i32.eq (local.get $op) (i32.const 45)) (then (local.set $r (f64.sub (local.get $a) (local.get $b)))))
    (if (i32.eq (local.get $op) (i32.const 42)) (then (local.set $r (f64.mul (local.get $a) (local.get $b)))))
    (if (i32.eq (local.get $op) (i32.const 47)) (then (local.set $r (f64.div (local.get $a) (local.get $b)))))
    (f64.store (i32.add (i32.const 1024) (i32.shl (i32.sub (global.get $nn) (i32.const 1)) (i32.const 3))) (local.get $r)))

  (func $push_num (param $v f64)
    (if (i32.ge_u (global.get $nn) (i32.const 100)) (then (global.set $status (i32.const 1)) (return)))
    (f64.store (i32.add (i32.const 1024) (i32.shl (global.get $nn) (i32.const 3))) (local.get $v))
    (global.set $nn (i32.add (global.get $nn) (i32.const 1))))

  (func $push_op (param $op i32)
    (if (i32.ge_u (global.get $no) (i32.const 100)) (then (global.set $status (i32.const 1)) (return)))
    ;; finish everything on the stack that binds at least as tightly
    (block $stop
      (loop $again
        (br_if $stop (i32.eqz (global.get $no)))
        (br_if $stop (i32.lt_u
          (call $prec (i32.load8_u (i32.add (i32.const 2048) (i32.sub (global.get $no) (i32.const 1)))))
          (call $prec (local.get $op))))
        (call $apply)
        (br $again)))
    (i32.store8 (i32.add (i32.const 2048) (global.get $no)) (local.get $op))
    (global.set $no (i32.add (global.get $no) (i32.const 1))))

  ;; read one number starting at $i: digits, an optional dot with at least one digit after it, an optional percent
  (func $num (param $i i32) (param $len i32) (result f64)
    (local $val f64) (local $frac f64) (local $scale f64) (local $nd i32) (local $fd i32) (local $c i32)
    (local.set $scale (f64.const 1))
    (block $intdone
      (loop $int
        (br_if $intdone (i32.ge_u (local.get $i) (local.get $len)))
        (local.set $c (i32.load8_u (local.get $i)))
        (br_if $intdone (i32.eqz (call $isdigit (local.get $c))))
        (local.set $val (f64.add (f64.mul (local.get $val) (f64.const 10)) (f64.convert_i32_u (i32.sub (local.get $c) (i32.const 48)))))
        (local.set $nd (i32.add (local.get $nd) (i32.const 1)))
        (local.set $i (i32.add (local.get $i) (i32.const 1)))
        (br $int)))
    (if (i32.and (i32.lt_u (local.get $i) (local.get $len)) (i32.eq (i32.load8_u (local.get $i)) (i32.const 46)))
      (then
        (local.set $i (i32.add (local.get $i) (i32.const 1)))
        (block $fracdone
          (loop $f
            (br_if $fracdone (i32.ge_u (local.get $i) (local.get $len)))
            (local.set $c (i32.load8_u (local.get $i)))
            (br_if $fracdone (i32.eqz (call $isdigit (local.get $c))))
            (local.set $frac (f64.add (f64.mul (local.get $frac) (f64.const 10)) (f64.convert_i32_u (i32.sub (local.get $c) (i32.const 48)))))
            (local.set $scale (f64.mul (local.get $scale) (f64.const 10)))
            (local.set $fd (i32.add (local.get $fd) (i32.const 1)))
            (local.set $i (i32.add (local.get $i) (i32.const 1)))
            (br $f)))
        (if (i32.eqz (local.get $fd)) (then (global.set $status (i32.const 1)) (return (f64.const 0))))
        (local.set $val (f64.add (local.get $val) (f64.div (local.get $frac) (local.get $scale)))))
      (else
        (if (i32.eqz (local.get $nd)) (then (global.set $status (i32.const 1)) (return (f64.const 0))))))
    (if (i32.and (i32.lt_u (local.get $i) (local.get $len)) (i32.eq (i32.load8_u (local.get $i)) (i32.const 37)))
      (then (local.set $val (f64.div (local.get $val) (f64.const 100))) (local.set $i (i32.add (local.get $i) (i32.const 1)))))
    (global.set $pos (local.get $i))
    (local.get $val))

  (func (export "eval") (param $len i32) (result f64)
    (local $i i32) (local $c i32) (local $prev i32) (local $v f64) (local $r f64)
    (global.set $status (i32.const 0)) (global.set $nn (i32.const 0)) (global.set $no (i32.const 0))
    (if (i32.gt_u (local.get $len) (i32.const 1000)) (then (global.set $status (i32.const 1)) (return (f64.const 0))))
    (block $fail
      (block $done
        (loop $next
          (br_if $done (i32.ge_u (local.get $i) (local.get $len)))
          (local.set $c (i32.load8_u (local.get $i)))
          ;; a number
          (if (i32.or (call $isdigit (local.get $c)) (i32.eq (local.get $c) (i32.const 46)))
            (then
              (br_if $fail (local.get $prev))
              (local.set $v (call $num (local.get $i) (local.get $len)))
              (br_if $fail (global.get $status))
              (call $push_num (local.get $v)) (br_if $fail (global.get $status))
              (local.set $i (global.get $pos)) (local.set $prev (i32.const 1))
              (br $next)))
          ;; a minus where a number is expected: the next number is negative
          (if (i32.and (i32.eq (local.get $c) (i32.const 45)) (i32.eqz (local.get $prev)))
            (then
              (local.set $i (i32.add (local.get $i) (i32.const 1)))
              (local.set $v (call $num (local.get $i) (local.get $len)))
              (br_if $fail (global.get $status))
              (call $push_num (f64.neg (local.get $v))) (br_if $fail (global.get $status))
              (local.set $i (global.get $pos)) (local.set $prev (i32.const 1))
              (br $next)))
          ;; + - * /
          (if (i32.or (i32.or (i32.eq (local.get $c) (i32.const 43)) (i32.eq (local.get $c) (i32.const 45)))
                      (i32.or (i32.eq (local.get $c) (i32.const 42)) (i32.eq (local.get $c) (i32.const 47))))
            (then
              (br_if $fail (i32.eqz (local.get $prev)))
              (call $push_op (local.get $c)) (br_if $fail (global.get $status))
              (local.set $i (i32.add (local.get $i) (i32.const 1))) (local.set $prev (i32.const 0))
              (br $next)))
          (br $fail)))
      ;; end of input: it must finish on a number
      (br_if $fail (i32.eqz (local.get $prev)))
      (block $out (loop $rest (br_if $out (i32.eqz (global.get $no))) (call $apply) (br $rest)))
      (local.set $r (f64.load (i32.const 1024)))
      ;; infinity and NaN are not answers
      (if (f64.ne (f64.sub (local.get $r) (local.get $r)) (f64.const 0))
        (then (global.set $status (i32.const 2)) (return (f64.const 0))))
      (return (local.get $r)))
    (global.set $status (i32.const 1))
    (f64.const 0))
)
