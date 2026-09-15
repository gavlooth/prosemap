# route-edge / expanded-duplicate / case-similar test.
# Run: bend bend/prosemap/mech_test3.bend
import Base
import ./types.bend as T
import ./contracts.bend as C
import ./mechanical.bend as M

def mkev(+id: String, +text: String) -> T.Evidence:
  C.Evidence.mk("ev-" ++ id, "hash", "doc.html", 0, U32.from_nat(String.length(text)), text, T.Anchor{"s1", None{}}, T.EvProse{}, text)

def blk(+id: String, kind: T.BlockKind, authored: Maybe<&2, String>, links: List<&2, T.Link>, tex: List<&2, T.Tex>, +text: String) -> T.Block:
  T.Block{id, kind, "p", "s1", authored, None{}, [], text, True{}, [mkev(id, text)], links, tex}

def titles(fs: List<&2, T.Finding>) -> String:
  match fs:
    case Nil{}:
      ""
    case Con{f, t}:
      match f:
        case T.Finding{recordId, rule, dimension, origin, kind, title, message, evidence, evidenceFingerprint, severity}:
          "  - " ++ title ++ ": " ++ message ++ "\n" ++ titles(t)

def main() -> IO(Unit):
  # b0 defines id "target"; b1 links forward to it -> route-edge (forward)
  b0 = blk("b0", T.BkProse{}, Some{"target"}, [], [], "the destination")
  lk = {T.Link{"#target", Some{"target"}, None{}, "ev-lk"} : T.Link}
  b1 = blk("b1", T.BkProse{}, None{}, [lk], [], "see target below")
  # b2 & b3: identical normalized prose (>=12 words) -> expanded-duplicate
  +dup = {"this sentence has twelve words in it to trip the duplicate rule now" : String}
  b2 = blk("b2", T.BkProse{}, None{}, [], [], dup)
  b3 = blk("b3", T.BkProse{}, None{}, [], [], dup)
  # b4: two recognized tex "Sigma" and "sigma" -> case-similar
  tx1 = {T.Tex{"Sigma", False{}, True{}, "ev-t1"} : T.Tex}
  tx2 = {T.Tex{"sigma", False{}, True{}, "ev-t2"} : T.Tex}
  b4 = blk("b4", T.BkMath{}, None{}, [], [tx1, tx2], "notation block")
  blocks = {[b0, b1, b2, b3, b4] : List<&2, T.Block>}
  do IO<Unit>:
    IO.print("new rules:")
    IO.print(titles(M.Mech.analyze(4, blocks)))
