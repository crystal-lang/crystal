
# General Intrinsics
#
# See http://llvm.org/docs/LangRef.html#general-intrinsics
module Intrinsics::General

  lib Lib

    # http://llvm.org/docs/LangRef.html#llvm-debugtrap-intrinsic
    fun debugtrap = "llvm.debugtrap"

  end

  @[AlwaysInline]
  def debugtrap
    Lib.debugtrap
  end

end
