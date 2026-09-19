# SHA-256 in pure Bend — used for evidence fingerprints and record ids
# Deterministic bit arithmetic over U32,
# a good fit for Bend and independent of any host crypto.
#
# Input Strings are encoded as UTF-8 octets before padding. This keeps source
# hashes stable across runtimes and aligned with byte-addressed evidence spans.
#
# Loops use a `Nat` fuel argument because Bend's termination checker only
# accepts recursion on structurally-smaller pattern-matched values, never on a
# computed one like `List.drop(xs, 16)`.
import Base
import ./utf8.bend as Utf8

# 8-word hash / working state
type St8 is Data:
  St8{a: U32, b: U32, c: U32, d: U32, e: U32, f: U32, g: U32, h: U32}

# --- constants -------------------------------------------------------------
def sha.h0() -> St8:
  St8{1779033703, 3144134277, 1013904242, 2773480762,
      1359893119, 2600822924, 528734635, 1541459225}

def sha.k() -> List<&2, U32>:
  [ 1116352408, 1899447441, 3049323471, 3921009573, 961987163, 1508970993,
    2453635748, 2870763221, 3624381080, 310598401, 607225278, 1426881987,
    1925078388, 2162078206, 2614888103, 3248222580, 3835390401, 4022224774,
    264347078, 604807628, 770255983, 1249150122, 1555081692, 1996064986,
    2554220882, 2821834349, 2952996808, 3210313671, 3336571891, 3584528711,
    113926993, 338241895, 666307205, 773529912, 1294757372, 1396182291,
    1695183700, 1986661051, 2177026350, 2456956037, 2730485921, 2820302411,
    3259730800, 3345764771, 3516065817, 3600352804, 4094571909, 275423344,
    430227734, 506948616, 659060556, 883997877, 958139571, 1322822218,
    1537002063, 1747873779, 1955562222, 2024104815, 2227730452, 2361852424,
    2428436474, 2756734187, 3204031479, 3329325298 ]

# pair accessors (destructuring a *parameter* is allowed; a computed value is not)
def sha.pfst(p: Nat & Nat) -> Nat:
  (q, r) = p
  q

def sha.psnd(p: Nat & Nat) -> Nat:
  (q, r) = p
  r

def sha.nmod(a: Nat, b: Nat) -> Nat:
  sha.psnd(Nat.divmod(a, b))

# --- bit helpers -----------------------------------------------------------
def sha.rotr(+x: U32, +n: Nat) -> U32:
  U32.or(U32.shrn(x, n), U32.shln(x, Nat.sub(32n, n)))

def sha.ss0(+x: U32) -> U32:
  U32.xor(U32.xor(sha.rotr(x, 7n), sha.rotr(x, 18n)), U32.shrn(x, 3n))

def sha.ss1(+x: U32) -> U32:
  U32.xor(U32.xor(sha.rotr(x, 17n), sha.rotr(x, 19n)), U32.shrn(x, 10n))

def sha.bS0(+x: U32) -> U32:
  U32.xor(U32.xor(sha.rotr(x, 2n), sha.rotr(x, 13n)), sha.rotr(x, 22n))

def sha.bS1(+x: U32) -> U32:
  U32.xor(U32.xor(sha.rotr(x, 6n), sha.rotr(x, 11n)), sha.rotr(x, 25n))

def sha.ch(+e: U32, f: U32, g: U32) -> U32:
  U32.xor(U32.and(e, f), U32.and(U32.not(e), g))

def sha.maj(+a: U32, +b: U32, +c: U32) -> U32:
  U32.xor(U32.xor(U32.and(a, b), U32.and(a, c)), U32.and(b, c))

# --- message prep ----------------------------------------------------------
# String -> UTF-8 byte values.
def sha.bytes(s: String) -> List<&2, U32>:
  Utf8.Utf8.bytes(s)

def sha.zeros(n: Nat) -> List<&2, U32>:
  match n:
    case 0n:
      Nil{}
    case 1n+p:
      {0 : U32} <> sha.zeros(p)

# little-endian bytes of a Nat (LSB first), `count` of them.
# `count` first so the termination checker sees the shrinking arg before `n`.
def sha.le_bytes(count: Nat, +n: Nat) -> List<&2, U32>:
  match count:
    case 0n:
      Nil{}
    case 1n+p:
      U32.from_nat(sha.nmod(n, 256n)) <> sha.le_bytes(p, Nat.div(n, 256n))

# 8-byte big-endian length field
def sha.be64(bits: Nat) -> List<&2, U32>:
  List.reverse(&2, U32, sha.le_bytes(8n, bits))

# pad message bytes to a multiple of 64: append 0x80, zeros, then bit length
# tail-recursive length / append over U32 lists (Base's are non-tail and
# overflow on multi-MB messages).
def sha.len_go(xs: List<&2, U32>, acc: Nat) -> Nat:
  match xs:
    case Nil{}:
      acc
    case Con{h, t}:
      sha.len_go(t, 1n+acc)

def sha.len(xs: List<&2, U32>) -> Nat:
  sha.len_go(xs, 0n)

def sha.rcat(xs: List<&2, U32>, acc: List<&2, U32>) -> List<&2, U32>:
  match xs:
    case Nil{}:
      acc
    case Con{h, t}:
      sha.rcat(t, h <> acc)

def sha.append(xs: List<&2, U32>, ys: List<&2, U32>) -> List<&2, U32>:
  sha.rcat(List.reverse(&2, U32, xs), ys)

def sha.pad(+msg: List<&2, U32>) -> List<&2, U32>:
  +len = sha.len(msg)
  +t   = sha.nmod(Nat.add(len, 1n), 64n)
  +k   = sha.nmod(Nat.sub(Nat.add(64n, 56n), t), 64n)
  +bits = Nat.mul(len, 8n)
  sha.append(msg,
    List.append(&2, U32, {[128] : List<&2, U32>},
      List.append(&2, U32, sha.zeros(k), sha.be64(bits))))

# --- big-endian 4-byte grouping -------------------------------------------
# TAIL-RECURSIVE: pack 4 bytes/word, accumulate reversed, reverse at the end.
# (A non-tail version overflows the stack on multi-MB inputs.)
def sha.words_go(bs: List<&2, U32>, acc: List<&2, U32>) -> List<&2, U32>:
  match bs:
    case Nil{}:
      List.reverse(&2, U32, acc)
    case Con{b0, r0}:
      match r0:
        case Nil{}:
          List.reverse(&2, U32, acc)
        case Con{b1, r1}:
          match r1:
            case Nil{}:
              List.reverse(&2, U32, acc)
            case Con{b2, r2}:
              match r2:
                case Nil{}:
                  List.reverse(&2, U32, acc)
                case Con{b3, r3}:
                  +w = U32.or(
                    U32.or(U32.shln(b0, 24n), U32.shln(b1, 16n)),
                    U32.or(U32.shln(b2, 8n), b3))
                  sha.words_go(r3, w <> acc)

def sha.words(bs: List<&2, U32>) -> List<&2, U32>:
  sha.words_go(bs, Nil{})

# --- schedule --------------------------------------------------------------
def sha.unwrap(m: Maybe<&2, U32>) -> U32:
  match m:
    case Some{v}:
      v
    case None{}:
      {0 : U32}

def sha.get(xs: List<&2, U32>, i: Nat) -> U32:
  sha.unwrap(List.get(&2, U32, xs, i))

# extend a reversed schedule (most-recent-first) by `fuel` words.
# `fuel` first so the shrinking arg precedes the mutated `rev`.
def sha.extend(fuel: Nat, +rev: List<&2, U32>) -> List<&2, U32>:
  match fuel:
    case 0n:
      rev
    case 1n+p:
      +w2  = sha.get(rev, 1n)
      +w7  = sha.get(rev, 6n)
      +w15 = sha.get(rev, 14n)
      +w16 = sha.get(rev, 15n)
      +nw  = U32.add(U32.add(w16, sha.ss0(w15)), U32.add(w7, sha.ss1(w2)))
      sha.extend(p, nw <> rev)

# w[0..63] in order from the 16 block words
def sha.sched(+first16: List<&2, U32>) -> List<&2, U32>:
  List.reverse(&2, U32, sha.extend(48n, List.reverse(&2, U32, first16)))

# --- compression -----------------------------------------------------------
def sha.round(wi: U32, ki: U32, st: St8) -> St8:
  match st:
    case St8{+a, +b, +c, d, +e, +f, +g, h}:
      +t1 = U32.add(U32.add(U32.add(U32.add(h, sha.bS1(e)), sha.ch(e, f, g)), ki), wi)
      t2  = U32.add(sha.bS0(a), sha.maj(a, b, c))
      St8{U32.add(t1, t2), a, b, c, U32.add(d, t1), e, f, g}

def sha.rounds(fuel: Nat, +i: Nat, +w: List<&2, U32>, +k: List<&2, U32>, st: St8) -> St8:
  match fuel:
    case 0n:
      st
    case 1n+p:
      +st2 = sha.round(sha.get(w, i), sha.get(k, i), st)
      sha.rounds(p, Nat.add(i, 1n), w, k, st2)

def sha.add8(x: St8, y: St8) -> St8:
  match x:
    case St8{xa, xb, xc, xd, xe, xf, xg, xh}:
      match y:
        case St8{ya, yb, yc, yd, ye, yf, yg, yh}:
          St8{U32.add(xa, ya), U32.add(xb, yb), U32.add(xc, yc), U32.add(xd, yd),
              U32.add(xe, ye), U32.add(xf, yf), U32.add(xg, yg), U32.add(xh, yh)}

def sha.compress(+blk: List<&2, U32>, +h0: St8) -> St8:
  +st = sha.rounds(64n, 0n, sha.sched(blk), sha.k(), h0)
  sha.add8(h0, st)

# process 16-word blocks; fuel = number of blocks
def sha.blocks(fuel: Nat, +ws: List<&2, U32>, h: St8) -> St8:
  match fuel:
    case 0n:
      h
    case 1n+p:
      sha.blocks(p, List.drop(&2, U32, ws, 16n), sha.compress(List.take(&2, U32, ws, 16n), h))

# --- hex output ------------------------------------------------------------
def sha.nib(+d: U32) -> Char:
  Bool.pick(Char, U32.is_lt(d, 10), Chr{U32.add(48, d)}, Chr{U32.add(87, d)})

def sha.hex32.go(fuel: Nat, +x: U32, +shift: Nat) -> String:
  match fuel:
    case 0n:
      SNil{}
    case 1n+p:
      SCon{sha.nib(U32.and(U32.shrn(x, shift), 15)), sha.hex32.go(p, x, Nat.sub(shift, 4n))}

def sha.hex32(+x: U32) -> String:
  sha.hex32.go(8n, x, 28n)

def sha.hex(h: St8) -> String:
  match h:
    case St8{a, b, c, d, e, f, g, h2}:
      sha.hex32(a) ++ sha.hex32(b) ++ sha.hex32(c) ++ sha.hex32(d) ++
      sha.hex32(e) ++ sha.hex32(f) ++ sha.hex32(g) ++ sha.hex32(h2)

# --- entry -----------------------------------------------------------------
def Sha256.hex(s: String) -> String:
  +ws = sha.words(sha.pad(sha.bytes(s)))
  +nb = Nat.div(sha.len(ws), 16n)
  sha.hex(sha.blocks(nb, ws, sha.h0()))
