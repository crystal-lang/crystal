module LLVM
  enum AtomicOrdering
    NotAtomic              = 0
    Unordered              = 1
    Monotonic              = 2
    Acquire                = 4
    Release                = 5
    AcquireRelease         = 6
    SequentiallyConsistent = 7
  end

  enum AtomicRMWBinOp
    Xchg
    Add
    Sub
    And
    Nand
    Or
    Xor
    Max
    Min
    Umax
    Umin
    Fadd
    Fsub
  end
end
