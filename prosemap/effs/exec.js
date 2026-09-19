// Exec
// ====
// Run a subprocess via `sh -c cmd`, feed `stdin`, capture stdout. Synchronous
// (event loop blocks for the child, like other simple effects). Fallible:
// io_done(stdout text) on a clean exit, io_fail(code) on spawn error/timeout/
// non-zero exit. Generic host capability reused for the LLM CLI, KaTeX, pandoc.

function exec_run(cmd, stdin, timeout_ms, max_bytes) {
  try {
    const c = Buffer.from(io_bytes(cmd)).toString("utf8");
    const input = Buffer.from(io_bytes(stdin));
    const cap = Math.max(Number(max_bytes), 1);
    const r = require("child_process").spawnSync("/bin/sh", ["-c", c], {
      input: input,
      timeout: Number(timeout_ms),
      maxBuffer: cap,
    });
    // spawn failure or timeout -> error result
    if (r.error || r.status === null) {
      return io_fail(r.status === null ? 110 : 1);
    }
    // non-zero exit -> error result (exit code as the errno-ish field)
    if (r.status !== 0) {
      return io_fail(r.status);
    }
    const out = r.stdout || Buffer.alloc(0);
    const u = new Uint8Array(out.buffer, out.byteOffset, out.length);
    return io_done(io_text(u, u.length));
  } catch (e) {
    return io_fail(1);
  }
}
