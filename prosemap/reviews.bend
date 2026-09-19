# Reviews — human dispositions on findings, read from reviews.jsonl and applied.
# Each line: {"findingRecordId":..,"reviewer":..,"disposition":"accepted|rejected|
# needs-context","rationale":..}. Rejected findings are suppressed from output and
# excluded from the gate; accepted/needs-context pass through.
import Base
import ./types.bend as T
import ./json_read.bend as Jr
import ./comparison.bend as Cmp

def Rv.parse_disp(+s: String) -> T.Disposition:
  Bool.pick(T.Disposition, String.eq(s, "rejected"), T.Rejected{},
    Bool.pick(T.Disposition, String.eq(s, "needs-context"), T.NeedsContext{}, T.Accepted{}))

def Rv.review_of(+line: String) -> T.Review:
  T.Review{
    Jr.Jr.field(line, "findingRecordId"),
    Jr.Jr.field(line, "reviewer"),
    Rv.parse_disp(Jr.Jr.field(line, "disposition")),
    Jr.Jr.field(line, "rationale"),
  }

def Rv.line_put(keep: Bool, l: String, rest: List<&2, T.Review>) -> List<&2, T.Review>:
  match keep:
    case True{}:
      Rv.review_of(l) <> rest
    case False{}:
      rest

def Rv.lines_go(lines: List<&2, String>) -> List<&2, T.Review>:
  match lines:
    case Nil{}:
      Nil{}
    case Con{+l, t}:
      Rv.line_put(Bool.not(String.is_empty(l)), l, Rv.lines_go(t))

def Rv.parse(content: String) -> List<&2, T.Review>:
  Rv.lines_go(String.lines(content))

# --- apply: drop findings whose recordId has a Rejected review --------------
def Rv.disp_rejected(d: T.Disposition) -> Bool:
  match d:
    case T.Rejected{}:
      True{}
    case T.Accepted{}:
      False{}
    case T.NeedsContext{}:
      False{}

def Rv.is_rejected(r: T.Review) -> Bool:
  match r:
    case T.Review{findingRecordId, reviewer, disposition, rationale}:
      Rv.disp_rejected(disposition)

def Rv.review_rid(r: T.Review) -> String:
  match r:
    case T.Review{findingRecordId, reviewer, disposition, rationale}:
      findingRecordId

def Rv.rid_put(rej: Bool, r: T.Review, rest: List<&2, String>) -> List<&2, String>:
  match rej:
    case True{}:
      Rv.review_rid(r) <> rest
    case False{}:
      rest

# record ids that carry a Rejected disposition
def Rv.rejected_ids(reviews: List<&2, T.Review>) -> List<&2, String>:
  match reviews:
    case Nil{}:
      Nil{}
    case Con{+r, t}:
      Rv.rid_put(Rv.is_rejected(r), r, Rv.rejected_ids(t))

def Rv.keep_finding(rejected: Bool, f: T.Finding, rest: List<&2, T.Finding>) -> List<&2, T.Finding>:
  match rejected:
    case True{}:
      rest
    case False{}:
      f <> rest

# drop findings whose recordId is in the rejected set
def Rv.apply(+rejected: List<&2, String>, findings: List<&2, T.Finding>) -> List<&2, T.Finding>:
  match findings:
    case Nil{}:
      Nil{}
    case Con{+f, t}:
      Rv.keep_finding(List.contains(~String, ~String.eq, rejected, Cmp.Fin.recordId(f)), f, Rv.apply(rejected, t))
