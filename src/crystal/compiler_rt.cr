{% skip_file if flag?(:skip_crystal_compiler_rt) %}

require "./compiler_rt/fixint.cr"
require "./compiler_rt/float.cr"
require "./compiler_rt/mul.cr"
require "./compiler_rt/divmod128.cr"
