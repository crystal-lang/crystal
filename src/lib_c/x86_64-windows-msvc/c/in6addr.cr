lib LibC
  struct In6Addr
    u : In6AddrU
  end

  union In6AddrU
    byte : Char[16]
    word : WORD[8]
  end
end
