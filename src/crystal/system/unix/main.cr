require "c/stdlib"

# Prefer explicit exit over returning the status, so we are free to resume the
# main thread's fiber on any thread, without occuring a weird behavior where
# another thread returns from main when the caller might expect the main thread
# to be the one returning.

fun main(argc : Int32, argv : UInt8**) : Int32
  status = Crystal.main(argc, argv)
  LibC.exit(status)
end
