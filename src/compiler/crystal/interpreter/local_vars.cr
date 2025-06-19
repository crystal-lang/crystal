require "./repl"

# Records the position in the stack for local variables.
#
# This is almost a Hash where the keys are names and the values
# are indexes, but it's a bit more complex because blocks create
# separate scopes where name clashes can happen.
#
# So if we have a code like this:
#
# ```
# a = 0
# b = 1
# foo do |a|
#   b = a
# end
# c = 2
# ```
#
# We actually want to store:
# - a in the first position (0-8 bytes)
# - b in the second position (8-16 bytes)
# - the a in the block is a different var, so we put it in (16-24)
# - now that the block is over, that new a (or any variable that only
#   exists inside the block) are no longer reachable so:
# - c can also be put in (16-24)
class Crystal::Repl::LocalVars
  record Key, name : String, block_level : Int32

  getter block_level : Int32

  def initialize(@context : Context)
    @types = {} of Key => Type
    @name_to_index = {} of Key => Int32
    @bytesize = 0
    @max_bytesize = 0
    @block_level = 0
    @bytesize_per_block_level = [] of Int32
  end

  def initialize(local_vars : LocalVars)
    @context = local_vars.@context
    @types = local_vars.@types.dup
    @name_to_index = local_vars.@name_to_index.dup
    @bytesize = local_vars.@bytesize
    @max_bytesize = local_vars.@max_bytesize
    @block_level = local_vars.@block_level
    @bytesize_per_block_level = local_vars.@bytesize_per_block_level
  end

  def push_block : Nil
    @bytesize_per_block_level << @bytesize
    @block_level += 1
  end

  def pop_block : Nil
    # Undefine variables that belong to the current block
    @types.reject! { |key, type| key.block_level == @block_level }
    @name_to_index.reject! { |key, index| key.block_level == @block_level }

    @block_level -= 1
    @bytesize = @bytesize_per_block_level.pop
  end

  def current_bytesize
    @bytesize
  end

  def max_bytesize
    @max_bytesize
  end

  def names_at_block_level_zero
    @name_to_index.keys.select { |key| key.block_level == 0 }.map(&.name)
  end

  def names
    @name_to_index.keys.map(&.name)
  end

  def declare(name : String, type : Type) : Int32?
    is_self = name == "self"
    # TODO: should this use `Type#passed_as_self?` instead?
    return if is_self && (type.is_a?(Program) || type.is_a?(FileModule))

    key = Key.new(name, @block_level)

    index = @bytesize
    @name_to_index[key] = index

    @types[key] = type

    if is_self && type.passed_by_value?
      @bytesize += sizeof(Pointer(UInt8))
    else
      @bytesize += @context.aligned_sizeof_type(type)
    end

    @max_bytesize = @bytesize if @bytesize > @max_bytesize

    index
  end

  def name_to_index(name : String, block_level : Int32) : Int32
    @name_to_index[Key.new(name, block_level)]
  end

  def name_to_index?(name : String, block_level : Int32) : Int32?
    @name_to_index[Key.new(name, block_level)]?
  end

  def type(name : String, block_level : Int32) : Type
    @types[Key.new(name, block_level)]
  end

  def type?(name : String, block_level : Int32) : Type?
    @types[Key.new(name, block_level)]?
  end

  def to_s(io : IO) : Nil
    return if @max_bytesize == 0

    io << "local table (bytesize: " << @max_bytesize << ")\n"
    @name_to_index.each do |key, index|
      io << "\t" unless index == 0
      io << key.name << '@' << index
      io << 'B' << key.block_level if key.block_level > 0
      io << ':' << @types[key]
    end
  end

  def dup
    LocalVars.new(self)
  end
end
