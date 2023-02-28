require "c/signal"

enum Signal : Int32
  INT   = LibC::SIGINT
  ILL   = LibC::SIGILL
  FPE   = LibC::SIGFPE
  SEGV  = LibC::SIGSEGV
  TERM  = LibC::SIGTERM
  BREAK = LibC::SIGBREAK
  ABRT  = LibC::SIGABRT

  def trap(&handler : Signal ->) : Nil
    raise NotImplementedError.new("Signal#trap")
  end

  def reset : Nil
    raise NotImplementedError.new("Signal#reset")
  end

  def ignore : Nil
    raise NotImplementedError.new("Signal#ignore")
  end
end
