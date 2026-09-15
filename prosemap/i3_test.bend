# I3 regression: strong/b term blocks are counted by introduction-density
# (the TS had this dead — <strong> never became a block). Run: bend bend/prosemap/i3_test.bend
import Base
import ./types.bend as T
import ./contracts.bend as C
import ./mechanical.bend as M

def mk(+id: String, kind: T.BlockKind, tag: String, +text: String) -> T.Block:
  ev = C.Evidence.mk("ev-" ++ id, "h", "d", 0, U32.from_nat(String.length(text)), text, T.Anchor{"s1", None{}}, T.EvProse{}, text)
  T.Block{id, kind, tag, "s1", None{}, None{}, [], text, True{}, [ev], [], []}

def titles(fs: List<&2, T.Finding>) -> String:
  match fs:
    case Nil{}:
      ""
    case Con{f, t}:
      match f:
        case T.Finding{recordId, rule, dimension, origin, kind, title, message, evidence, evidenceFingerprint, severity}:
          "  - " ++ title ++ "\n" ++ titles(t)

def main() -> IO(Unit):
  s1 = mk("s1", T.BkOther{}, "strong", "Functor")
  s2 = mk("s2", T.BkOther{}, "b", "Monad")
  d1 = mk("d1", T.BkDefinition{}, "dfn", "Applicative")
  p1 = mk("p1", T.BkProse{}, "p", "Prose about these three highlighted terms goes on for a bit here now.")
  do IO<Unit>:
    # 3 term blocks (strong + b + dfn) in prose -> introduction-density candidate
    IO.print(titles(M.Mech.analyze_cfg(4, 100n, 3n, 3n, {[s1, s2, d1, p1] : List<&2, T.Block>})))
