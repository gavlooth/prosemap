# SHA-256 vector check. Run: bend prosemap/sha_test.bend
import Base
import ./sha256.bend as S

def main() -> IO(Unit):
  do IO<Unit>:
    # "" -> e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855
    IO.print("empty = " ++ S.Sha256.hex(""))
    # "abc" -> ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad
    IO.print("abc   = " ++ S.Sha256.hex("abc"))
    # 56-byte message crosses into a second block after padding
    IO.print("a*56  = " ++ S.Sha256.hex("aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"))
