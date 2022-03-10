require "./repl"

# This class keeps track of all the constants the interpreter will
# need access to, and allows you to declare and access their position
# in memory, and whether they have an initializer or not.
#
# Trivial constants such as `A = 1` (int literals, bools, etc.) are not stored
# in memory. Instead, their value is inlined in the bytecode when they are used.
#
# The interpreter holds a memory region for constants, for example like this:
#
# [_,_,_,_,_,_,_,_,_,......]
#  ^-----^ ^-------^
#   A          B
#
# In this memory, for each constant there are 8 bytes that indicate
# whether the constant was initialized or not. After these 8 bytes comes the
# constant data, aligned to 8 bytes boundaries so that the GC
# can properly track pointers (that's why we also use 8 bytes for the `initialized` bit.)
#
# This class and `ClassVars` are very similar.
class Crystal::Repl::Constants
  # The offset to use after the index of a constant to get access to its data.
  OFFSET_FROM_INITIALIZED = 8

  # Each value tracked per constant: its index in memory and
  record Value, index : Int32, compiled_def : CompiledDef

  def initialize(@context : Context)
    @data = {} of Const => Value
    @bytesize = 0
  end

  # Returns the total amount of bytes needed to store all known constants so far.
  def bytesize
    @bytesize
  end

  # Declares a new constant. Returns the index in memory where it will be stored.
  # `compiled_def` is the constant initializer compiled to bytecode.
  # Note that at that index the `initializer` "bit" (8 bytes) should be stored,
  # and only after `OFFSET_FROM_INITIALIZER` the data should be stored.
  def declare(const : Const, compiled_def : CompiledDef) : Int32
    type = const.value.type

    index = @bytesize
    @data[const] = Value.new(index, compiled_def)

    @bytesize += OFFSET_FROM_INITIALIZED
    @bytesize += @context.aligned_sizeof_type(type)

    index
  end

  # Fetches a constant, if it's there.
  def fetch?(const : Const) : Value?
    @data[const]?
  end
end
