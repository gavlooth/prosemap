# Contextual evidence re-verification. Run: bend bend/prosemap/ctx_test.bend
import Base
import ./types.bend as T
import ./contracts.bend as C
import ./contextual.bend as Ctx

def sb(b: Bool) -> String:
  match b:
    case True{}:
      "true"
    case False{}:
      "false"

def good2() -> T.Evidence:
  C.Evidence.mk("g2", "hash", "d", 0, 4, "0123", T.Anchor{"root", None{}}, T.EvProse{}, "0123456789")

def main() -> IO(Unit):
  +src = {"0123456789" : String}
  # genuine: excerpt "3456" derived from src[3,7)
  good = C.Evidence.mk("g", "hash", "d", 3, 7, "3456", T.Anchor{"root", None{}}, T.EvProse{}, src)
  # tampered: same span but a forged excerpt (constructed directly, not via mk)
  bad = {T.Evidence{"b", "hash", "d", T.Span{3, 7}, "XXXX", "XXXX", T.Anchor{"root", None{}}, T.EvProse{}} : T.Evidence}
  evs = {[good, bad] : List<&2, T.Evidence>}
  do IO<Unit>:
    # verify drops the tampered one: 2 in -> 1 kept
    IO.print("kept = " ++ Nat.show(List.length(&2, T.Evidence, Ctx.Ctx.verify(src, "hash", evs))))
    # all_verified false because one candidate's evidence is forged
    IO.print("all_verified = " ++ sb(Ctx.Ctx.all_verified(src, "hash", {[good2()] : List<&2, T.Evidence>})))
