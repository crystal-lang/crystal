require "./repl"

# Some constants to be used at compile-time to debug
# the interpreter itself.
#
# These are not used at runtime because they significantly
# slow down the interpreter.
module Crystal::Repl::Debug
  TRACE     = false
  DECOMPILE = false
end
