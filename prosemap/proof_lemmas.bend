# Reusable equality lemmas: reflexivity of Bend's comparison chain, up to the
# structural string equality Str.eq2. These are ordinary defs whose return TYPE
# is an equality proposition (in Bend a proof is just a def of that type).
# Used by PROOF.bend to discharge the full evidence-integrity law.
import Base
import ./contracts.bend as C

# Word.cmp(n, w, w) == EQ  (induction on the bit-word; the EQ branch of
# Word.cmp.fin reduces to Bool.cmp(b, b), settled by casing the bit).
def PL.word_cmp_refl(n: Nat, w: Word(n)) -> {Word.cmp(n, w, w) == EQ{} : Cmp}:
  match n:
    case 0n:
      {==}
    case 1n+p:
      match w:
        case WCon{b, t}:
          match b:
            case True{}:
              %Equal.sym(Cmp, Word.cmp(p, t, t), EQ{}, PL.word_cmp_refl(p, t)) : { Word.cmp.fin(True{}, True{}, _) == EQ{} : Cmp }
              {==}
            case False{}:
              %Equal.sym(Cmp, Word.cmp(p, t, t), EQ{}, PL.word_cmp_refl(p, t)) : { Word.cmp.fin(False{}, False{}, _) == EQ{} : Cmp }
              {==}

def PL.u32_cmp_refl(x: U32) -> {U32.cmp(x, x) == EQ{} : Cmp}:
  match x:
    case U32{w}:
      PL.word_cmp_refl(32n, w)

def PL.char_eq_refl(c: Char) -> {Char.is_eq(c, c) == True{} : Bool}:
  match c:
    case Chr{x}:
      %Equal.sym(Cmp, U32.cmp(x, x), EQ{}, PL.u32_cmp_refl(x)) : { Cmp.is_eq(_) == True{} : Bool }
      {==}

# Any string starts with the empty prefix.
def PL.starts_with_empty(s: String) -> {String.starts_with(s, SNil{}) == True{} : Bool}:
  match s:
    case SNil{}:
      {==}
    case SCon{h, t}:
      {==}

# Appending a suffix preserves the prefix relation.
def PL.starts_with_append(s: String, +suffix: String) -> {String.starts_with(String.append(s, suffix), s) == True{} : Bool}:
  match s:
    case SNil{}:
      PL.starts_with_empty(suffix)
    case SCon{h, t}:
      Equal.trans(
        Bool,
        String.starts_with.if(String.append(t, suffix), t, Char.is_eq(h, h)),
        String.starts_with(String.append(t, suffix), t),
        True{},
        Equal.cong(
          Bool,
          Bool,
          x => String.starts_with.if(String.append(t, suffix), t, x),
          Char.is_eq(h, h),
          True{},
          PL.char_eq_refl(h),
        ),
        PL.starts_with_append(t, suffix),
      )

def PL.str_eq2_refl(s: String) -> {C.Str.eq2(s, s) == True{} : Bool}:
  match s:
    case SNil{}:
      {==}
    case SCon{h, t}:
      %Equal.sym(Bool, Char.is_eq(h, h), True{}, PL.char_eq_refl(h)) : { Bool.and(_, C.Str.eq2(t, t)) == True{} : Bool }
      %Equal.sym(Bool, C.Str.eq2(t, t), True{}, PL.str_eq2_refl(t)) : { Bool.and(True{}, _) == True{} : Bool }
      {==}
