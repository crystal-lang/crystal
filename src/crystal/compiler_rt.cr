# Low Level Runtime Functions for LLVM.
# The function definitions and explinations can be found here.
# https://gcc.gnu.org/onlinedocs/gccint/Libgcc.html#Libgcc

{% skip_file if flag?(:skip_crystal_compiler_rt) %}

# Structs for implementing 128bit
require "./compiler_rt/info.cr"

# Overflow operations
require "./compiler_rt/udivmodti4.cr"
require "./compiler_rt/muloti4.cr"

# Signed Multiplication
require "./compiler_rt/mulodi4.cr"
require "./compiler_rt/multi3.cr"

# Unsigned Multiplication
require "./compiler_rt/umuldi3.cr"

# Signed Division
require "./compiler_rt/modti3.cr"

# Unsigned Division
require "./compiler_rt/umodti3.cr"
