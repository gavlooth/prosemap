# Generic subprocess effect (FFI) — runs `sh -c cmd`, pipes `stdin`, returns
# stdout. Fallible: Fail carries a numeric code (non-zero exit / 110 timeout /
# 1 spawn error). Shared shim for the LLM CLI, KaTeX, and pandoc.
#
# Host implementations: effs/exec.c for native builds and effs/exec.js for the
# default JavaScript backend.
import Base

def Exec.run(cmd: String, stdin: String, timeout_ms: U32, max_bytes: U32) -> IO(Result<&1, &1, U32 & String, String>):
  import "./effs/exec.c"
  import "./effs/exec.js"
