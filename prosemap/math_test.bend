# Markdown math and TeX command-tokenizer smoke test.
# Run: bend bend/prosemap/math_test.bend
import Base
import ./types.bend as T
import ./markdown.bend as Md
import ./mechanical.bend as M

def show_tex(ts: List<&2, T.Tex>) -> String:
  match ts:
    case Nil{}:
      ""
    case Con{tx, t}:
      match tx:
        case T.Tex{raw, display, recognized, evidenceId}:
          "  " ++ raw ++ " display=" ++ Bool.show(display) ++ "\n" ++ show_tex(t)

def show_findings(fs: List<&2, T.Finding>) -> String:
  match fs:
    case Nil{}:
      ""
    case Con{f, t}:
      match f:
        case T.Finding{recordId, rule, dimension, origin, kind, title, message, evidence, evidenceFingerprint, severity}:
          title ++ ": " ++ message ++ "\n" ++ show_findings(t)

def show_blocks(bs: List<&2, T.Block>) -> String:
  match bs:
    case Nil{}:
      ""
    case Con{b, t}:
      match b:
        case T.Block{blockId, kind, tagName, sectionAnchor, authoredId, headingLevel, ancestorSections, text, mapped, evidence, links, tex}:
          "block " ++ tagName ++ ":\n" ++ show_tex(tex) ++ show_blocks(t)

def main() -> IO(Unit):
  +src = {"# Math\n\nInline $\\alpha + \\Alpha$ and display:\n\n$$\\alpha + \\Alpha$$\n\n```math\n\\Beta\n```\n" : String}
  +blocks = Md.Md.parse(src, "mathsha")
  +findings = M.Mech.analyze(4, blocks)
  do IO<Unit>:
    IO.print(show_blocks(blocks))
    IO.print(show_findings(findings))
