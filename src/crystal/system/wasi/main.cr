require "./lib_wasi"

lib LibC
  fun __wasm_call_ctors
  fun __wasm_call_dtors
  fun __original_main : Int32
end

fun _start
  LibC.__wasm_call_ctors
  status = LibC.__original_main
  LibC.__wasm_call_dtors
  LibWasi.proc_exit(status) if status != 0
end
