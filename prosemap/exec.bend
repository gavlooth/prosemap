# Generic subprocess effect (FFI) — runs `sh -c cmd`, pipes `stdin`, returns
# stdout. Fallible: Fail carries a numeric code (non-zero exit / 110 timeout /
# 1 spawn error). Shared shim for the LLM CLI, KaTeX, and pandoc.
#
# Host impl: effs/exec.js (JS backend). A native `effs/exec.c` twin can be added
# for `-o` native builds; the JS backend (default `bend run`) needs only the .js.
import Base

def Exec.run(cmd: String, stdin: String, timeout_ms: U32, max_bytes: U32) -> IO(Result<&1, &1, U32 & String, String>):
  import "./effs/exec.js"
