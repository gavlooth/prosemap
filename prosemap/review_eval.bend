# Independent-review evaluation for contextual.model findings.
#
# Findings come from the ordinary compact findings JSONL. Review rows are flat
# JSON objects with findingRecordId, reviewer, disposition, and rationale. A
# complete study requires at least two distinct reviewer IDs per contextual
# finding. Reviewer independence and human provenance are external study facts;
# this module validates identifiers, coverage, agreement, and data integrity.
import Base
import ./types.bend as T
import ./json_read.bend as Jr
import ./comparison.bend as Cmp

type Row is Data:
  Row{rid: String, reviewer: String, disposition: String}

type Parsed is Data:
  Parsed{rows: List<&2, Row>, errors: String}

type Study is Data:
  Study{
    findings: Nat,
    reviews: Nat,
    covered: Nat,
    accepted: Nat,
    rejected: Nat,
    needs: Nat,
    conflicted: Nat,
    underReviewed: Nat,
    orphan: Nat,
    duplicate: Nat,
  }

def Re.b2n(b: Bool) -> Nat:
  match b:
    case True{}:
      1n
    case False{}:
      0n

def Re.row(+line: String) -> Row:
  Row{Jr.Jr.field(line, "findingRecordId"), Jr.Jr.field(line, "reviewer"), Jr.Jr.field(line, "disposition")}

def Re.disposition_ok(+s: String) -> Bool:
  Bool.or(String.eq(s, "accepted"), Bool.or(String.eq(s, "rejected"), String.eq(s, "needs-context")))

def Re.row_ok(r: Row) -> Bool:
  match r:
    case Row{+rid, +reviewer, disposition}:
      Bool.and(Bool.not(String.is_empty(rid)), Bool.and(Bool.not(String.is_empty(reviewer)), Re.disposition_ok(disposition)))

def Re.parse_put(ok: Bool, r: Row, rows: List<&2, Row>, errors: String, line: Nat) -> Parsed:
  match ok:
    case True{}:
      Parsed{r <> rows, errors}
    case False{}:
      Parsed{rows, "invalid review row " ++ Nat.show(line) ++ "\n" ++ errors}

def Re.parse_line(+line: String, n: Nat, rest: Parsed) -> Parsed:
  match rest:
    case Parsed{rows, errors}:
      Re.parse_put(
        Bool.and(Re.row_ok(Re.row(line)), Bool.not(String.is_empty(Jr.Jr.field(line, "rationale")))),
        Re.row(line), rows, errors, n)

def Re.parse_skip(skip: Bool, line: String, n: Nat, rest: Parsed) -> Parsed:
  match skip:
    case True{}:
      rest
    case False{}:
      Re.parse_line(line, n, rest)

def Re.parse_go(lines: List<&2, String>, +n: Nat) -> Parsed:
  match lines:
    case Nil{}:
      Parsed{Nil{}, ""}
    case Con{+line, t}:
      Re.parse_skip(String.is_empty(String.trim(line)), line, n, Re.parse_go(t, Nat.add(n, 1n)))

def Re.parse(content: String) -> Parsed:
  Re.parse_go(String.lines(content), 1n)

def Re.rule_id(r: T.RuleRef) -> String:
  match r:
    case T.RuleRef{id, version}:
      id

def Re.contextual(f: T.Finding) -> Bool:
  String.eq(Re.rule_id(Cmp.Fin.rule(f)), "contextual.model")

def Re.finding_put(keep: Bool, f: T.Finding, rest: List<&2, T.Finding>) -> List<&2, T.Finding>:
  match keep:
    case True{}:
      f <> rest
    case False{}:
      rest

def Re.contextual_findings(fs: List<&2, T.Finding>) -> List<&2, T.Finding>:
  match fs:
    case Nil{}:
      Nil{}
    case Con{+f, t}:
      Re.finding_put(Re.contextual(f), f, Re.contextual_findings(t))

def Re.row_rid(r: Row) -> String:
  match r:
    case Row{rid, reviewer, disposition}:
      rid

def Re.row_reviewer(r: Row) -> String:
  match r:
    case Row{rid, reviewer, disposition}:
      reviewer

def Re.row_disposition(r: Row) -> String:
  match r:
    case Row{rid, reviewer, disposition}:
      disposition

def Re.row_key(+r: Row) -> String:
  Re.row_rid(r) ++ "\t" ++ Re.row_reviewer(r)

def Re.row_matches(+r: Row, +rid: String) -> Bool:
  String.eq(Re.row_rid(r), rid)

def Re.row_keep(keep: Bool, r: Row, rest: List<&2, Row>) -> List<&2, Row>:
  match keep:
    case True{}:
      r <> rest
    case False{}:
      rest

def Re.for_finding(rows: List<&2, Row>, +rid: String) -> List<&2, Row>:
  match rows:
    case Nil{}:
      Nil{}
    case Con{+r, t}:
      Re.row_keep(Re.row_matches(r, rid), r, Re.for_finding(t, rid))

def Re.reviewers(rows: List<&2, Row>) -> List<&2, String>:
  match rows:
    case Nil{}:
      Nil{}
    case Con{r, t}:
      Re.row_reviewer(r) <> Re.reviewers(t)

def Re.count_disposition(rows: List<&2, Row>, +disposition: String) -> Nat:
  match rows:
    case Nil{}:
      0n
    case Con{r, t}:
      Nat.add(Re.b2n(String.eq(Re.row_disposition(r), disposition)), Re.count_disposition(t, disposition))

def Re.finding_ids(fs: List<&2, T.Finding>) -> List<&2, String>:
  match fs:
    case Nil{}:
      Nil{}
    case Con{f, t}:
      Cmp.Fin.recordId(f) <> Re.finding_ids(t)

def Re.orphan(rows: List<&2, Row>, +ids: List<&2, String>) -> Nat:
  match rows:
    case Nil{}:
      0n
    case Con{r, t}:
      Nat.add(Re.b2n(Bool.not(List.contains(~String, ~String.eq, ids, Re.row_rid(r)))), Re.orphan(t, ids))

def Re.duplicates(rows: List<&2, Row>, +seen: List<&2, String>) -> Nat:
  match rows:
    case Nil{}:
      0n
    case Con{+r, t}:
      +key = Re.row_key(r)
      Nat.add(Re.b2n(List.contains(~String, ~String.eq, seen, key)), Re.duplicates(t, key <> seen))

def Re.study_acc(acc: Study, reviewCount: Nat, +covered: Bool, +onlyAccepted: Bool, +onlyRejected: Bool, +onlyNeeds: Bool) -> Study:
  match acc:
    case Study{findings, reviewsTotal, coveredTotal, acceptedTotal, rejectedTotal, needsTotal, conflicts, under, orphan, duplicate}:
      Study{
        Nat.add(findings, 1n), Nat.add(reviewsTotal, reviewCount),
        Nat.add(coveredTotal, Re.b2n(covered)),
        Nat.add(acceptedTotal, Re.b2n(onlyAccepted)),
        Nat.add(rejectedTotal, Re.b2n(onlyRejected)),
        Nat.add(needsTotal, Re.b2n(onlyNeeds)),
        Nat.add(conflicts, Re.b2n(Bool.and(covered, Bool.not(Bool.or(onlyAccepted, Bool.or(onlyRejected, onlyNeeds)))))),
        Nat.add(under, Re.b2n(Bool.not(covered))), orphan, duplicate,
      }

def Re.study_add(+rid: String, +rows: List<&2, Row>, acc: Study) -> Study:
  +mine = Re.for_finding(rows, rid)
  +reviewers = Cmp.Cmp.nub(Re.reviewers(mine))
  +reviewCount = List.length(&2, String, reviewers)
  +covered = Nat.is_ge(reviewCount, 2n)
  +accepted = Re.count_disposition(mine, "accepted")
  +rejected = Re.count_disposition(mine, "rejected")
  +needs = Re.count_disposition(mine, "needs-context")
  +onlyAccepted = Bool.and(covered, Bool.and(Nat.is_gt(accepted, 0n), Bool.and(Nat.is_eq(rejected, 0n), Nat.is_eq(needs, 0n))))
  +onlyRejected = Bool.and(covered, Bool.and(Nat.is_gt(rejected, 0n), Bool.and(Nat.is_eq(accepted, 0n), Nat.is_eq(needs, 0n))))
  +onlyNeeds = Bool.and(covered, Bool.and(Nat.is_gt(needs, 0n), Bool.and(Nat.is_eq(accepted, 0n), Nat.is_eq(rejected, 0n))))
  Re.study_acc(acc, List.length(&2, Row, mine), covered, onlyAccepted, onlyRejected, onlyNeeds)

def Re.study_go(fs: List<&2, T.Finding>, +rows: List<&2, Row>, acc: Study) -> Study:
  match fs:
    case Nil{}:
      acc
    case Con{f, t}:
      Re.study_go(t, rows, Re.study_add(Cmp.Fin.recordId(f), rows, acc))

def Re.study(+fs: List<&2, T.Finding>, +rows: List<&2, Row>) -> Study:
  +ids = Re.finding_ids(fs)
  Re.study_go(fs, rows, Study{0n, 0n, 0n, 0n, 0n, 0n, 0n, 0n, Re.orphan(rows, ids), Re.duplicates(rows, Nil{})})

def Re.valid_study(s: Study) -> Bool:
  match s:
    case Study{findings, reviews, covered, accepted, rejected, needs, conflicted, under, orphan, duplicate}:
      Bool.and(Nat.is_gt(findings, 0n), Bool.and(Nat.is_eq(under, 0n), Bool.and(Nat.is_eq(orphan, 0n), Nat.is_eq(duplicate, 0n))))

def Re.verdict(ok: Bool) -> String:
  match ok:
    case True{}:
      "REVIEW EVALUATE PASS"
    case False{}:
      "REVIEW EVALUATE FAIL"

def Re.report(s: Study, +errors: String) -> String:
  match s:
    case Study{+findings, +reviews, +covered, +accepted, +rejected, +needs, +conflicted, +under, +orphan, +duplicate}:
      "Independent-review data check; reviewer identity/provenance is externally asserted.\n" ++
      "contextual findings: " ++ Nat.show(findings) ++ "  review rows: " ++ Nat.show(reviews) ++ "\n" ++
      "coverage (>=2 distinct reviewers): " ++ Nat.show(covered) ++ "/" ++ Nat.show(findings) ++ "\n" ++
      "consensus accepted: " ++ Nat.show(accepted) ++ "  rejected: " ++ Nat.show(rejected) ++
      "  needs-context: " ++ Nat.show(needs) ++ "  conflicted: " ++ Nat.show(conflicted) ++ "\n" ++
      "under-reviewed: " ++ Nat.show(under) ++ "  orphan rows: " ++ Nat.show(orphan) ++
      "  duplicate reviewer rows: " ++ Nat.show(duplicate) ++ "\n" ++
      errors ++ Re.verdict(Bool.and(String.is_empty(errors), Re.valid_study(Study{findings, reviews, covered, accepted, rejected, needs, conflicted, under, orphan, duplicate})))

def Re.read_finish(rd: File & Result<&1, &1, U32 & String, String>) -> IO(Result<&1, &1, U32 & String, String>):
  (f, result) = rd
  do IO<Result<&1, &1, U32 & String, String>>:
    File.close(f)
    IO.pure(Result<&1, &1, U32 & String, String>, result)

def Re.read_open(result: Result<&1, &1, U32 & String, File>) -> IO(Result<&1, &1, U32 & String, String>):
  match result:
    case Fail{e}:
      IO.pure(Result<&1, &1, U32 & String, String>, Fail{e})
    case Done{f}:
      do IO<Result<&1, &1, U32 & String, String>>:
        rd : File & Result<&1, &1, U32 & String, String> <- File.read(f, 5000000)
        Re.read_finish(rd)

def Re.read(path: String) -> IO(Result<&1, &1, U32 & String, String>):
  do IO<Result<&1, &1, U32 & String, String>>:
    result : Result<&1, &1, U32 & String, File> <- File.open(path, "r")
    Re.read_open(result)

def Re.finding_error_put(ok: Bool, line: Nat, rest: String) -> String:
  match ok:
    case True{}:
      rest
    case False{}:
      "invalid finding row " ++ Nat.show(line) ++ "\n" ++ rest

def Re.finding_line(skip: Bool, +raw: String, line: Nat, rest: String) -> String:
  match skip:
    case True{}:
      rest
    case False{}:
      Re.finding_error_put(
        Bool.and(Bool.not(String.is_empty(Jr.Jr.field(raw, "recordId"))), Bool.not(String.is_empty(Jr.Jr.field(raw, "rule")))),
        line, rest)

def Re.finding_errors_go(lines: List<&2, String>, +line: Nat) -> String:
  match lines:
    case Nil{}:
      ""
    case Con{+raw, t}:
      Re.finding_line(
        String.is_empty(String.trim(raw)), raw, line,
        Re.finding_errors_go(t, Nat.add(line, 1n)))

def Re.finding_errors(content: String) -> String:
  Re.finding_errors_go(String.lines(content), 1n)

def Re.duplicate_error_if(unique: Bool) -> String:
  match unique:
    case True{}:
      ""
    case False{}:
      "duplicate contextual finding recordId\n"

def Re.duplicate_finding_error(fs: List<&2, T.Finding>) -> String:
  +ids = Re.finding_ids(fs)
  Re.duplicate_error_if(Nat.is_eq(List.length(&2, String, ids), List.length(&2, String, Cmp.Cmp.nub(ids))))

def Re.report_parsed(parsed: Parsed, +findingsContent: String) -> IO(Unit):
  match parsed:
    case Parsed{rows, errors}:
      IO.print(Re.report(
        Re.study(Re.contextual_findings(Jr.Jr.parse(findingsContent)), rows),
        errors ++ Re.finding_errors(findingsContent) ++
          Re.duplicate_finding_error(Re.contextual_findings(Jr.Jr.parse(findingsContent)))))

def Re.loaded(findingsResult: Result<&1, &1, U32 & String, String>, reviewsResult: Result<&1, &1, U32 & String, String>) -> IO(Unit):
  match findingsResult:
    case Fail{e}:
      IO.print("REVIEW EVALUATE FAIL (unreadable findings)")
    case Done{findingsContent}:
      match reviewsResult:
        case Fail{e}:
          IO.print("REVIEW EVALUATE FAIL (unreadable reviews)")
        case Done{reviewsContent}:
          Re.report_parsed(Re.parse(reviewsContent), findingsContent)

def Re.flow_paths(findingsPath: String, reviewsPath: String) -> IO(Unit):
  do IO<Unit>:
    findingsResult : Result<&1, &1, U32 & String, String> <- Re.read(findingsPath)
    reviewsResult : Result<&1, &1, U32 & String, String> <- Re.read(reviewsPath)
    Re.loaded(findingsResult, reviewsResult)

def Re.env_or(result: Result<&1, &1, U32 & String, String>, default: String) -> String:
  match result:
    case Done{value}:
      value
    case Fail{e}:
      default

def Re.flow() -> IO(Unit):
  do IO<Unit>:
    findingsEnv : Result<&1, &1, U32 & String, String> <- IO.get_env("PROSEMAP_FINDINGS")
    reviewsEnv : Result<&1, &1, U32 & String, String> <- IO.get_env("PROSEMAP_REVIEWS")
    Re.flow_paths(Re.env_or(findingsEnv, "findings.jsonl"), Re.env_or(reviewsEnv, "reviews.jsonl"))
