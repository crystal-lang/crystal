
# Code Generator Intrinsics
#
# See http://llvm.org/docs/LangRef.html#code-generator-intrinsics
module Intrinsics::CodeGenerator

  lib Lib

    # http://llvm.org/docs/LangRef.html#llvm-readcyclecounter-intrinsic
    fun readcyclecounter = "llvm.readcyclecounter" : UInt64

  end

  # Returns low latency, high accuracy clock count on CPUs that support it.
  #
  # Please note it overflows quickly (9 seconds on Alpha CPU) so it should be used for small timings only.
  #
  # For more information see http://llvm.org/docs/LangRef.html#llvm-readcyclecounter-intrinsic.
  @[AlwaysInline]
  def read_cycle_counter : UInt64
    Lib.readcyclecounter
  end

end
