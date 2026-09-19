# Adjudicated rule-label evaluation over Markdown documents.
#
# labels.tsv has five tab-separated fields:
# document, UTF-8 SHA-256, route (`-` or comma anchors), defect rules, neutral rules.
# Rule lists use comma separators or `-`; every unlisted rule is labeled absent.
# Labels are externally asserted as independent/adjudicated—the program validates
# completeness, hashes, and scoring, but cannot prove reviewer independence.
import Base
import ./types.bend as T
import ./sha256.bend as S
import ./markdown.bend as Md
import ./mechanical.bend as M
import ./route.bend as Rt
import ./corpus.bend as Cp

type LabelCase is Data:
  LabelCase{doc: String, sha: String, route: String, defects: List<&2, String>, neutral: List<&2, String>}

type Labels is Data:
  Labels{cases: List<&2, LabelCase>, errors: String}

type Observation is Data:
  Observation{doc: String, route: String, defects: List<&2, String>, neutral: List<&2, String>, actual: List<&2, String>}

type Run is Data:
  Run{observations: List<&2, Observation>, errors: String}

type Score is Data:
  Score{tp: Nat, fp: Nat, fn: Nat, neutral: Nat}

def Le.key(c: LabelCase) -> String:
  match c:
    case LabelCase{doc, sha, route, defects, neutral}:
      doc ++ "\t" ++ route

def Le.keys(cs: List<&2, LabelCase>) -> List<&2, String>:
  match cs:
    case Nil{}:
      Nil{}
    case Con{c, t}:
      Le.key(c) <> Le.keys(t)

def Le.case_of(+fields: List<&2, String>) -> LabelCase:
  LabelCase{
    Cp.Cp.field(fields, 0n), Cp.Cp.field(fields, 1n), Cp.Cp.field(fields, 2n),
    Cp.Cp.items(Cp.Cp.field(fields, 3n)), Cp.Cp.items(Cp.Cp.field(fields, 4n)),
  }

def Le.disjoint(xs: List<&2, String>, +ys: List<&2, String>) -> Bool:
  match xs:
    case Nil{}:
      True{}
    case Con{h, t}:
      Bool.and(Bool.not(Cp.Cp.mem(ys, h)), Le.disjoint(t, ys))

def Le.case_valid(c: LabelCase) -> Bool:
  match c:
    case LabelCase{+doc, +sha, +route, +defects, +neutral}:
      Bool.and(
        Bool.and(String.ends_with(doc, ".md"), Cp.Cp.chars(String.to_list(doc), "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_" ++ ".")),
        Bool.and(
          Bool.and(Nat.is_eq(String.length(sha), 64n), Cp.Cp.chars(String.to_list(sha), "0123456789abcdef")),
          Bool.and(
            Bool.and(Cp.Cp.unique(Cp.Cp.items(route)), Cp.Cp.nonempty(Cp.Cp.items(route))),
            Bool.and(
              Bool.and(Cp.Cp.unique(defects), Bool.and(Cp.Cp.unique(neutral), Le.disjoint(defects, neutral))),
              Bool.and(Cp.Cp.known(defects), Cp.Cp.known(neutral))))))

def Le.accept(ok: Bool, c: LabelCase, cs: List<&2, LabelCase>, errors: String, line: Nat) -> Labels:
  match ok:
    case True{}:
      Labels{c <> cs, errors}
    case False{}:
      Labels{cs, "invalid or duplicate label row " ++ Nat.show(line) ++ "\n" ++ errors}

def Le.add(rest: Labels, +fields: List<&2, String>, line: Nat) -> Labels:
  match rest:
    case Labels{+cases, errors}:
      Le.accept(
        Bool.and(
          Nat.is_eq(List.length(&2, String, fields), 5n),
          Bool.and(
            Le.case_valid(Le.case_of(fields)),
            Bool.not(Cp.Cp.mem(Le.keys(cases), Le.key(Le.case_of(fields)))))),
        Le.case_of(fields), cases, errors, line)

def Le.line_if(skip: Bool, line: String, n: Nat, rest: Labels) -> Labels:
  match skip:
    case True{}:
      rest
    case False{}:
      Le.add(rest, String.split(line, '\t'), n)

def Le.lines(lines: List<&2, String>, +n: Nat) -> Labels:
  match lines:
    case Nil{}:
      Labels{Nil{}, ""}
    case Con{+line, t}:
      Le.line_if(Bool.or(String.is_empty(String.trim(line)), String.starts_with(line, "#")), line, n, Le.lines(t, Nat.add(n, 1n)))

def Le.parse(content: String) -> Labels:
  Le.lines(String.lines(content), 1n)

def Le.observe(c: LabelCase, +source: String) -> Observation:
  match c:
    case LabelCase{doc, sha, +route, defects, neutral}:
      Observation{doc, route, defects, neutral,
        M.Mech.nub(Cp.Cp.rule_ids(M.Mech.analyze(4, Rt.Route.apply(Cp.Cp.items(route), Md.Md.parse(source, S.Sha256.hex(source))))))}

def Le.one(+defect: Bool, +neutral: Bool, +actual: Bool) -> Score:
  Score{
    Cp.Cp.b2n(Bool.and(defect, actual)),
    Cp.Cp.b2n(Bool.and(actual, Bool.not(Bool.or(defect, neutral)))),
    Cp.Cp.b2n(Bool.and(defect, Bool.not(actual))),
    Cp.Cp.b2n(Bool.and(neutral, actual)),
  }

def Le.score_observation(o: Observation, +rule: String) -> Score:
  match o:
    case Observation{doc, route, defects, neutral, actual}:
      Le.one(Cp.Cp.mem(defects, rule), Cp.Cp.mem(neutral, rule), Cp.Cp.mem(actual, rule))

def Le.sum(a: Score, b: Score) -> Score:
  match a:
    case Score{tp, fp, fn, neutral}:
      match b:
        case Score{btp, bfp, bfn, bneutral}:
          Score{Nat.add(tp, btp), Nat.add(fp, bfp), Nat.add(fn, bfn), Nat.add(neutral, bneutral)}

def Le.score(os: List<&2, Observation>, +rule: String) -> Score:
  match os:
    case Nil{}:
      Score{0n, 0n, 0n, 0n}
    case Con{o, t}:
      Le.sum(Le.score_observation(o, rule), Le.score(t, rule))

def Le.total(rules: List<&2, String>, +os: List<&2, Observation>) -> Score:
  match rules:
    case Nil{}:
      Score{0n, 0n, 0n, 0n}
    case Con{r, t}:
      Le.sum(Le.score(os, r), Le.total(t, os))

def Le.score_text(s: Score) -> String:
  match s:
    case Score{+tp, +fp, +fn, neutral}:
      Nat.show(tp) ++ "\t" ++ Nat.show(fp) ++ "\t" ++ Nat.show(fn) ++ "\t" ++ Nat.show(neutral) ++ "\t" ++
      T.Metric.show(T.Metric.mk(tp, Nat.add(tp, fp))) ++ "\t" ++ T.Metric.show(T.Metric.mk(tp, Nat.add(tp, fn)))

def Le.rows(rules: List<&2, String>, +os: List<&2, Observation>) -> String:
  match rules:
    case Nil{}:
      ""
    case Con{+rule, t}:
      rule ++ "\t" ++ Le.score_text(Le.score(os, rule)) ++ "\n" ++ Le.rows(t, os)

def Le.pass(s: Score) -> Bool:
  match s:
    case Score{tp, fp, fn, neutral}:
      Bool.and(Nat.is_eq(fp, 0n), Nat.is_eq(fn, 0n))

def Le.verdict(ok: Bool) -> String:
  match ok:
    case True{}:
      "LABEL EVALUATE PASS"
    case False{}:
      "LABEL EVALUATE FAIL"

def Le.report_if(clean: Bool, +os: List<&2, Observation>, errors: String) -> String:
  match clean:
    case False{}:
      "LABEL EVALUATE FAIL (input verification)\n" ++ errors
    case True{}:
      +total = Le.total(Cp.Cp.rules(), os)
      "Adjudicated rule-label evaluation; reviewer independence/provenance is externally asserted.\n" ++
      "cases: " ++ Nat.show(List.length(&2, Observation, os)) ++ " (all source hashes verified)\n" ++
      "rule\ttp\tfp\tfn\tneutral\tprecision\trecall\n" ++ Le.rows(Cp.Cp.rules(), os) ++
      "TOTAL\t" ++ Le.score_text(total) ++ "\n" ++ Le.verdict(Le.pass(total))

def Le.report(run: Run) -> String:
  match run:
    case Run{+observations, +errors}:
      Le.report_if(String.is_empty(errors), observations, errors)

def Le.prepend(o: Observation, run: Run) -> Run:
  match run:
    case Run{observations, errors}:
      Run{o <> observations, errors}

def Le.error(message: String, run: Run) -> Run:
  match run:
    case Run{observations, errors}:
      Run{observations, message ++ "\n" ++ errors}

def Le.checked(ok: Bool, c: LabelCase, source: String, rest: Run) -> Run:
  match ok:
    case True{}:
      Le.prepend(Le.observe(c, source), rest)
    case False{}:
      Le.error("source hash mismatch: " ++ Le.key(c), rest)

def Le.source(result: Result<&1, &1, U32 & String, String>, c: LabelCase, rest: Run) -> Run:
  match result:
    case Fail{e}:
      Le.error("unreadable source: " ++ Le.key(c), rest)
    case Done{+source}:
      match c:
        case LabelCase{doc, +sha, route, defects, neutral}:
          Le.checked(String.eq(sha, S.Sha256.hex(source)), LabelCase{doc, sha, route, defects, neutral}, source, rest)

def Le.path(c: LabelCase, dir: String) -> String:
  match c:
    case LabelCase{doc, sha, route, defects, neutral}:
      dir ++ "/" ++ doc

def Le.run(cases: List<&2, LabelCase>, +dir: String) -> IO(Run):
  match cases:
    case Nil{}:
      IO.pure(Run, Run{Nil{}, ""})
    case Con{+c, t}:
      do IO<Run>:
        result : Result<&1, &1, U32 & String, String> <- Cp.Cp.read(Le.path(c, dir))
        rest : Run <- Le.run(t, dir)
        IO.pure(Run, Le.source(result, c, rest))

def Le.start_nonempty(cases: List<&2, LabelCase>, dir: String) -> IO(Unit):
  match cases:
    case Nil{}:
      IO.print("LABEL EVALUATE FAIL (empty labels)")
    case Con{c, t}:
      do IO<Unit>:
        run : Run <- Le.run(c <> t, dir)
        IO.print(Le.report(run))

def Le.start_if(clean: Bool, cases: List<&2, LabelCase>, errors: String, dir: String) -> IO(Unit):
  match clean:
    case False{}:
      IO.print("LABEL EVALUATE FAIL (invalid labels.tsv)\n" ++ errors)
    case True{}:
      Le.start_nonempty(cases, dir)

def Le.start(labels: Labels, dir: String) -> IO(Unit):
  match labels:
    case Labels{cases, +errors}:
      Le.start_if(String.is_empty(errors), cases, errors, dir)

def Le.loaded(result: Result<&1, &1, U32 & String, String>, dir: String) -> IO(Unit):
  match result:
    case Fail{e}:
      IO.print("LABEL EVALUATE FAIL (unreadable labels.tsv)")
    case Done{content}:
      Le.start(Le.parse(content), dir)

def Le.flow_dir(+dir: String) -> IO(Unit):
  do IO<Unit>:
    result : Result<&1, &1, U32 & String, String> <- Cp.Cp.read(dir ++ "/labels.tsv")
    Le.loaded(result, dir)

def Le.flow_env(result: Result<&1, &1, U32 & String, String>) -> IO(Unit):
  match result:
    case Fail{e}:
      IO.print("LABEL EVALUATE FAIL (PROSEMAP_LABEL_DIR required)")
    case Done{dir}:
      Le.flow_dir(dir)

def Le.flow() -> IO(Unit):
  do IO<Unit>:
    result : Result<&1, &1, U32 & String, String> <- IO.get_env("PROSEMAP_LABEL_DIR")
    Le.flow_env(result)
