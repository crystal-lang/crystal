require "./intrinsics/*"

# http://llvm.org/docs/LangRef.html#intrinsic-functions
module Intrinsics
  extend Intrinsics::General
  extend Intrinsics::StdCLib
  extend Intrinsics::BitManipulation
  extend Intrinsics::CodeGenerator
end

macro debugger
  Intrinsics.debugtrap
end
