"""Destroyer of Worlds tests: the maths, the buttons, the keyboard, the walking character, and no requests to other sites.
Run: python tests/test_calc.py  (needs playwright + chromium)"""
import http.server, socketserver, threading, pathlib, sys, functools
from playwright.sync_api import sync_playwright

ROOT = pathlib.Path(__file__).resolve().parent.parent
H = functools.partial(http.server.SimpleHTTPRequestHandler, directory=str(ROOT)); H.log_message = lambda *a, **k: None
srv = socketserver.TCPServer(("127.0.0.1", 0), H); base = f"http://127.0.0.1:{srv.server_address[1]}"
threading.Thread(target=srv.serve_forever, daemon=True).start()
fails = []
def check(name, got, want):
    ok = got == want
    print(("ok   " if ok else "FAIL ") + name + ("" if ok else f"\n     got  {got!r}\n     want {want!r}"))
    if not ok: fails.append(name)

with sync_playwright() as p:
    b = p.chromium.launch(); pg = b.new_page(viewport={"width": 390, "height": 844}); reqs = []
    pg.on("request", lambda r: reqs.append(r.url)); errs = []; pg.on("pageerror", lambda e: errs.append(str(e)))
    pg.goto(base + "/index.html"); pg.wait_for_selector("#pad")
    pg.wait_for_function("Calc.engine === 'wasm'", timeout=5000)
    check("the page runs the WebAssembly engine", pg.evaluate("Calc.engine"), "wasm")
    # the hand-written WebAssembly and the plain JavaScript reference must agree on everything, including nonsense
    import random
    random.seed(7); toks = list("0123456789") + [".", "+", "−", "×", "÷", "%"]
    cases = ["2+3×4", "10÷4", "0.1+0.2", "−5+2", "50%", "200+10%", "5÷0", "1÷3", "2−−3", "7×−2", "3.", ".5+.5", "12345678901234567890×10", "0.0000000001", "1÷0×0", "−", "%", "5%%", "9×+2", "1e5", "2 3"]
    cases += ["".join(random.choice(toks) for _ in range(random.randint(1, 9))) for _ in range(1500)]
    bad = pg.evaluate("""cs => cs.filter(s => { const a = Calc.evaluate(s), b = Calc.evaluateJS(s); return a.ok !== b.ok || (a.ok && a.text !== b.text); })""", cases)
    check("wasm and JS agree on %d sums" % len(cases), bad[:5], [])
    ev = lambda s: pg.evaluate("s => { const r = Calc.evaluate(s); return [r.ok, r.text]; }", s)
    for s, want in [("2+3×4", [True, "14"]), ("10÷4", [True, "2.5"]), ("0.1+0.2", [True, "0.3"]), ("−5+2", [True, "−3"]), ("50%", [True, "0.5"]),
                    ("2−−3", [True, "5"]), ("1÷3", [True, "0.333333333333"]), ("5÷0", [False, "Error"]), ("7×", [False, "Error"]), ("", [False, "Error"])]:
        check(f"maths {s or '(empty)'}", ev(s), want)
    def tap(keys):
        for k in keys: pg.click(f'[data-k="{k}"]')
    res = lambda: pg.inner_text("#res")
    tap(["AC", "2", "+", "3", "×", "4", "="]); check("buttons 2+3×4", res(), "14")
    tap(["AC", "5", "÷", "0", "="]); check("divide by zero message", res(), "Cannot divide by zero")
    tap(["AC", "1", ".", "5", "+", "1", "."]); check("second dot ignored", pg.inner_text("#expr"), "1.5+1.")
    tap(["AC", "9", "×", "+", "2", "="]); check("operator replaced", res(), "11")
    tap(["AC", "8", "=", "+", "2", "="]); check("continue from result", res(), "10")
    tap(["AC", "4", "2", "BS", "7", "="]) if False else None
    tap(["AC", "4", "2", "BS", "7"]); check("backspace", pg.inner_text("#expr"), "47")
    # keyboard
    tap(["AC"]); pg.keyboard.type("12*3"); pg.keyboard.press("Enter"); check("keyboard 12*3", res(), "36")
    pg.keyboard.press("Escape"); check("Escape clears", res(), "0")
    # the destroyer walks
    pos = lambda: pg.evaluate("document.getElementById('hero').style.transform")
    tap(["AC", "7"]); a = pos(); tap(["3"]); c = pos()
    check("character moves between keys", a != c and "translate" in a, True)
    # planet breaks after four equals and the counter goes up
    tap(["AC"])
    for _ in range(4): tap(["1", "+", "1", "="]); pg.keyboard.press("Escape") if False else None
    pg.wait_for_function("window.__dow.state().worlds >= 1", timeout=4000)
    check("a world ends after four sums", pg.evaluate("window.__dow.state().worlds") >= 1, True)
    # layout and privacy
    check("no sideways scroll at 390 px", pg.evaluate("document.documentElement.scrollWidth - innerWidth") <= 0, True)
    small = pg.evaluate("[...document.querySelectorAll('button')].filter(b => b.getBoundingClientRect().height < 44).length")
    check("every button is at least 44 px tall", small, 0)
    check("no requests to other sites", [u for u in reqs if not u.startswith(base)], [])
    check("no page errors", errs, [])
    pg.screenshot(path="/tmp/audit/dow.png")
    b.close()
print("\n%d failed" % len(fails) if fails else "\nall passed"); sys.exit(1 if fails else 0)
