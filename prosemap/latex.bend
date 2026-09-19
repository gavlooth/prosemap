# LaTeX/math parsability check. prosemap extracts math snippets (Tex records);
# this stage runs each through an external parser (KaTeX) via the Exec shim and
# flags the ones that do not parse. Correctness here means PARSABLE — a real
# engine accepts it. The IO loop lives in main.bend; this module is the pure
# collection + finding construction.
import Base
import ./types.bend as T
import ./mechanical.bend as M
import ./sha256.bend as S

# a math snippet paired with the evidence to cite if it fails to parse
type LxItem is Data:
  LxItem{raw: String, ev: List<&2, T.Evidence>}

def LxItem.raw(i: LxItem) -> String:
  match i:
    case LxItem{raw, ev}:
      raw

def Lx.rule() -> T.RuleRef:
  T.RuleRef{"formula.unparsable", "1"}

# every Tex snippet in a block, tagged with the block's evidence
def Lx.block_items(texs: List<&2, T.Tex>, +ev: List<&2, T.Evidence>) -> List<&2, LxItem>:
  match texs:
    case Nil{}:
      Nil{}
    case Con{+tx, t}:
      LxItem{M.Tex.raw(tx), ev} <> Lx.block_items(t, ev)

def Lx.items(blocks: List<&2, T.Block>) -> List<&2, LxItem>:
  match blocks:
    case Nil{}:
      Nil{}
    case Con{+b, t}:
      List.append(&2, LxItem, Lx.block_items(M.Blk.tex(b), M.Blk.evidence(b)), Lx.items(t))

# finding for one unparsable snippet. The fingerprint folds in the snippet raw
# so distinct snippets in the same block get distinct record ids.
def Lx.finding_of(i: LxItem) -> T.Finding:
  match i:
    case LxItem{+raw, ev}:
      +fp = S.Sha256.hex("formula.unparsable@1#" ++ raw)
      T.Finding{
        "formula.unparsable:" ++ String.take(fp, 20n),
        Lx.rule(), T.Formula{}, T.Mechanical{}, T.Candidate{},
        "Unparsable LaTeX",
        "The math snippet \"" ++ raw ++ "\" is not accepted by the LaTeX parser.",
        ev, fp, None{},
      }

# fold one Exec result into the accumulator: non-zero exit (Fail) = unparsable.
def Lx.acc_step(rr: Result<&1, &1, U32 & String, String>, i: LxItem, acc: List<&2, T.Finding>) -> List<&2, T.Finding>:
  match rr:
    case Fail{e}:
      Lx.finding_of(i) <> acc
    case Done{ok}:
      acc
