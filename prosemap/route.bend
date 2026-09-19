# Reading route — scope analysis to a chosen set of sections (the route). When a
# route is supplied (PROSEMAP_ROUTE, one section anchor per line), only blocks
# whose sectionAnchor is on the route are analyzed; an empty route means the
# whole document (identity). This is the route-availability analog: content off
# the route is treated as not-on-this-reading-path.
#
# NOTE: section anchors are currently `sec-<byteoffset>` (discoverable from a
# prior run's evidence). Human-named `{#slug}` heading anchors are a follow-up.
import Base
import ./types.bend as T
import ./mechanical.bend as M

def Route.keep(on: Bool, b: T.Block, rest: List<&2, T.Block>) -> List<&2, T.Block>:
  match on:
    case True{}:
      b <> rest
    case False{}:
      rest

def Route.filter(+route: List<&2, String>, blocks: List<&2, T.Block>) -> List<&2, T.Block>:
  match blocks:
    case Nil{}:
      Nil{}
    case Con{+b, t}:
      Route.keep(List.contains(~String, ~String.eq, route, M.Blk.section(b)), b, Route.filter(route, t))

def Route.apply_if(empty: Bool, route: List<&2, String>, blocks: List<&2, T.Block>) -> List<&2, T.Block>:
  match empty:
    case True{}:
      blocks
    case False{}:
      Route.filter(route, blocks)

# apply the route to a block list; an empty route is the identity
def Route.apply(+route: List<&2, String>, blocks: List<&2, T.Block>) -> List<&2, T.Block>:
  Route.apply_if(Nat.is_eq(List.length(&2, String, route), 0n), route, blocks)

# parse a route file: non-empty trimmed lines are section anchors
def Route.keep_line(keep: Bool, l: String, rest: List<&2, String>) -> List<&2, String>:
  match keep:
    case True{}:
      l <> rest
    case False{}:
      rest

def Route.parse_go(lines: List<&2, String>) -> List<&2, String>:
  match lines:
    case Nil{}:
      Nil{}
    case Con{+l, t}:
      Route.keep_line(Bool.not(String.is_empty(l)), l, Route.parse_go(t))

def Route.parse(content: String) -> List<&2, String>:
  Route.parse_go(String.lines(content))
