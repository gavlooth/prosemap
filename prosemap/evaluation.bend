# Deterministic evaluation — comparison plus replay-verified CI gate.
#
# Evaluation always verifies the two stored findings artifacts against their
# independently selected Markdown sources before it reports a pass. It supports
# either conventional run directories (input.md + findings.jsonl) or explicit
# findings/source paths; see Eval.flow below.
import Base
import ./types.bend as T
import ./comparison.bend as Cmp
import ./gate.bend as G
import ./json_read.bend as Jr

type EvalRes is Data:
  EvalRes{
    verified: Bool,
    comparison: List<&2, T.CompRecord>,
    gate: G.GateRes,
  }

def Eval.gate_pass(g: G.GateRes) -> Bool:
  match g:
    case G.GateRes{passed, violations}:
      passed

def Eval.gate_outcome(passed: Bool) -> String:
  match passed:
    case True{}:
      "EVALUATE PASS"
    case False{}:
      "EVALUATE FAIL (gate violations)"

def Eval.outcome(verified: Bool, gate: G.GateRes) -> String:
  match verified:
    case False{}:
      "EVALUATE FAIL (replay verification failed)"
    case True{}:
      Eval.gate_outcome(Eval.gate_pass(gate))

def Eval.show(r: EvalRes) -> String:
  match r:
    case EvalRes{verified, comparison, gate}:
      Eval.outcome(verified, gate) ++ " (" ++
      Nat.show(List.length(&2, T.CompRecord, comparison)) ++ " comparison record(s))"

# Pure evaluation of trusted findings remains available to callers that already
# hold findings in memory. CLI evaluation below uses replay instead.
def Eval.run(+base: List<&2, T.Finding>, +candidate: List<&2, T.Finding>, +allow: List<&2, T.RuleRef>) -> EvalRes:
  EvalRes{True{}, Cmp.Cmp.compare(base, candidate), G.Gate.run(base, candidate, allow)}

# Parse the stored artifacts for the comparison and let Gate.replay_run both
# parse them for the gate and prove their canonical, source-derived encoding.
def Eval.replay(+baseSource: String, +baseStored: String, +candidateSource: String, +candidateStored: String, +allow: List<&2, T.RuleRef>) -> EvalRes:
  +replay = G.Gate.replay_run(baseSource, baseStored, candidateSource, candidateStored, allow)
  EvalRes{
    G.ReplayRes.verified(replay),
    Cmp.Cmp.compare(Jr.Jr.parse(baseStored), Jr.Jr.parse(candidateStored)),
    G.ReplayRes.gate(replay),
  }

# --- IO --------------------------------------------------------------------
def Eval.env_m(r: Result<&1, &1, U32 & String, String>) -> Maybe<&2, String>:
  match r:
    case Done{v}:
      Some{v}
    case Fail{e}:
      None{}

def Eval.read_finish(rd: File & Result<&1, &1, U32 & String, String>) -> IO(String):
  (f2, res) = rd
  do IO<String>:
    File.close(f2)
    IO.pass(String, res)

def Eval.read_all(f: File) -> IO(String):
  do IO<String>:
    rd : File & Result<&1, &1, U32 & String, String> <- File.read(f, 5000000)
    Eval.read_finish(rd)

def Eval.io_paths(+baseFindings: String, +candidateFindings: String, +baseSource: String, +candidateSource: String) -> IO(Unit):
  do IO<Unit>:
    bf : File <- IO.try(File, File.open(baseFindings, "r"))
    bc : String <- Eval.read_all(bf)
    cf : File <- IO.try(File, File.open(candidateFindings, "r"))
    cc : String <- Eval.read_all(cf)
    bsf : File <- IO.try(File, File.open(baseSource, "r"))
    bs : String <- Eval.read_all(bsf)
    csf : File <- IO.try(File, File.open(candidateSource, "r"))
    cs : String <- Eval.read_all(csf)
    IO.print(Eval.show(Eval.replay(bs, bc, cs, cc, G.Gate.eligible_rules())))

def Eval.explicit_paths(baseFindings: Maybe<&2, String>, candidateFindings: Maybe<&2, String>, baseSource: Maybe<&2, String>, candidateSource: Maybe<&2, String>) -> IO(Unit):
  match baseFindings:
    case None{}:
      IO.print("EVALUATE FAIL (base findings/source paths required)")
    case Some{+bf}:
      match candidateFindings:
        case None{}:
          IO.print("EVALUATE FAIL (candidate findings/source paths required)")
        case Some{+cf}:
          match baseSource:
            case None{}:
              IO.print("EVALUATE FAIL (base findings/source paths required)")
            case Some{+bs}:
              match candidateSource:
                case None{}:
                  IO.print("EVALUATE FAIL (candidate findings/source paths required)")
                case Some{+cs}:
                  Eval.io_paths(bf, cf, bs, cs)

def Eval.explicit_flow() -> IO(Unit):
  do IO<Unit>:
    br : Result<&1, &1, U32 & String, String> <- IO.get_env("PROSEMAP_BASE")
    cr : Result<&1, &1, U32 & String, String> <- IO.get_env("PROSEMAP_CANDIDATE")
    bsr : Result<&1, &1, U32 & String, String> <- IO.get_env("PROSEMAP_BASE_SOURCE")
    csr : Result<&1, &1, U32 & String, String> <- IO.get_env("PROSEMAP_CANDIDATE_SOURCE")
    Eval.explicit_paths(Eval.env_m(br), Eval.env_m(cr), Eval.env_m(bsr), Eval.env_m(csr))

def Eval.run_dirs(+baseRun: String, +candidateRun: String) -> IO(Unit):
  Eval.io_paths(
    baseRun ++ "/findings.jsonl",
    candidateRun ++ "/findings.jsonl",
    baseRun ++ "/input.md",
    candidateRun ++ "/input.md")

def Eval.run_mode(baseRun: Maybe<&2, String>, candidateRun: Maybe<&2, String>) -> IO(Unit):
  match baseRun:
    case None{}:
      match candidateRun:
        case None{}:
          Eval.explicit_flow()
        case Some{candidate}:
          IO.print("EVALUATE FAIL (both run directories are required)")
    case Some{base}:
      match candidateRun:
        case None{}:
          IO.print("EVALUATE FAIL (both run directories are required)")
        case Some{candidate}:
          Eval.run_dirs(base, candidate)

def Eval.flow() -> IO(Unit):
  do IO<Unit>:
    br : Result<&1, &1, U32 & String, String> <- IO.get_env("PROSEMAP_BASE_RUN")
    cr : Result<&1, &1, U32 & String, String> <- IO.get_env("PROSEMAP_CANDIDATE_RUN")
    Eval.run_mode(Eval.env_m(br), Eval.env_m(cr))
