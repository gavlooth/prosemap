# UTF-8 byte helpers for source hashing and byte-addressed evidence spans.
#
# Bend Strings are sequences of Unicode Char values. A Char is encoded here as
# its UTF-8 scalar-value sequence; it is never truncated to its low byte.
import Base

# Number of UTF-8 bytes occupied by one Unicode scalar value.
def Utf8.width2(isTwo: Bool, +code: U32) -> U32:
  match isTwo:
    case True{}:
      2
    case False{}:
      Bool.pick(U32, U32.is_lt(code, 65536), 3, 4)

def Utf8.width1(isAscii: Bool, +code: U32) -> U32:
  match isAscii:
    case True{}:
      1
    case False{}:
      Utf8.width2(U32.is_lt(code, 2048), code)

def Utf8.width(c: Char) -> U32:
  +code = Char.to_u32(c)
  Utf8.width1(U32.is_lt(code, 128), code)

# UTF-8 byte sequence for one Unicode scalar value. Each output U32 is in
# 0..255 and can feed SHA-256 directly.
def Utf8.encode3(isThree: Bool, +code: U32) -> List<&2, U32>:
  match isThree:
    case True{}:
      [ U32.or(U32.shrn(code, 12n), 224),
        U32.or(U32.and(U32.shrn(code, 6n), 63), 128),
        U32.or(U32.and(code, 63), 128) ]
    case False{}:
      [ U32.or(U32.and(U32.shrn(code, 18n), 7), 240),
        U32.or(U32.and(U32.shrn(code, 12n), 63), 128),
        U32.or(U32.and(U32.shrn(code, 6n), 63), 128),
        U32.or(U32.and(code, 63), 128) ]

def Utf8.encode2(isTwo: Bool, +code: U32) -> List<&2, U32>:
  match isTwo:
    case True{}:
      [ U32.or(U32.shrn(code, 6n), 192), U32.or(U32.and(code, 63), 128) ]
    case False{}:
      Utf8.encode3(U32.is_lt(code, 65536), code)

def Utf8.encode1(isAscii: Bool, +code: U32) -> List<&2, U32>:
  match isAscii:
    case True{}:
      [code]
    case False{}:
      Utf8.encode2(U32.is_lt(code, 2048), code)

def Utf8.char_bytes(c: Char) -> List<&2, U32>:
  +code = Char.to_u32(c)
  Utf8.encode1(U32.is_lt(code, 128), code)

# String -> UTF-8 octets. TAIL-RECURSIVE (accumulator, reversed): the recursive
# call is in tail position so Bend compiles it to a loop — constant stack over
# multi-MB inputs. A non-tail version overflows the machine stack.
def Utf8.prepend_bytes(xs: List<&2, U32>, acc: List<&2, U32>) -> List<&2, U32>:
  match xs:
    case Nil{}:
      acc
    case Con{h, t}:
      Utf8.prepend_bytes(t, h <> acc)

def Utf8.bytes_go(s: String, acc: List<&2, U32>) -> List<&2, U32>:
  match s:
    case SNil{}:
      List.reverse(&2, U32, acc)
    case SCon{c, t}:
      Utf8.bytes_go(t, Utf8.prepend_bytes(Utf8.char_bytes(c), acc))

def Utf8.bytes(s: String) -> List<&2, U32>:
  Utf8.bytes_go(s, Nil{})

# UTF-8 byte length (tail-recursive accumulator), used for source spans.
def Utf8.byte_length_go(s: String, acc: U32) -> U32:
  match s:
    case SNil{}:
      acc
    case SCon{c, t}:
      Utf8.byte_length_go(t, U32.add(acc, Utf8.width(c)))

def Utf8.byte_length(s: String) -> U32:
  Utf8.byte_length_go(s, 0)

# Drop an exact UTF-8-byte prefix. A byte range splitting a character cannot be
# represented as a Bend String, so non-boundary starts deterministically yield
# no excerpt rather than shifting the span to a different character.
def Utf8.drop_bytes(s: String, +bytes: U32) -> String:
  match s:
    case SNil{}:
      SNil{}
    case SCon{+c, +t}:
      +width = Utf8.width(c)
      Bool.pick(String, U32.is_eq(bytes, 0), SCon{c, t},
        Bool.pick(String, U32.is_lt(bytes, width), SNil{}, Utf8.drop_bytes(t, U32.sub(bytes, width))))

# Take an exact UTF-8-byte prefix. A final partial character is not included,
# preserving valid UTF-8 String output.
def Utf8.take_bytes(s: String, +bytes: U32) -> String:
  match s:
    case SNil{}:
      SNil{}
    case SCon{+c, +t}:
      +width = Utf8.width(c)
      Bool.pick(String, U32.is_lt(bytes, width), SNil{},
        SCon{c, Utf8.take_bytes(t, U32.sub(bytes, width))})
def Utf8.slice(s: String, +start: U32, end: U32) -> String:
  Utf8.take_bytes(Utf8.drop_bytes(s, start), U32.sub(end, start))
