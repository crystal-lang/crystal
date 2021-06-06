require "./repl"

class Crystal::Repl::ClassVars
  record Key, owner : Type, name : String

  OFFSET_FROM_INITIALIZED = 8

  def initialize(@context : Context)
    @types = {} of Key => Type
    @key_to_index = {} of Key => Int32
    @index_to_compiled_def = {} of Int32 => CompiledDef?
    @keys_with_initializer = Set(Key).new
    @bytesize = 0
  end

  def bytesize
    @bytesize
  end

  def declare(owner : Type, name : String, type : Type, compiled_def : CompiledDef?) : Int32
    key = Key.new(owner, name)

    index = @bytesize
    @key_to_index[key] = index
    @index_to_compiled_def[index] = compiled_def

    @types[key] = type

    # We need a bit to know if the class var was already initialized,
    # but we use a byte so that things are aligned.
    # TODO: maybe put this information somewhere else?
    # Though here it's closer to the class var so maybe good for cache locality.
    @bytesize += OFFSET_FROM_INITIALIZED
    @bytesize += @context.aligned_sizeof_type(type)

    index
  end

  def key_to_index?(owner : Type, name : String) : Int32?
    @key_to_index[Key.new(owner, name)]?
  end

  def index_to_compiled_def(index : Int32) : CompiledDef?
    @index_to_compiled_def[index].not_nil!
  end

  def index_to_compiled_def?(index : Int32) : CompiledDef?
    @index_to_compiled_def[index]
  end

  def each_initialized_index
    @index_to_compiled_def.each do |index, compiled_def|
      yield index unless compiled_def
    end
  end
end
