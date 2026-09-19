# UTF-8 byte-span and source-hash smoke check. Run: bend prosemap/utf8_test.bend
import Base
import ./types.bend as T
import ./utf8.bend as Utf8
import ./contracts.bend as C
import ./sha256.bend as S
import ./markdown.bend as Md

def span_show(ev: T.Evidence) -> String:
  match ev:
    case T.Evidence{id, documentSha256, sourcePath, span, rawExcerpt, displayText, anchor, kind}:
      match span:
        case T.Span{start, end}:
          Nat.show(U32.to_nat(start)) ++ "-" ++ Nat.show(U32.to_nat(end)) ++ "=" ++ rawExcerpt

def block_spans(bs: List<&2, T.Block>) -> String:
  match bs:
    case Nil{}:
      ""
    case Con{b, rest}:
      match b:
        case T.Block{blockId, kind, tagName, sectionAnchor, authoredId, headingLevel, ancestorSections, text, mapped, evidence, links, tex}:
          match evidence:
            case Nil{}:
              "missing evidence\n" ++ block_spans(rest)
            case Con{ev, more}:
              span_show(ev) ++ "\n" ++ block_spans(rest)

def main() -> IO(Unit):
  +src = {"# é\n\nπ\n" : String}
  +term_src = {"π before <dfn>Functor</dfn> after.\n" : String}
  do IO<Unit>:
    # a (1) + € (3) + 𝄞 (4) UTF-8 bytes
    IO.print("byte-length = " ++ Nat.show(U32.to_nat(Utf8.Utf8.byte_length("a€𝄞"))))
    IO.print("slice = " ++ C.Str.slice("aéπ", 1, 5))
    # "é" -> SHA-256(c3 a9)
    IO.print("sha-é = " ++ S.Sha256.hex("é"))
    # "a€𝄞" -> SHA-256(61 e2 82 ac f0 9d 84 9e)
    IO.print("sha-mixed = " ++ S.Sha256.hex("a€𝄞"))
    # Heading and paragraph ranges are 0-4 and 6-8, respectively.
    IO.print(block_spans(Md.Md.parse(src, S.Sha256.hex(src))))
    # The extracted inline definition starts after the two-byte π prefix; its
    # evidence range still slices exactly to the term text.
    IO.print("term spans:")
    IO.print(block_spans(Md.Md.parse(term_src, S.Sha256.hex(term_src))))
