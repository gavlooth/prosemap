# Contextual stage — evidence re-verification core (Bend port of the security-
# critical part of src/contextual.ts: validateRequestEvidence, contextual.ts:331).
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
