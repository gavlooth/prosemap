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
import ./exec.bend as E
import ./latex.bend as Lx
import ./reviews.bend as Rv
import ./route.bend as Rt
import ./evaluation.bend as Eval
import ./artifacts.bend as Art
import ./corpus.bend as Cp
import ./review_eval.bend as Re
import ./label_eval.bend as Le

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
def Cli.env_m(r: Result<&1, &1, U32 & String, String>) -> Maybe<&2, String>:
  match r:
    case Done{v}:
      Some{v}
    case Fail{e}:
      None{}

def Cli.env_or(r: Result<&1, &1, U32 & String, String>, d: String) -> String:
  match r:
    case Done{v}:
      v
    case Fail{e}:
      d

# the whole pure pipeline: markdown source -> report + findings.jsonl + manifest
def Cli.out_of(+sha: String, +fs: List<&2, T.Finding>) -> CliOut:
  CliOut{Rep.Rep.render(fs), J.Json.findings_jsonl(fs), J.Json.manifest(sha, List.length(&2, T.Finding, fs))}

# analyze with LLM candidates merged in and reviews applied. `cands` are the
# already-verified contextual/model candidate findings (empty when no LLM).
def Cli.out_merged(+content: String, +cands: List<&2, T.Finding>, +reviews: String, +route: String) -> CliOut:
  +sha = S.Sha256.hex(content)
  +mech = M.Mech.analyze(4, Rt.Route.apply(Rt.Route.parse(route), Md.Md.parse(content, sha)))
  Cli.out_of(sha, Rv.Rv.apply(Rv.Rv.rejected_ids(Rv.Rv.parse(reviews)), List.append(&2, T.Finding, mech, cands)))

# run the configured LLM CLI over a prompt, yielding "" on unset/failure.
def Cli.llm_resp(rr: Result<&1, &1, U32 & String, String>) -> IO(String):
  match rr:
    case Fail{e}:
      IO.pure(String, "")
    case Done{s}:
      IO.pure(String, s)

def Cli.llm_run(+cmd: String, prompt: String) -> IO(String):
  do IO<String>:
    rr : Result<&1, &1, U32 & String, String> <- E.Exec.run(cmd, prompt, 60000, 1048576)
    Cli.llm_resp(rr)

# Preparing a contextual request parses and hashes the whole document. Skip that
# work entirely when no model command was requested; the mechanical pass below
# remains the sole full-document pass for ordinary analysis.
def Cli.maybe_cands(m: Maybe<&2, String>, +reader: String, +content: String) -> IO(List<&2, T.Finding>):
  match m:
    case None{}:
      IO.pure(List<&2, T.Finding>, Nil{})
    case Some{cmd}:
      do IO<List<&2, T.Finding>>:
        +req : Ctx.CtxReq = Ctx.Ctx.prepare(reader, content)
        resp : String <- Cli.llm_run(cmd, Ctx.CtxReq.prompt(req))
        IO.pure(List<&2, T.Finding>, Ctx.Ctx.candidates(Ctx.CtxReq.evs(req), resp))

# tuple projection must live in a plain def body (destructuring-let is not a
# valid do-block statement).
def Cli.read_finish(rd: File & Result<&1, &1, U32 & String, String>) -> IO(String):
  (f2, res) = rd
  do IO<String>:
    File.close(f2)
    IO.pass(String, res)

def Cli.read_sized(sr: File & Result<&1, &1, U32 & String, U32>) -> IO(String):
  (f, res) = sr
  match res:
    case Fail{(code, message)}:
      do IO<String>:
        File.close(f)
        IO.die(String, code, message)
    case Done{size}:
      do IO<String>:
        rd : File & Result<&1, &1, U32 & String, String> <- File.read(f, size)
        Cli.read_finish(rd)

def Cli.read_all(f: File) -> IO(String):
  do IO<String>:
    sr : File & Result<&1, &1, U32 & String, U32> <- File.size(f)
    Cli.read_sized(sr)


# read an optional file, yielding "" when unset or unopenable (never dies)
def Cli.read_opt_after(fr: Result<&1, &1, U32 & String, File>) -> IO(String):
  match fr:
    case Fail{e}:
      IO.pure(String, "")
    case Done{f}:
      Cli.read_all(f)

def Cli.read_opt_open(+path: String) -> IO(String):
  do IO<String>:
    fr : Result<&1, &1, U32 & String, File> <- File.open(path, "r")
    Cli.read_opt_after(fr)

def Cli.read_opt(m: Maybe<&2, String>) -> IO(String):
  match m:
    case None{}:
      IO.pure(String, "")
    case Some{path}:
      Cli.read_opt_open(path)

def Cli.analyze_flow() -> IO(Unit):
  do IO<Unit>:
    inr : Result<&1, &1, U32 & String, String> <- IO.get_env("PROSEMAP_INPUT")
    f : File <- IO.try(File, File.open(Cli.env_or(inr, "input.md"), "r"))
    content : String <- Cli.read_all(f)
    +cc : String = content
    rvr : Result<&1, &1, U32 & String, String> <- IO.get_env("PROSEMAP_REVIEWS")
    reviews : String <- Cli.read_opt(Cli.env_m(rvr))
    rdr : Result<&1, &1, U32 & String, String> <- IO.get_env("PROSEMAP_READER")
    reader : String <- Cli.read_opt(Cli.env_m(rdr))
    lcr : Result<&1, &1, U32 & String, String> <- IO.get_env("PROSEMAP_LLM_CMD")
    cands : List<&2, T.Finding> <- Cli.maybe_cands(Cli.env_m(lcr), reader, cc)
    rtr : Result<&1, &1, U32 & String, String> <- IO.get_env("PROSEMAP_ROUTE")
    route : String <- Cli.read_opt(Cli.env_m(rtr))
    +out : CliOut = Cli.out_merged(cc, cands, reviews, route)
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

# context command: run the configured LLM CLI (PROSEMAP_LLM_CMD) over the
# document, keep only candidates citing a source-verified evidence id.
# Unset command -> stage is skipped. Any CLI failure/timeout -> abstain.

def Cli.context_emit(rr: Result<&1, &1, U32 & String, String>, evs: List<&2, T.Evidence>) -> IO(Unit):
  match rr:
    case Fail{e}:
      IO.print("contextual: provider CLI failed or timed out; stage abstains")
    case Done{resp}:
      IO.print("contextual candidate findings (evidence-verified):\n" ++ J.Json.findings_jsonl(Ctx.Ctx.candidates(evs, resp)))

def Cli.context_run(+cmd: String) -> IO(Unit):
  do IO<Unit>:
    inr : Result<&1, &1, U32 & String, String> <- IO.get_env("PROSEMAP_INPUT")
    f : File <- IO.try(File, File.open(Cli.env_or(inr, "input.md"), "r"))
    content : String <- Cli.read_all(f)
    rdr : Result<&1, &1, U32 & String, String> <- IO.get_env("PROSEMAP_READER")
    reader : String <- Cli.read_opt(Cli.env_m(rdr))
    +req : Ctx.CtxReq = Ctx.Ctx.prepare(reader, content)
    tr : Result<&1, &1, U32 & String, String> <- IO.get_env("PROSEMAP_LLM_TIMEOUT")
    br : Result<&1, &1, U32 & String, String> <- IO.get_env("PROSEMAP_LLM_MAX_BYTES")
    rr : Result<&1, &1, U32 & String, String> <- E.Exec.run(cmd, Ctx.CtxReq.prompt(req), Cli.u32_or(tr, 60000), Cli.u32_or(br, 1048576))
    Cli.context_emit(rr, Ctx.CtxReq.evs(req))

def Cli.context_go(m: Maybe<&2, String>) -> IO(Unit):
  match m:
    case None{}:
      IO.print("contextual: PROSEMAP_LLM_CMD unset; stage skipped")
    case Some{cmd}:
      Cli.context_run(cmd)

def Cli.context_flow() -> IO(Unit):
  do IO<Unit>:
    lr : Result<&1, &1, U32 & String, String> <- IO.get_env("PROSEMAP_LLM_CMD")
    Cli.context_go(Cli.env_m(lr))

# latex command: run each extracted math snippet through PROSEMAP_KATEX_CMD and
# report the unparsable ones. Unset -> skipped. A failed probe (parser broken /
# missing) -> abstain, so we never flag every snippet on a setup error.
def Cli.latex_loop(items: List<&2, Lx.LxItem>, +cmd: String, acc: List<&2, T.Finding>) -> IO(List<&2, T.Finding>):
  match items:
    case Nil{}:
      IO.pure(List<&2, T.Finding>, List.reverse(&2, T.Finding, acc))
    case Con{+it, rest}:
      do IO<List<&2, T.Finding>>:
        rr : Result<&1, &1, U32 & String, String> <- E.Exec.run(cmd, Lx.LxItem.raw(it), 30000, 65536)
        step : List<&2, T.Finding> = Lx.Lx.acc_step(rr, it, acc)
        Cli.latex_loop(rest, cmd, step)

def Cli.latex_emit(+fs: List<&2, T.Finding>) -> IO(Unit):
  IO.print("unparsable LaTeX (" ++ Nat.show(List.length(&2, T.Finding, fs)) ++ "):\n" ++ J.Json.findings_jsonl(fs))

def Cli.latex_run(+cmd: String) -> IO(Unit):
  do IO<Unit>:
    inr : Result<&1, &1, U32 & String, String> <- IO.get_env("PROSEMAP_INPUT")
    f : File <- IO.try(File, File.open(Cli.env_or(inr, "input.md"), "r"))
    content : String <- Cli.read_all(f)
    +cc : String = content
    +sha : String = S.Sha256.hex(cc)
    found : List<&2, T.Finding> <- Cli.latex_loop(Lx.Lx.items(Md.Md.parse(cc, sha)), cmd, Nil{})
    Cli.latex_emit(found)

def Cli.latex_after_probe(pr: Result<&1, &1, U32 & String, String>, cmd: String) -> IO(Unit):
  match pr:
    case Fail{e}:
      IO.print("latex: KaTeX probe failed; stage abstains")
    case Done{ok}:
      Cli.latex_run(cmd)

def Cli.latex_probe(+cmd: String) -> IO(Unit):
  do IO<Unit>:
    pr : Result<&1, &1, U32 & String, String> <- E.Exec.run(cmd, "x+1", 30000, 65536)
    Cli.latex_after_probe(pr, cmd)

def Cli.latex_go(m: Maybe<&2, String>) -> IO(Unit):
  match m:
    case None{}:
      IO.print("latex: PROSEMAP_KATEX_CMD unset; stage skipped")
    case Some{cmd}:
      Cli.latex_probe(cmd)

def Cli.latex_flow() -> IO(Unit):
  do IO<Unit>:
    kr : Result<&1, &1, U32 & String, String> <- IO.get_env("PROSEMAP_KATEX_CMD")
    Cli.latex_go(Cli.env_m(kr))

def Cli.dispatch4(isEvaluate: Bool, isLatex: Bool) -> IO(Unit):
  match isEvaluate:
    case True{}:
      Eval.Eval.flow()
    case False{}:
      match isLatex:
        case True{}:
          Cli.latex_flow()
        case False{}:
          Cli.analyze_flow()

def Cli.dispatch3(isContext: Bool, isEvaluate: Bool, isLatex: Bool) -> IO(Unit):
  match isContext:
    case True{}:
      Cli.context_flow()
    case False{}:
      Cli.dispatch4(isEvaluate, isLatex)

def Cli.dispatch2(isGate: Bool, isContext: Bool, isEvaluate: Bool, isLatex: Bool) -> IO(Unit):
  match isGate:
    case True{}:
      Cli.gate_flow()
    case False{}:
      Cli.dispatch3(isContext, isEvaluate, isLatex)

def Cli.dispatch1(isCorpus: Bool, isGate: Bool, isContext: Bool, isEvaluate: Bool, isLatex: Bool) -> IO(Unit):
  match isCorpus:
    case True{}:
      Cp.Cp.flow()
    case False{}:
      Cli.dispatch2(isGate, isContext, isEvaluate, isLatex)

def Cli.dispatch0(isReviewEvaluate: Bool, isCorpus: Bool, isGate: Bool, isContext: Bool, isEvaluate: Bool, isLatex: Bool) -> IO(Unit):
  match isReviewEvaluate:
    case True{}:
      Re.Re.flow()
    case False{}:
      Cli.dispatch1(isCorpus, isGate, isContext, isEvaluate, isLatex)

def Cli.dispatch_labels(isLabels: Bool, isReviewEvaluate: Bool, isCorpus: Bool, isGate: Bool, isContext: Bool, isEvaluate: Bool, isLatex: Bool) -> IO(Unit):
  match isLabels:
    case True{}:
      Le.Le.flow()
    case False{}:
      Cli.dispatch0(isReviewEvaluate, isCorpus, isGate, isContext, isEvaluate, isLatex)

def Cli.dispatch(+cmd: String) -> IO(Unit):
  Cli.dispatch_labels(String.eq(cmd, "label-evaluate"), String.eq(cmd, "review-evaluate"), String.eq(cmd, "corpus"), String.eq(cmd, "gate"), String.eq(cmd, "context"), String.eq(cmd, "evaluate"), String.eq(cmd, "latex"))
def main() -> IO(Unit):
  do IO<Unit>:
    cmdr : Result<&1, &1, U32 & String, String> <- IO.get_env("PROSEMAP_CMD")
    Cli.dispatch(Cli.env_or(cmdr, "analyze"))
