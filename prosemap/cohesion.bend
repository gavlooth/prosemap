# Lexical cohesion kernel — tokenization plus exact set Jaccard and multiset
# Dice over token lists. Neither score carries a quality judgment.
#
# Representation choices (intentional):
# - Metrics are EXACT RATIONALS (num/den as Nat), not F32. Base has no F32.show
#   and floats can diverge across CPU/GPU; rationals are deterministic and
#   serializable. Downstream can divide if it wants a decimal.
# - Tokenizer is ASCII-fold (lowercase, split on non-alphanumeric, drop
#   length-<=1 and stop-word tokens). Full Unicode NFKC is deferred; the
#   fixtures are ASCII so results match.
import Base
import ./types.bend as T


# ---------------------------------------------------------------------------
# Metric compatibility
# ---------------------------------------------------------------------------
# Metric's data representation and constructors live in types.bend. Keep this
# display entry point for current cohesion renderers.
def Metric.show(m: T.Metric) -> String:
  T.Metric.show(m)

# den == 0 -> unassessed (matches TS unionSize/tokenTotal == 0 guard)
def Cohesion.mk_metric(num: Nat, +den: Nat) -> T.Metric:
  T.Metric.mk(num, den)

# ---------------------------------------------------------------------------
# Tokenizer
# ---------------------------------------------------------------------------
# non-alphanumeric -> space; alphanumeric -> lowercase.
# Affine param (List.map needs `Char -> Char`); copy it reusable internally.
def Cohesion.norm_char(c: Char) -> Char:
  +cc = c
  Bool.pick(Char, Bool.or(Char.is_alpha(cc), Char.is_digit(cc)), Char.to_lower(cc), Chr{32})

# String is itself a char list; recurse directly (avoids List.map kind juggling).
def Cohesion.norm(s: String) -> String:
  match s:
    case SNil{}:
      SNil{}
    case SCon{h, t}:
      SCon{Cohesion.norm_char(h), Cohesion.norm(t)}

# Bundled English stop words (data, not a dependency — matches ENGLISH_STOP_WORDS_V1)
def Cohesion.stopwords() -> List<&2, String>:
  [ "a", "about", "after", "again", "against", "all", "am", "an", "and", "any",
    "are", "as", "at", "be", "because", "been", "before", "being", "between",
    "both", "but", "by", "can", "could", "did", "do", "does", "doing", "down",
    "during", "each", "few", "for", "from", "further", "had", "has", "have",
    "having", "he", "her", "here", "hers", "herself", "him", "himself", "his",
    "how", "i", "if", "in", "into", "is", "it", "its", "itself", "just", "me",
    "more", "most", "my", "myself", "no", "nor", "not", "now", "of", "off",
    "on", "once", "only", "or", "other", "our", "ours", "ourselves", "out",
    "over", "own", "same", "she", "should", "so", "some", "such", "than",
    "that", "the", "their", "theirs", "them", "themselves", "then", "there",
    "these", "they", "this", "those", "through", "to", "too", "under", "until",
    "up", "very", "was", "we", "were", "what", "when", "where", "which",
    "while", "who", "whom", "why", "will", "with", "would", "you", "your",
    "yours", "yourself", "yourselves" ]

# keep tokens longer than one char that are not stop words.
# Affine param (List.filter needs `String -> Bool`); copy it reusable internally.
def Cohesion.keep(t: String) -> Bool:
  +tt = t
  Bool.and(
    Nat.is_gt(String.length(tt), 1n),
    Bool.not(List.contains(~String, ~String.eq, Cohesion.stopwords(), tt)),
  )

def Cohesion.tokenize(s: String) -> List<&2, String>:
  List.filter(~String, ~Cohesion.keep, String.split(Cohesion.norm(s), ' '))

# ---------------------------------------------------------------------------
# Set / multiset helpers over token lists
# ---------------------------------------------------------------------------
def Str.count.if(same: Bool, rest: Nat) -> Nat:
  match same:
    case True{}:
      1n+rest
    case False{}:
      rest

# occurrences of x in xs (multiset count)
def Str.count(xs: List<&2, String>, +x: String) -> Nat:
  match xs:
    case Nil{}:
      0n
    case Con{h, t}:
      Str.count.if(String.eq(h, x), Str.count(t, x))

def Str.nub.if(present: Bool, h: String, acc: List<&2, String>) -> List<&2, String>:
  match present:
    case True{}:
      acc
    case False{}:
      h <> acc

def Str.nub.go(xs: List<&2, String>, +acc: List<&2, String>) -> List<&2, String>:
  match xs:
    case Nil{}:
      List.reverse(&2, String, acc)
    case Con{+h, t}:
      Str.nub.go(t, Str.nub.if(List.contains(~String, ~String.eq, acc, h), h, acc))

# distinct terms, in first-seen order
def Str.nub(xs: List<&2, String>) -> List<&2, String>:
  Str.nub.go(xs, Nil{})

def Str.inter.if(present: Bool, h: String, rest: List<&2, String>) -> List<&2, String>:
  match present:
    case True{}:
      h <> rest
    case False{}:
      rest

# distinct terms of `a` that also occur in `b` (a should be pre-deduped)
def Str.inter(a: List<&2, String>, +b: List<&2, String>) -> List<&2, String>:
  match a:
    case Nil{}:
      Nil{}
    case Con{+h, t}:
      Str.inter.if(List.contains(~String, ~String.eq, b, h), h, Str.inter(t, b))

# count of elements of xs not present in base
def Str.count_absent(+base: List<&2, String>, xs: List<&2, String>) -> Nat:
  match xs:
    case Nil{}:
      0n
    case Con{+h, t}:
      Str.count.if(Bool.not(List.contains(~String, ~String.eq, base, h)), Str.count_absent(base, t))

# |distinct(a) ∪ distinct(b)| given the two distinct lists
def Str.union_size(+da: List<&2, String>, db: List<&2, String>) -> Nat:
  Nat.add(List.length(&2, String, da), Str.count_absent(da, db))

# sum over intersection terms of min(count in left, count in right)
def Str.overlap(inter: List<&2, String>, +left: List<&2, String>, +right: List<&2, String>) -> Nat:
  match inter:
    case Nil{}:
      0n
    case Con{+h, t}:
      Nat.add(Nat.min(Str.count(left, h), Str.count(right, h)), Str.overlap(t, left, right))

# ---------------------------------------------------------------------------
# compareLexicalTokens
# ---------------------------------------------------------------------------
type Cmp3 is Data:
  Cmp3{inter: List<&2, String>, jaccard: T.Metric, dice: T.Metric}

def Cohesion.compare(+left: List<&2, String>, +right: List<&2, String>) -> Cmp3:
  +da    = Str.nub(left)
  +db    = Str.nub(right)
  +inter = Str.inter(da, db)
  +usize = Str.union_size(da, db)
  +lenL  = List.length(&2, String, left)
  +lenR  = List.length(&2, String, right)
  +ov    = Str.overlap(inter, left, right)
  isize  = List.length(&2, String, inter)
  sorted = List.sort(~String, ~String.is_le, inter)
  jaccard = Cohesion.mk_metric(isize, usize)
  dice    = Cohesion.mk_metric(Nat.mul(2n, ov), Nat.add(lenL, lenR))
  Cmp3{sorted, jaccard, dice}
