# Runtime smoke tests for the pure core. Run: bend prosemap/test.bend
import Base
import ./types.bend as T
import ./contracts.bend as C
import ./cohesion.bend as Co

def show_bool(b: Bool) -> String:
  match b:
    case True{}:
      "PASS"
    case False{}:
      "FAIL"

def show_cmp(c: Co.Cmp3) -> String:
  match c:
    case Co.Cmp3{inter, jaccard, dice}:
      "inter=[" ++ String.join(inter, ", ") ++ "] jaccard=" ++ Co.Metric.show(jaccard) ++ " dice=" ++ Co.Metric.show(dice)

def main() -> IO(Unit):
  # source: 0123456789 ; slice [3,7) must be "3456"
  +src = {"0123456789" : String}
  ev = C.Evidence.mk("e1", "hash", "doc.html", 3, 7, "3456", T.Anchor{"sec-1", None{}}, T.EvProse{}, src)
  ev2 = C.Evidence.mk("e2", "hash", "doc.html", 3, 7, "3456", T.Anchor{"sec-1", None{}}, T.EvProse{}, src)
  do IO<Unit>:
    # slice extracts the right bytes
    IO.print("slice[3,7)  = " ++ C.Str.slice(src, 3, 7))
    # integrity holds when excerpt derives from the source and hash matches
    IO.print("integrity   = " ++ show_bool(C.Evidence.integrity(src, ev, "hash")))
    # integrity fails on a wrong expected hash
    IO.print("bad-hash    = " ++ show_bool(C.Evidence.integrity(src, ev2, "nope")))
    # cohesion: "The quick brown fox jumps" vs "The brown fox sleeps"
    # tokens L={quick,brown,fox,jumps} R={brown,fox,sleeps}; inter={brown,fox}
    # jaccard=2/5, dice=2*2/(4+3)=4/7
    IO.print("cohesion    = " ++ show_cmp(Co.Cohesion.compare(
      Co.Cohesion.tokenize("The quick brown fox jumps"),
      Co.Cohesion.tokenize("The brown fox sleeps"))))
