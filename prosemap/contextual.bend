# Contextual stage — evidence re-verification core (the security-critical rule:
# cited evidence must reproduce the source before a candidate is trusted).
#
# A contextual (LLM) provider returns candidates that CITE evidence. Before any
# candidate is trusted, every cited evidence span is re-sliced from the source
# and compared to its claimed excerpt; candidates whose evidence does not match
# are dropped. This module is that pure filter. The network transport (a loopback
# TCP JSON POST — Bend TCP has no DNS/TLS) is a separate, deferred piece; this
# core needs no I/O and is fully testable.
import Base
import ./types.bend as T
import ./contracts.bend as C
import ./markdown.bend as Md
import ./sha256.bend as S
import ./json_read.bend as Jr

# keep an evidence item only if it re-verifies against the source
def Ctx.keep(ok: Bool, ev: T.Evidence, rest: List<&2, T.Evidence>) -> List<&2, T.Evidence>:
  match ok:
    case True{}:
      ev <> rest
    case False{}:
      rest

# retain only evidence whose recorded excerpt equals source[span] and whose
# document hash matches (Evidence.integrity from contracts.bend).
def Ctx.verify(+source: String, +docsha: String, evs: List<&2, T.Evidence>) -> List<&2, T.Evidence>:
  match evs:
    case Nil{}:
      Nil{}
    case Con{+ev, t}:
      Ctx.keep(C.Evidence.integrity(source, ev, docsha), ev, Ctx.verify(source, docsha, t))

# a candidate is admissible only if ALL of its cited evidence re-verifies, i.e.
# verifying its evidence drops nothing.
def Ctx.all_verified(+source: String, +docsha: String, +evs: List<&2, T.Evidence>) -> Bool:
  Nat.is_eq(List.length(&2, T.Evidence, Ctx.verify(source, docsha, evs)), List.length(&2, T.Evidence, evs))

# ---------------------------------------------------------------------------
# Network transport — plaintext HTTP POST to a LOOPBACK contextual provider.
# Bend Base has raw TCP but no DNS/TLS, so this is 127.0.0.1 plaintext HTTP;
# HTTPS is a later effs/tls.c FFI shim. Returns the raw response (headers+body).
# ---------------------------------------------------------------------------

# build a minimal HTTP/1.1 POST request
def Ctx.request(+path: String, +body: String) -> String:
  "POST " ++ path ++ " HTTP/1.1\r\nHost: 127.0.0.1\r\nContent-Type: application/json\r\n" ++
  "Content-Length: " ++ Nat.show(String.length(body)) ++ "\r\nConnection: close\r\n\r\n" ++ body

def Ctx.after_recv(m: Socket & Result<&1, &1, U32 & String, String>) -> IO(String):
  (s, r) = m
  do IO<String>:
    Socket.close(s)
    IO.pass(String, r)

def Ctx.after_send(m: Socket & Result<&1, &1, U32 & String, Unit>) -> IO(String):
  (s, r) = m
  do IO<String>:
    IO.pass(Unit, r)
    got : Socket & Result<&1, &1, U32 & String, String> <- TCP.recv(s, 1048576)
    Ctx.after_recv(got)

# connect to host:port, POST req, read the response
def Ctx.fetch(+host: String, port: U32, req: String) -> IO(String):
  do IO<String>:
    c : Socket <- IO.try(Socket, TCP.connect(host, port))
    sent : Socket & Result<&1, &1, U32 & String, Unit> <- TCP.send(c, req)
    Ctx.after_send(sent)

# the response body: everything after the first blank line (\r\n\r\n)
def Ctx.body_after(m: Maybe<&2, String>) -> String:
  match m:
    case None{}:
      ""
    case Some{rest}:
      rest

# tail after the first "\r\n\r\n" (self-recursive, fuel-bounded)
def Ctx.find_body(fuel: Nat, +resp: String) -> Maybe<&2, String>:
  match fuel:
    case 0n:
      None{}
    case 1n+p:
      Bool.pick(Maybe<&2, String>, String.starts_with(resp, "\r\n\r\n"),
        Some{String.drop(resp, 4n)},
        Ctx.find_body(p, String.drop(resp, 1n)))

def Ctx.http_body(+resp: String) -> String:
  Ctx.body_after(Ctx.find_body(String.length(resp), resp))

# ===========================================================================
# LLM-CLI transport (chosen over TCP loopback): build a prompt from the doc's
# SOURCE-VERIFIED evidence, hand it to an external CLI (via Exec.run, in main),
# then keep only candidate lines that cite a verified evidence id. Loose
# contract: model replies with one JSON object per line
# {"kind":..,"evidenceId":..,"rationale":..}; anything else is dropped.
# Correctness rests on the evidence check, not on schema conformance.
# ===========================================================================

# the prepared request: the prompt, the citable verified ids, and the verified
# evidence objects (kept so accepted candidates can cite a real Evidence).
type CtxReq is Data:
  CtxReq{prompt: String, ids: List<&2, String>, evs: List<&2, T.Evidence>}

def CtxReq.prompt(r: CtxReq) -> String:
  match r:
    case CtxReq{prompt, ids, evs}:
      prompt

def CtxReq.ids(r: CtxReq) -> List<&2, String>:
  match r:
    case CtxReq{prompt, ids, evs}:
      ids

def CtxReq.evs(r: CtxReq) -> List<&2, T.Evidence>:
  match r:
    case CtxReq{prompt, ids, evs}:
      evs

def Ctx.ev_id(e: T.Evidence) -> String:
  match e:
    case T.Evidence{id, documentSha256, sourcePath, span, rawExcerpt, displayText, anchor, kind}:
      id

def Ctx.blk_ev(b: T.Block) -> List<&2, T.Evidence>:
  match b:
    case T.Block{blockId, kind, tagName, sectionAnchor, authoredId, headingLevel, ancestorSections, text, mapped, evidence, links, tex}:
      evidence

def Ctx.all_ev(blocks: List<&2, T.Block>) -> List<&2, T.Evidence>:
  match blocks:
    case Nil{}:
      Nil{}
    case Con{b, t}:
      List.append(&2, T.Evidence, Ctx.blk_ev(b), Ctx.all_ev(t))

def Ctx.ev_ids(evs: List<&2, T.Evidence>) -> List<&2, String>:
  match evs:
    case Nil{}:
      Nil{}
    case Con{e, t}:
      Ctx.ev_id(e) <> Ctx.ev_ids(t)

def Ctx.cite_line(+e: T.Evidence) -> String:
  "  " ++ Ctx.ev_id(e) ++ ": " ++ C.Evidence.raw(e) ++ "\n"

def Ctx.cite_lines(evs: List<&2, T.Evidence>) -> String:
  match evs:
    case Nil{}:
      ""
    case Con{e, t}:
      Ctx.cite_line(e) ++ Ctx.cite_lines(t)

# the prompt embeds the reader profile (assumed / not-assumed knowledge,
# objective) so candidates are judged for THIS reader.
def Ctx.prompt(+reader: String, evs: List<&2, T.Evidence>, +content: String) -> String:
  "You judge whether the writing serves this reader.\n--- reader profile ---\n" ++ reader ++
  "\n--- task ---\nReply ONLY with one JSON object per line: {\"kind\":\"...\",\"evidenceId\":\"...\",\"rationale\":\"...\"}.\nCite only these evidence ids:\n" ++
  Ctx.cite_lines(evs) ++ "\n--- document ---\n" ++ content

# prepare the request from the raw Markdown content: parse, gather evidence,
# re-verify it against the source, and expose the verified citable ids + objects.
# The parser builds each Evidence from the block's own exact source substring
# (Evidence.of), so it is correct by construction — no need to re-slice the whole
# source per evidence here (that was O(n^2) and overflowed). Response candidates
# are still checked against this evidence-id set in Ctx.candidates/Ctx.filter.
def Ctx.prepare(+reader: String, +content: String) -> CtxReq:
  +sha = S.Sha256.hex(content)
  +evs = Ctx.all_ev(Md.Md.parse(content, sha))
  CtxReq{Ctx.prompt(reader, evs, content), Ctx.ev_ids(evs), evs}

# --- response filtering: keep candidate lines citing a verified id ----------
def Ctx.keep_line(inSet: Bool, line: String, rest: List<&2, String>) -> List<&2, String>:
  match inSet:
    case True{}:
      line <> rest
    case False{}:
      rest

def Ctx.filter(+valid: List<&2, String>, lines: List<&2, String>) -> List<&2, String>:
  match lines:
    case Nil{}:
      Nil{}
    case Con{+l, t}:
      Ctx.keep_line(
        Bool.and(Bool.not(String.is_empty(l)), List.contains(~String, ~String.eq, valid, Jr.Jr.field(l, "evidenceId"))),
        l, Ctx.filter(valid, t))

def Ctx.join_lines(lines: List<&2, String>) -> String:
  match lines:
    case Nil{}:
      ""
    case Con{l, t}:
      l ++ "\n" ++ Ctx.join_lines(t)

def Ctx.accept_show(empty: Bool, kept: List<&2, String>) -> String:
  match empty:
    case True{}:
      "(no accepted candidates)"
    case False{}:
      Ctx.join_lines(kept)

# accepted candidates from a raw provider response, given the verified ids
def Ctx.accept(+valid: List<&2, String>, +response: String) -> String:
  +kept = Ctx.filter(valid, String.lines(response))
  Ctx.accept_show(Nat.is_eq(List.length(&2, String, kept), 0n), kept)

# ===========================================================================
# LLM candidates -> findings (merged into the artifacts). Each accepted line
# (citing a source-verified evidence id) becomes an advisory contextual/model
# candidate finding. Model-origin candidates are never gate-eligible.
# ===========================================================================
def Ctx.fev_pick(hit: Bool, e: T.Evidence, rec: Maybe<&2, T.Evidence>) -> Maybe<&2, T.Evidence>:
  match hit:
    case True{}:
      Some{e}
    case False{}:
      rec

def Ctx.find_ev(evs: List<&2, T.Evidence>, +id: String) -> Maybe<&2, T.Evidence>:
  match evs:
    case Nil{}:
      None{}
    case Con{+e, t}:
      Ctx.fev_pick(String.eq(Ctx.ev_id(e), id), e, Ctx.find_ev(t, id))

def Ctx.mk_candidate(ev: T.Evidence, +kindstr: String, +rationale: String, +eid: String) -> T.Finding:
  +fp = S.Sha256.hex("contextual#" ++ kindstr ++ "#" ++ eid ++ "#" ++ rationale)
  T.Finding{
    "contextual:" ++ String.take(fp, 20n),
    T.RuleRef{"contextual.model", "1"},
    T.Contextual{}, T.Model{}, T.Candidate{},
    "Contextual candidate",
    kindstr ++ ": " ++ rationale,
    [ev], fp, None{},
  }

def Ctx.cand_join(m: Maybe<&2, T.Evidence>, +l: String, rest: List<&2, T.Finding>) -> List<&2, T.Finding>:
  match m:
    case None{}:
      rest
    case Some{ev}:
      Ctx.mk_candidate(ev, Jr.Jr.field(l, "kind"), Jr.Jr.field(l, "rationale"), Jr.Jr.field(l, "evidenceId")) <> rest

def Ctx.candidates_go(+evs: List<&2, T.Evidence>, lines: List<&2, String>) -> List<&2, T.Finding>:
  match lines:
    case Nil{}:
      Nil{}
    case Con{+l, t}:
      Ctx.cand_join(Ctx.find_ev(evs, Jr.Jr.field(l, "evidenceId")), l, Ctx.candidates_go(evs, t))

# accepted candidate findings from a raw provider response + verified evidence
def Ctx.candidates(+evs: List<&2, T.Evidence>, +response: String) -> List<&2, T.Finding>:
  Ctx.candidates_go(evs, String.lines(response))
