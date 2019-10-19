# Low Level Runtime Functions for LLVM.
# The function definitions and explinations can be found here.
# https://gcc.gnu.org/onlinedocs/gccint/Libgcc.html#Libgcc

{% skip_file if flag?(:skip_crystal_compiler_rt) %}

require "./compiler_rt/mulodi4.cr"
