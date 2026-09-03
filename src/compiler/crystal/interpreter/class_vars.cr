require "./repl"

# This class keeps track of all the class variables the interpreter will
# need access to, and allows you to declare and access their position
# in memory, and whether they have an initializer or not.
#
# The interpreter holds a memory region for class variables, for example like this:
#
# [_,_,_,_,_,_,_,_,_,......]
#  ^-----^ ^-------^
#   A.@@a     B.@@b
#
# In this memory, for each class variables there are 8 bytes that indicate
# whether the class variable was initialized or not. If a class variable
# has no initializer it's considered to be initialized when the program
# starts (see `#each_initialized_index`). After these 8 bytes comes the
# class variable data, aligned to 8 bytes boundaries so that the GC
# can properly track pointers (that's why we also use 8 bytes for the `initialized` bit.)
#
# This class and `Constants` are very similar.
class Crystal::Repl::ClassVars
  # The offset to use after the index of a class variable to get access to its data.
  OFFSET_FROM_INITIALIZED = 8

  # Each class variable is determined by its owner and name
  record Key, owner : Type, name : String

  # For each class variable we record its index and whether it
  # has an initializer, in the form of a CompiledDef (has the initializer
  # already compiled to bytecode)
  record Value, index : Int32, compiled_def : CompiledDef?

  def initialize(@context : Context)
    @data = {} of Key => Value
    @bytesize = 0
  end

  # Returns the total amount of bytes needed to store all known class variables so far.
  def bytesize
    @bytesize
  end

  # Declares a new class variable. Returns the index in memory where it will be stored.
  # `compiled_def` is the class var's initializer compiled to bytecode, if there was
  # an initializer.
  # Note that at that index the `initializer` "bit" (8 bytes) should be stored,
  # and only after `OFFSET_FROM_INITIALIZER` the data should be stored.
  def declare(owner : Type, name : String, type : Type, compiled_def : CompiledDef?) : Int32
    key = Key.new(owner, name)

    index = @bytesize
    @data[key] = Value.new(index, compiled_def)

    @bytesize += OFFSET_FROM_INITIALIZED
    @bytesize += @context.aligned_sizeof_type(type)

    index
  end

  # Fetches a class variable, if it's there.
  def fetch?(owner : Type, name : String) : Value?
    @data[Key.new(owner, name)]?
  end

  # Yields each index of every class variable that is trivially "initialized"
  # when the program starts: those that don't have initializers.
  def each_initialized_index(&)
    @data.each_value do |value|
      yield value.index unless value.compiled_def
    end
  end
end
