# Exec shim smoke test. Run: bend prosemap/exec_test.bend
import Base
import ./exec.bend as E

def main() -> IO(Unit):
  do IO<Unit>:
    out : String <- IO.try(String, E.Exec.run("printf 'hello %s' world", "", 5000, 1048576))
    IO.print("stdout=[" ++ out ++ "]")
    # feed stdin through `cat`
    piped : String <- IO.try(String, E.Exec.run("cat", "piped-in-data", 5000, 1048576))
    IO.print("piped=[" ++ piped ++ "]")
