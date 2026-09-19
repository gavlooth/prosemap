# Markdown parse -> mechanical analysis. Run: bend prosemap/md_test.bend
import Base
import ./types.bend as T
import ./markdown.bend as Md
import ./mechanical.bend as M

def show_blocks(bs: List<&2, T.Block>) -> String:
  match bs:
    case Nil{}:
      ""
    case Con{b, t}:
      match b:
        case T.Block{blockId, kind, tagName, sectionAnchor, authoredId, headingLevel, ancestorSections, text, mapped, evidence, links, tex}:
          "  [" ++ tagName ++ "] " ++ text ++ "\n" ++ show_blocks(t)

def show_findings(fs: List<&2, T.Finding>) -> String:
  match fs:
    case Nil{}:
      ""
    case Con{f, t}:
      match f:
        case T.Finding{recordId, rule, dimension, origin, kind, title, message, evidence, evidenceFingerprint, severity}:
          "  - " ++ title ++ "\n" ++ show_findings(t)

def show_auth(m: Maybe<&2, String>) -> String:
  match m:
    case None{}:
      "-"
    case Some{s}:
      s

# tag, resolved section anchor, authored id, text — the anchor surface
def show_anchors(bs: List<&2, T.Block>) -> String:
  match bs:
    case Nil{}:
      ""
    case Con{b, t}:
      match b:
        case T.Block{blockId, kind, tagName, sectionAnchor, authoredId, headingLevel, ancestorSections, text, mapped, evidence, links, tex}:
          "  [" ++ tagName ++ "] sec=" ++ sectionAnchor ++ " id=" ++ show_auth(authoredId) ++ " " ++ text ++ "\n" ++ show_anchors(t)

def main() -> IO(Unit):
  +src = {"# Guide\n\nThe quick brown fox jumps over things here.\n\n##### Deep\n\n```\n+---+\n| A | -> | B |\n+---+\n```\n" : String}
  # {#slug}: the authored anchor becomes the heading's section anchor and its
  # authored id (so `#methods` resolves); `{#}` names nothing and keeps the
  # offset anchor.
  +slugs = {"# Intro {#intro}\n\nSee [methods](#methods) and [ghost](#missing).\n\n## Methods {#methods}\n\nBody text goes here.\n\n## Bare {#}\n\nAfter the empty anchor.\n" : String}
  blocks = Md.Md.parse(src, "docsha123")
  +slug_blocks = Md.Md.parse(slugs, "docsha123")
  do IO<Unit>:
    IO.print("blocks:")
    IO.print(show_blocks(blocks))
    IO.print("findings:")
    IO.print(show_findings(M.Mech.analyze(4, Md.Md.parse(src, "docsha123"))))
    IO.print("slug anchors:")
    IO.print(show_anchors(slug_blocks))
    IO.print("slug findings:")
    IO.print(show_findings(M.Mech.analyze(4, slug_blocks)))
