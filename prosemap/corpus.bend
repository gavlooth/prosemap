# Frozen Markdown regression corpus. Each TSV row is:
# filename, UTF-8 SHA-256, comma-separated route (or -), expected rule IDs (or -).
# Labels describe rule emissions, NOT independently established writing defects.
# Every unlisted rule is forbidden. Counts are binary per (document, route, rule).
import Base
import ./types.bend as T
import ./sha256.bend as S
import ./markdown.bend as Md
import ./mechanical.bend as M
import ./route.bend as Rt

type Case is Data:
  Case{doc: String, sha: String, route: String, expected: List<&2, String>}

type Corpus is Data:
  Corpus{cases: List<&2, Case>, errors: String}

type Observation is Data:
  Observation{doc: String, route: String, expected: List<&2, String>, actual: List<&2, String>}

type Run is Data:
  Run{observations: List<&2, Observation>, errors: String}

type Score is Data:
  Score{hit: Nat, extra: Nat, miss: Nat}

def Cp.rules() -> List<&2, String>:
  ["structure.heading-depth", "structure.heading-transition",
   "structure.duplicate-id", "structure.expanded-duplicate",
   "reference.unresolved", "reference.route-edge", "notation.case-similar",
   "formula.ari", "terminology.definition", "terminology.introduction-density",
   "source.escaped-pipe", "source.ascii-diagram"]

def Cp.mem(xs: List<&2, String>, +x: String) -> Bool:
  List.contains(~String, ~String.eq, xs, x)

def Cp.b2n(b: Bool) -> Nat:
  match b:
    case True{}:
      1n
    case False{}:
      0n

def Cp.value(m: Maybe<&2, String>) -> String:
  match m:
    case None{}:
      ""
    case Some{s}:
      s

def Cp.field(fs: List<&2, String>, n: Nat) -> String:
  Cp.value(List.get(&2, String, fs, n))

def Cp.items_if(empty: Bool, s: String) -> List<&2, String>:
  match empty:
    case True{}:
      Nil{}
    case False{}:
      String.split(s, ',')

def Cp.items(+s: String) -> List<&2, String>:
  Cp.items_if(String.eq(s, "-"), s)

def Cp.chars(cs: List<&2, Char>, +allowed: String) -> Bool:
  match cs:
    case Nil{}:
      True{}
    case Con{c, t}:
      Bool.and(String.contains(allowed, String.from_list([c])), Cp.chars(t, allowed))

def Cp.unique(xs: List<&2, String>) -> Bool:
  match xs:
    case Nil{}:
      True{}
    case Con{h, +t}:
      Bool.and(Bool.not(Cp.mem(t, h)), Cp.unique(t))

def Cp.known(xs: List<&2, String>) -> Bool:
  match xs:
    case Nil{}:
      True{}
    case Con{h, t}:
      Bool.and(Cp.mem(Cp.rules(), h), Cp.known(t))

def Cp.nonempty(xs: List<&2, String>) -> Bool:
  match xs:
    case Nil{}:
      True{}
    case Con{h, t}:
      Bool.and(Bool.not(String.is_empty(h)), Cp.nonempty(t))

def Cp.valid(c: Case) -> Bool:
  match c:
    case Case{+doc, +sha, +route, +expected}:
      Bool.and(
        Bool.and(String.ends_with(doc, ".md"), Cp.chars(String.to_list(doc), "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_.")),
        Bool.and(
          Bool.and(Nat.is_eq(String.length(sha), 64n), Cp.chars(String.to_list(sha), "0123456789abcdef")),
          Bool.and(Bool.and(Cp.unique(Cp.items(route)), Cp.nonempty(Cp.items(route))),
            Bool.and(Cp.unique(expected), Cp.known(expected)))))

def Cp.key(c: Case) -> String:
  match c:
    case Case{doc, sha, route, expected}:
      doc ++ "\t" ++ route

def Cp.keys(cs: List<&2, Case>) -> List<&2, String>:
  match cs:
    case Nil{}:
      Nil{}
    case Con{c, t}:
      Cp.key(c) <> Cp.keys(t)

def Cp.row_case(+fs: List<&2, String>) -> Case:
  Case{Cp.field(fs, 0n), Cp.field(fs, 1n), Cp.field(fs, 2n), Cp.items(Cp.field(fs, 3n))}

def Cp.accept(valid: Bool, c: Case, cs: List<&2, Case>, errors: String, line: Nat) -> Corpus:
  match valid:
    case True{}:
      Corpus{c <> cs, errors}
    case False{}:
      Corpus{cs, "invalid or duplicate corpus row " ++ Nat.show(line) ++ "\n" ++ errors}

def Cp.add_row(rest: Corpus, +fs: List<&2, String>, line: Nat) -> Corpus:
  match rest:
    case Corpus{+cs, errors}:
      Cp.accept(Bool.and(Nat.is_eq(List.length(&2, String, fs), 4n),
        Bool.and(Cp.valid(Cp.row_case(fs)), Bool.not(Cp.mem(Cp.keys(cs), Cp.key(Cp.row_case(fs)))))),
        Cp.row_case(fs), cs, errors, line)

def Cp.parse_row_if(skip: Bool, s: String, line: Nat, rest: Corpus) -> Corpus:
  match skip:
    case True{}:
      rest
    case False{}:
      Cp.add_row(rest, String.split(s, '\t'), line)

def Cp.parse_row(+s: String, line: Nat, rest: Corpus) -> Corpus:
  Cp.parse_row_if(Bool.or(String.is_empty(String.trim(s)), String.starts_with(s, "#")), s, line, rest)

def Cp.parse_lines(lines: List<&2, String>, +line: Nat) -> Corpus:
  match lines:
    case Nil{}:
      Corpus{Nil{}, ""}
    case Con{s, t}:
      Cp.parse_row(s, line, Cp.parse_lines(t, Nat.add(line, 1n)))

def Cp.parse(s: String) -> Corpus:
  Cp.parse_lines(String.lines(s), 1n)

def Cp.rule_id(f: T.Finding) -> String:
  match f:
    case T.Finding{recordId, rule, dimension, origin, kind, title, message, evidence, evidenceFingerprint, severity}:
      M.RuleRef.id(rule)

def Cp.rule_ids(fs: List<&2, T.Finding>) -> List<&2, String>:
  match fs:
    case Nil{}:
      Nil{}
    case Con{f, t}:
      Cp.rule_id(f) <> Cp.rule_ids(t)

def Cp.observe(c: Case, +source: String) -> Observation:
  match c:
    case Case{doc, sha, +route, expected}:
      Observation{doc, route, expected,
        M.Mech.nub(Cp.rule_ids(M.Mech.analyze(4, Rt.Route.apply(Cp.items(route), Md.Md.parse(source, S.Sha256.hex(source))))))}

def Cp.put(keep: Bool, h: String, rest: List<&2, String>) -> List<&2, String>:
  match keep:
    case True{}:
      h <> rest
    case False{}:
      rest

def Cp.difference(xs: List<&2, String>, +ys: List<&2, String>) -> List<&2, String>:
  match xs:
    case Nil{}:
      Nil{}
    case Con{+h, t}:
      Cp.put(Bool.not(Cp.mem(ys, h)), h, Cp.difference(t, ys))

def Cp.score_one(+expected: Bool, +actual: Bool) -> Score:
  Score{Cp.b2n(Bool.and(expected, actual)),
    Cp.b2n(Bool.and(actual, Bool.not(expected))),
    Cp.b2n(Bool.and(expected, Bool.not(actual)))}

def Cp.score_obs(o: Observation, +rule: String) -> Score:
  match o:
    case Observation{doc, route, expected, actual}:
      Cp.score_one(Cp.mem(expected, rule), Cp.mem(actual, rule))

def Cp.sum(a: Score, b: Score) -> Score:
  match a:
    case Score{h, e, m}:
      match b:
        case Score{bh, be, bm}:
          Score{Nat.add(h, bh), Nat.add(e, be), Nat.add(m, bm)}

def Cp.score(os: List<&2, Observation>, +rule: String) -> Score:
  match os:
    case Nil{}:
      Score{0n, 0n, 0n}
    case Con{o, t}:
      Cp.sum(Cp.score_obs(o, rule), Cp.score(t, rule))

def Cp.total(rules: List<&2, String>, +os: List<&2, Observation>) -> Score:
  match rules:
    case Nil{}:
      Score{0n, 0n, 0n}
    case Con{r, t}:
      Cp.sum(Cp.score(os, r), Cp.total(t, os))

def Cp.score_text(s: Score) -> String:
  match s:
    case Score{+h, +e, +m}:
      Nat.show(h) ++ "\t" ++ Nat.show(e) ++ "\t" ++ Nat.show(m) ++ "\t" ++
      T.Metric.show(T.Metric.mk(h, Nat.add(h, e))) ++ "\t" ++ T.Metric.show(T.Metric.mk(h, Nat.add(h, m)))

def Cp.rows(rules: List<&2, String>, +os: List<&2, Observation>) -> String:
  match rules:
    case Nil{}:
      ""
    case Con{+r, t}:
      r ++ "\t" ++ Cp.score_text(Cp.score(os, r)) ++ "\n" ++ Cp.rows(t, os)

def Cp.issues(os: List<&2, Observation>) -> String:
  match os:
    case Nil{}:
      ""
    case Con{Observation{doc, route, +expected, +actual}, t}:
      doc ++ " [" ++ route ++ "] missing={" ++ String.join(Cp.difference(expected, actual), ",") ++
        "} unexpected={" ++ String.join(Cp.difference(actual, expected), ",") ++ "}\n" ++ Cp.issues(t)

def Cp.verdict_if(ok: Bool) -> String:
  match ok:
    case True{}:
      "CORPUS PASS"
    case False{}:
      "CORPUS FAIL (emission mismatch)"

def Cp.verdict(s: Score) -> String:
  match s:
    case Score{h, e, m}:
      Cp.verdict_if(Bool.and(Nat.is_eq(e, 0n), Nat.is_eq(m, 0n)))

def Cp.report_if(clean: Bool, +os: List<&2, Observation>, errors: String) -> String:
  match clean:
    case False{}:
      "CORPUS FAIL (input verification)\n" ++ errors
    case True{}:
      "Synthetic emission regression; not writing-defect accuracy.\n" ++
      "configuration: heading depth=4; ARI words=100 sentences=3; term density=3; rules @1\n" ++
      "cases: " ++ Nat.show(List.length(&2, Observation, os)) ++ " (all source hashes verified)\n" ++
      Cp.issues(os) ++ "rule\thit\textra\tmiss\tprecision\trecall\n" ++ Cp.rows(Cp.rules(), os) ++
      "TOTAL\t" ++ Cp.score_text(Cp.total(Cp.rules(), os)) ++ "\n" ++
      "Terminology positive coverage: unsupported by the Markdown extractor.\n" ++
      Cp.verdict(Cp.total(Cp.rules(), os))

def Cp.report(run: Run) -> String:
  match run:
    case Run{+os, +errors}:
      Cp.report_if(String.is_empty(errors), os, errors)

# IO follows evaluation.bend's bounded file reads, but preserves errors so a
# missing input cannot be mistaken for a clean empty document.
def Cp.read_finish(rd: File & Result<&1, &1, U32 & String, String>) -> IO(Result<&1, &1, U32 & String, String>):
  (f, res) = rd
  do IO<Result<&1, &1, U32 & String, String>>:
    File.close(f)
    IO.pure(Result<&1, &1, U32 & String, String>, res)

def Cp.read_open(r: Result<&1, &1, U32 & String, File>) -> IO(Result<&1, &1, U32 & String, String>):
  match r:
    case Fail{e}:
      IO.pure(Result<&1, &1, U32 & String, String>, Fail{e})
    case Done{f}:
      do IO<Result<&1, &1, U32 & String, String>>:
        rd : File & Result<&1, &1, U32 & String, String> <- File.read(f, 5000000)
        Cp.read_finish(rd)

def Cp.read(path: String) -> IO(Result<&1, &1, U32 & String, String>):
  do IO<Result<&1, &1, U32 & String, String>>:
    r : Result<&1, &1, U32 & String, File> <- File.open(path, "r")
    Cp.read_open(r)

def Cp.prepend(o: Observation, r: Run) -> Run:
  match r:
    case Run{os, errors}:
      Run{o <> os, errors}

def Cp.error(message: String, r: Run) -> Run:
  match r:
    case Run{os, errors}:
      Run{os, message ++ "\n" ++ errors}

def Cp.checked(ok: Bool, c: Case, source: String, rest: Run) -> Run:
  match ok:
    case True{}:
      Cp.prepend(Cp.observe(c, source), rest)
    case False{}:
      Cp.error("source hash mismatch: " ++ Cp.key(c), rest)

def Cp.source(r: Result<&1, &1, U32 & String, String>, c: Case, rest: Run) -> Run:
  match r:
    case Fail{e}:
      Cp.error("unreadable source: " ++ Cp.key(c), rest)
    case Done{+source}:
      match c:
        case Case{doc, +sha, route, expected}:
          Cp.checked(String.eq(sha, S.Sha256.hex(source)), Case{doc, sha, route, expected}, source, rest)

def Cp.path(c: Case, dir: String) -> String:
  match c:
    case Case{doc, sha, route, expected}:
      dir ++ "/" ++ doc

def Cp.run(cs: List<&2, Case>, +dir: String) -> IO(Run):
  match cs:
    case Nil{}:
      IO.pure(Run, Run{Nil{}, ""})
    case Con{+c, t}:
      do IO<Run>:
        r : Result<&1, &1, U32 & String, String> <- Cp.read(Cp.path(c, dir))
        rest : Run <- Cp.run(t, dir)
        IO.pure(Run, Cp.source(r, c, rest))

def Cp.start_nonempty(cs: List<&2, Case>, dir: String) -> IO(Unit):
  match cs:
    case Nil{}:
      IO.print("CORPUS FAIL (empty corpus)")
    case Con{c, t}:
      do IO<Unit>:
        result : Run <- Cp.run(c <> t, dir)
        IO.print(Cp.report(result))

def Cp.start_if(clean: Bool, cs: List<&2, Case>, errors: String, dir: String) -> IO(Unit):
  match clean:
    case False{}:
      IO.print("CORPUS FAIL (invalid manifest)\n" ++ errors)
    case True{}:
      Cp.start_nonempty(cs, dir)

def Cp.start(corpus: Corpus, dir: String) -> IO(Unit):
  match corpus:
    case Corpus{cs, +errors}:
      Cp.start_if(String.is_empty(errors), cs, errors, dir)
def Cp.loaded(r: Result<&1, &1, U32 & String, String>, dir: String) -> IO(Unit):
  match r:
    case Fail{e}:
      IO.print("CORPUS FAIL (unreadable cases.tsv)")
    case Done{s}:
      Cp.start(Cp.parse(s), dir)

def Cp.flow_dir(+dir: String) -> IO(Unit):
  do IO<Unit>:
    r : Result<&1, &1, U32 & String, String> <- Cp.read(dir ++ "/cases.tsv")
    Cp.loaded(r, dir)

def Cp.flow_env(r: Result<&1, &1, U32 & String, String>) -> IO(Unit):
  match r:
    case Fail{e}:
      Cp.flow_dir("fixtures/corpus")
    case Done{dir}:
      Cp.flow_dir(dir)

def Cp.flow() -> IO(Unit):
  do IO<Unit>:
    r : Result<&1, &1, U32 & String, String> <- IO.get_env("PROSEMAP_CORPUS_DIR")
    Cp.flow_env(r)
