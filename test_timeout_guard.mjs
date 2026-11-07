// Main-thread timeout / busy-guard behaviour.
//
// GDScript cannot preempt a running function, so a command that outruns its budget keeps going
// on Pixelorama's main thread after the HTTP caller has given up. These tests pin the three
// things the bridge can do about that: tell the truth, refuse to stack more work behind it, and
// recover by itself.
const URL = "http://127.0.0.1:7373/command";

async function send(tool, params = {}, timeoutMs) {
  const body = { tool, params };
  if (timeoutMs !== undefined) body.timeout_ms = timeoutMs;
  const res = await fetch(URL, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(body),
  });
  return { status: res.status, body: await res.json() };
}

const results = [];
function check(name, ok, detail = "") {
  results.push({ name, ok, detail });
  console.log(`  ${ok ? "✅ PASS" : "❌ FAIL"}: ${name}${detail ? ` — ${detail}` : ""}`);
}

// Occupies the main thread for `ms` without yielding.
const hogCode = (ms) =>
  `\nvar t0 = Time.get_ticks_msec()\nwhile Time.get_ticks_msec() - t0 < ${ms}:\n    pass\n`;

async function main() {
  console.log("\n=== main-thread timeout / busy guard ===\n");
  await send("create_canvas", { width: 32, height: 32, name: "TimeoutGuard" });

  // Hog the main thread for 10s but only wait 2s for it.
  const hog = send("eval_gdscript", { code: hogCode(10000) }, 2000);
  await new Promise((r) => setTimeout(r, 4000)); // past the wait, still running

  const busy = await send("get_canvas_info");
  check("a command arriving while the main thread is busy is refused, not queued",
    busy.status === 503 && busy.body.busy === true, `HTTP ${busy.status}`);
  check("the refusal names the command that is still running",
    busy.body.running_tool === "eval_gdscript", `running_tool=${busy.body.running_tool}`);
  check("the refusal reports how long it has been running",
    typeof busy.body.running_for_ms === "number" && busy.body.running_for_ms > 3000,
    `${busy.body.running_for_ms} ms`);

  const timedOut = await hog;
  check("the caller is told the work was abandoned, not cancelled",
    timedOut.status === 504 && timedOut.body.timed_out === true, `HTTP ${timedOut.status}`);
  check("the timeout message says the command is still running",
    /STILL RUNNING/.test(timedOut.body.error || ""), "");

  // Wait for the hog to finish, then confirm the bridge frees itself without a restart.
  let recovered = null;
  for (let i = 0; i < 100; i++) {
    const r = await send("get_canvas_info");
    if (r.status !== 503) { recovered = r; break; }
    await new Promise((r2) => setTimeout(r2, 200));
  }
  check("the bridge recovers on its own once the main thread is free",
    recovered !== null && recovered.status === 200, `HTTP ${recovered && recovered.status}`);

  // A budget the caller sets is honoured by the loops that own long work.
  const bones = [{ name: "T0", pivot: { x: 16, y: 2 } }];
  for (let i = 1; i < 400; i++) {
    bones.push({ name: `T${i}`, parent: `T${i - 1}`, pivot: { x: 16, y: 2 } });
  }
  await send("create_canvas", { width: 32, height: 32, name: "DeadlineAbort" });
  const t0 = Date.now();
  await send("setup_skeletor_rig", { bones }, 1500);
  let freeAt = null;
  for (let i = 0; i < 600; i++) {
    const r = await send("get_canvas_info");
    if (r.status !== 503) { freeAt = Date.now() - t0; break; }
    await new Promise((r2) => setTimeout(r2, 100));
  }
  // Unbounded, this rig pins the main thread for ~110s; the deadline must cut that drastically.
  check("a long rig build stops itself near the caller's budget",
    freeAt !== null && freeAt < 30000, `main thread blocked ${(freeAt / 1000).toFixed(2)}s`);

  const failed = results.filter((r) => !r.ok).length;
  console.log(`\n=== RESULTS: ${results.length - failed}/${results.length} passed ===`);
  if (failed > 0) { console.log("❌ SOME TESTS FAILED!"); process.exit(1); }
  console.log("🎉 ALL TIMEOUT GUARD TESTS PASSED!");
}

main().catch((e) => { console.error(e); process.exit(1); });
