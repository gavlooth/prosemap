# prosemap — CLI entry point.
#
# Pipeline: read a Markdown file -> SHA-256 it -> parse to blocks -> mechanical
# analysis -> render a Markdown report -> write it out and print it.
#
# Invocation (Bend has no argv; paths come from the environment):
#   PROSEMAP_INPUT=doc.md PROSEMAP_OUTPUT=report.md bend prosemap/main.bend
# Defaults: input.md -> report.md
import Base
import ./types.bend as T
import ./sha256.bend as S
import ./markdown.bend as Md
import ./mechanical.bend as M
import ./report.bend as Rep
import ./json.bend as J
import ./json_read.bend as Jr
import ./gate.bend as G
import ./contextual.bend as Ctx
import ./evaluation.bend as Eval
import ./artifacts.bend as Art

# all rendered artifacts from one analysis pass
type CliOut is Data:
  CliOut{report: String, jsonl: String, manifest: String}

def CliOut.report(o: CliOut) -> String:
  match o:
    case CliOut{report, jsonl, manifest}:
      report

def CliOut.jsonl(o: CliOut) -> String:
  match o:
    case CliOut{report, jsonl, manifest}:
      jsonl

def CliOut.manifest(o: CliOut) -> String:
  match o:
    case CliOut{report, jsonl, manifest}:
      manifest

# env value or a default
def Cli.env_or(r: Result<&1, &1, U32 & String, String>, d: String) -> String:
  match r:
    case Done{v}:
      v
    case Fail{e}:
      d

# the whole pure pipeline: markdown source -> report + findings.jsonl + manifest
def Cli.run(+content: String) -> CliOut:
  +sha = S.Sha256.hex(content)
  +fs  = M.Mech.analyze(4, Md.Md.parse(content, sha))
  CliOut{Rep.Rep.render(fs), J.Json.findings_jsonl(fs), J.Json.manifest(sha, List.length(&2, T.Finding, fs))}

# tuple projection must live in a plain def body (destructuring-let is not a
# valid do-block statement).
def Cli.read_finish(rd: File & Result<&1, &1, U32 & String, String>) -> IO(String):
  (f2, res) = rd
  do IO<String>:
    File.close(f2)
    IO.pass(String, res)

def Cli.read_all(f: File) -> IO(String):
  do IO<String>:
    rd : File & Result<&1, &1, U32 & String, String> <- File.read(f, 5000000)
    Cli.read_finish(rd)


def Cli.analyze_flow() -> IO(Unit):
  do IO<Unit>:
    inr : Result<&1, &1, U32 & String, String> <- IO.get_env("PROSEMAP_INPUT")
    f : File <- IO.try(File, File.open(Cli.env_or(inr, "input.md"), "r"))
    content : String <- Cli.read_all(f)
    +out : CliOut = Cli.run(content)
    +report : String = CliOut.report(out)
    +jsonl : String = CliOut.jsonl(out)
    +manifest : String = CliOut.manifest(out)
    outr : Result<&1, &1, U32 & String, String> <- IO.get_env("PROSEMAP_OUTPUT")
    jr : Result<&1, &1, U32 & String, String> <- IO.get_env("PROSEMAP_JSONL")
    mr : Result<&1, &1, U32 & String, String> <- IO.get_env("PROSEMAP_MANIFEST")
    cr : Result<&1, &1, U32 & String, String> <- IO.get_env("PROSEMAP_COMPLETE")
    Art.Art.commit(
      Cli.env_or(outr, "report.md"),
      Cli.env_or(jr, "findings.jsonl"),
      Cli.env_or(mr, "manifest.json"),
      Cli.env_or(cr, "manifest.json.complete"),
      report,
      jsonl,
      manifest)
    IO.print(report)

# gate command: compare a stored base vs candidate findings.jsonl and apply the
# CI gate (allowlist = the gate-eligible rules).
def Cli.passed_str(p: Bool) -> String:
  match p:
    case True{}:
      "GATE PASS"
    case False{}:
      "GATE FAIL"

def Cli.gate_show(g: G.GateRes) -> String:
  match g:
    case G.GateRes{passed, violations}:
      Cli.passed_str(passed) ++ " (" ++ Nat.show(List.length(&2, T.Finding, violations)) ++ " violation(s))"

def Cli.gate_report(+bc: String, +cc: String) -> String:
  Cli.gate_show(G.Gate.run(Jr.Jr.parse(bc), Jr.Jr.parse(cc), G.Gate.eligible_rules()))

def Cli.gate_replay_show(r: G.ReplayRes) -> String:
  match r:
    case G.ReplayRes{verified, gate}:
      match verified:
        case True{}:
          Cli.gate_show(gate)
        case False{}:
          "GATE FAIL (replay verification failed)"

def Cli.gate_replay_report(+bc: String, +cc: String, +bs: String, +cs: String) -> String:
  Cli.gate_replay_show(G.Gate.replay_run(bs, bc, cs, cc, G.Gate.eligible_rules()))

# Replay is opt-in for backward-compatible gate invocations. Supplying either
# source path selects replay mode, which requires both sources; an incomplete
# pair is an explicit closed gate rather than a fallback to stored artifacts.
def Cli.gate_sources(baseSource: Result<&1, &1, U32 & String, String>, candidateSource: Result<&1, &1, U32 & String, String>, +bc: String, +cc: String) -> IO(Unit):
  match baseSource:
    case Done{bsPath}:
      match candidateSource:
        case Done{csPath}:
          do IO<Unit>:
            bsf : File <- IO.try(File, File.open(bsPath, "r"))
            bs : String <- Cli.read_all(bsf)
            csf : File <- IO.try(File, File.open(csPath, "r"))
            cs : String <- Cli.read_all(csf)
            IO.print(Cli.gate_replay_report(bc, cc, bs, cs))
        case Fail{e}:
          IO.print("GATE FAIL (both replay source paths are required)")
    case Fail{e}:
      match candidateSource:
        case Done{csPath}:
          IO.print("GATE FAIL (both replay source paths are required)")
        case Fail{e2}:
          IO.print(Cli.gate_report(bc, cc))

def Cli.gate_flow() -> IO(Unit):
  do IO<Unit>:
    br : Result<&1, &1, U32 & String, String> <- IO.get_env("PROSEMAP_BASE")
    bf : File <- IO.try(File, File.open(Cli.env_or(br, "base.jsonl"), "r"))
    bc : String <- Cli.read_all(bf)
    cr : Result<&1, &1, U32 & String, String> <- IO.get_env("PROSEMAP_CANDIDATE")
    cf : File <- IO.try(File, File.open(Cli.env_or(cr, "findings.jsonl"), "r"))
    cc : String <- Cli.read_all(cf)
    bsr : Result<&1, &1, U32 & String, String> <- IO.get_env("PROSEMAP_BASE_SOURCE")
    csr : Result<&1, &1, U32 & String, String> <- IO.get_env("PROSEMAP_CANDIDATE_SOURCE")
    Cli.gate_sources(bsr, csr, bc, cc)

# context command: POST the document to a loopback contextual provider over TCP
# (PROSEMAP_PROVIDER_PORT, default 8899) and print the response body.
def Cli.u32_of(m: Maybe<&2, U32>, d: U32) -> U32:
  match m:
    case Some{v}:
      v
    case None{}:
      d

def Cli.u32_or(r: Result<&1, &1, U32 & String, String>, d: U32) -> U32:
  match r:
    case Done{v}:
      Cli.u32_of(U32.read(v), d)
    case Fail{e}:
      d

def Cli.context_flow() -> IO(Unit):
  do IO<Unit>:
    inr : Result<&1, &1, U32 & String, String> <- IO.get_env("PROSEMAP_INPUT")
    f : File <- IO.try(File, File.open(Cli.env_or(inr, "input.md"), "r"))
    content : String <- Cli.read_all(f)
    pr : Result<&1, &1, U32 & String, String> <- IO.get_env("PROSEMAP_PROVIDER_PORT")
    resp : String <- Ctx.Ctx.fetch("127.0.0.1", Cli.u32_or(pr, 8899), Ctx.Ctx.request("/contextual", content))
    IO.print(Ctx.Ctx.http_body(resp))

def Cli.dispatch3(isContext: Bool, isEvaluate: Bool) -> IO(Unit):
  match isContext:
    case True{}:
      Cli.context_flow()
    case False{}:
      match isEvaluate:
        case True{}:
          Eval.Eval.flow()
        case False{}:
          Cli.analyze_flow()

def Cli.dispatch2(isGate: Bool, isContext: Bool, isEvaluate: Bool) -> IO(Unit):
  match isGate:
    case True{}:
      Cli.gate_flow()
    case False{}:
      Cli.dispatch3(isContext, isEvaluate)

def Cli.dispatch(+cmd: String) -> IO(Unit):
  Cli.dispatch2(String.eq(cmd, "gate"), String.eq(cmd, "context"), String.eq(cmd, "evaluate"))
def main() -> IO(Unit):
  do IO<Unit>:
    cmdr : Result<&1, &1, U32 & String, String> <- IO.get_env("PROSEMAP_CMD")
    Cli.dispatch(Cli.env_or(cmdr, "analyze"))
