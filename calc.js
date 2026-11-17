/* Calculator maths for Destroyer of Worlds. Pure functions, no eval. Exposes window.Calc.evaluate("2+3×4") -> {ok, value, text}. */
(function (root) {
  'use strict';
  var PREC = { '+': 1, '-': 1, '*': 2, '/': 2 };
  function tokens(s) {
    s = String(s).replace(/×/g, '*').replace(/÷/g, '/').replace(/−/g, '-').replace(/\s+/g, '');
    var out = [], re = /(\d*\.?\d+|\d+\.)(%?)|([+\-*\/])/g, m, prev = null, pos = 0;
    while ((m = re.exec(s)) !== null) {
      if (m.index !== pos) return null;                                  // junk between tokens
      pos = re.lastIndex;
      if (m[3]) {
        var op = m[3];
        if (op === '-' && (prev === null || prev === 'op')) { var n = /^\d*\.?\d+|^\d+\./.exec(s.slice(pos)); if (!n) return null; re.lastIndex = pos + n[0].length; var pct = s.charAt(re.lastIndex) === '%'; if (pct) re.lastIndex++; pos = re.lastIndex; out.push({ n: -parseFloat(n[0]) / (pct ? 100 : 1) }); prev = 'num'; continue; }
        if (prev !== 'num') return null;
        out.push({ op: op }); prev = 'op';
      } else { out.push({ n: parseFloat(m[1]) / (m[2] ? 100 : 1) }); prev = 'num'; }
    }
    if (pos !== s.length || prev !== 'num') return null;
    return out;
  }
  function format(v) {
    var r = +v.toPrecision(12), a = Math.abs(r);
    if (a !== 0 && (a >= 1e15 || a < 1e-9)) return r.toExponential(6).replace(/\.?0+e/, 'e').replace('e+', 'e');
    return String(r).replace('-', '−');
  }
  function evaluate(s) {
    var t = tokens(s); if (!t) return { ok: false, value: NaN, text: 'Error' };
    var nums = [], ops = [];
    function apply() { var b = nums.pop(), a = nums.pop(), o = ops.pop(); nums.push(o === '+' ? a + b : o === '-' ? a - b : o === '*' ? a * b : a / b); }
    for (var i = 0; i < t.length; i++) {
      if (t[i].op) { while (ops.length && PREC[ops[ops.length - 1]] >= PREC[t[i].op]) apply(); ops.push(t[i].op); }
      else nums.push(t[i].n);
    }
    while (ops.length) apply();
    var v = nums[0];
    if (!isFinite(v)) return { ok: false, value: v, text: 'Error' };
    return { ok: true, value: v, text: format(v) };
  }
  root.Calc = { evaluate: evaluate, tokens: tokens };
})(typeof window !== 'undefined' ? window : globalThis);
