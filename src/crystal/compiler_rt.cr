# Low Level Runtime Functions for LLVM.
# The function definitions and explinations can be found here.
# https://gcc.gnu.org/onlinedocs/gccint/Libgcc.html#Libgcc

{% skip_file if flag?(:skip_crystal_compiler_rt) %}

require "./compiler_rt/u128_info.cr"
require "./compiler_rt/i128_info.cr"

# Signed Multiplication
require "./compiler_rt/mulodi4.cr"
require "./compiler_rt/multi3.cr"
require "./compiler_rt/muloti4.cr"

# Unsigned Multiplication
require "./compiler_rt/umuldi3.cr"

# Signed Division
require "./compiler_rt/modti3.cr"
require "./compiler_rt/modti3.cr"

# Unsigned Division
require "./compiler_rt/udivmodti4.cr"
require "./compiler_rt/umodti3.cr"

# Functions for arithmetically shifting bits left eg. `a << b`
# fun __ashlti3(a : Int128, b : Int32) : Int128
#   raise "__ashlti3"
# end

# Functions for arithmetically shifting bits right eg. `a >> b`
# fun __ashrti3(a : Int128, b : Int32) : Int128
#   raise "__ashrti3"
# end

# Function for logically shifting left (signed shift)
# fun __lshrti3(a : Int128, b : Int32) : Int128
#   raise "__lshrti3"
# end

# Functions for returning the product eg. `a * b`
# fun __muldi3(a : Int64, b : Int64) : Int64

# Function returning quotient for signed division eg `a / b`
# fun __divdi3(a : Int64, b : Int64) : Int64

# Function returning quotient for unsigned division eg. `a / b`
fun __udivti3(a : UInt128, b : UInt128) : UInt128
  raise "__udivti3"
end

# TODO
# __absvti2
# __addvti3
# __negti2
# __negvti2
# __subvti3

# __ashlti3
# __ashrti3
# __lshrti3

# __cmpti2
# __ucmpti2

# __clrsbti2
# __clzti2
# __ctzti2
# __ffsti2

# __divti3
# __modti3
# __multi3
# __mulvti3
# __udivti3
# __umodti3

# __parityti2
# __popcountti2
