require "./repl"

# A value produced by the interpreter, essentially
# a pointer to some data coupled with type information.
# Based on the type we know how to interpreter the data in `pointer`.
struct Crystal::Repl::Value
  getter pointer : Pointer(UInt8)
  getter type : Type

  def initialize(@interpreter : Interpreter, @pointer : Pointer(UInt8), @type : Type)
  end

  # This is a fail-safe way of getting a Crystal value for well-known
  # types like ints, floats, chars, tuples, classes and pointers.
  def value
    type = @type
    case type
    when NilType
      nil
    when BoolType
      @pointer.as(Bool*).value
    when CharType
      @pointer.as(Char*).value
    when IntegerType
      case type.kind
      when .i8?
        @pointer.as(Int8*).value
      when .u8?
        @pointer.as(UInt8*).value
      when .i16?
        @pointer.as(Int16*).value
      when .u16?
        @pointer.as(UInt16*).value
      when .i32?
        @pointer.as(Int32*).value
      when .u32?
        @pointer.as(UInt32*).value
      when .i64?
        @pointer.as(Int64*).value
      when .u64?
        @pointer.as(UInt64*).value
      when .i128?
        @pointer.as(Int128*).value
      when .u128?
        @pointer.as(UInt128*).value
      else
        raise "BUG: missing handling of Repl value for #{type}"
      end
    when FloatType
      case type.kind
      when .f32?
        @pointer.as(Float32*).value
      when .f64?
        @pointer.as(Float64*).value
      else
        raise "BUG: missing handling of Repl value for #{type}"
      end
    when type.program.string
      @pointer.as(UInt8**).value.unsafe_as(String)
    when PointerInstanceType
      @pointer.as(UInt8**).value
    when MetaclassType, GenericClassInstanceMetaclassType, VirtualMetaclassType
      type_id = @pointer.as(Int32*).value
      context.type_from_id(type_id)
    else
      @pointer
    end
  end

  # Copies the contents of this value to another pointer.
  def copy_to(pointer : Pointer(UInt8))
    @pointer.copy_to(pointer, context.inner_sizeof_type(@type))
  end

  # Appends the string representation of this value to the given *io*.
  # This is done by interpreting a call to `inspect` (not `to_s`)
  # on this value.
  def to_s(io : IO)
    decl = UninitializedVar.new(Var.new("x"), TypeNode.new(@type))
    call = Call.new(Var.new("x"), "inspect")
    exps = Expressions.new([decl, call] of ASTNode)

    begin
      value = Interpreter.interpret(context, exps) do |stack|
        stack.copy_from(@pointer, context.inner_sizeof_type(@type))
      end
      if value.type == context.program.string
        value.pointer.as(UInt8**).value.unsafe_as(String).to_s(io)
      else
        value.fallback_to_s(io)
      end
    rescue ex
      io.puts "Error while calling inspect on value: #{ex.message}"
      fallback_to_s(io)
    end
  end

  # A way to compute a string representation of a value for _some_
  # types, if computing `inspect` fails for some reason.
  def fallback_to_s(io : IO)
    type = @type
    case type
    when NilType
      io << "nil"
    when BoolType
      io << @pointer.as(Bool*).value
    when CharType
      @pointer.as(Char*).value.inspect(io)
    when IntegerType
      case type.kind
      when .i8?
        io << @pointer.as(Int8*).value
      when .u8?
        io << @pointer.as(UInt8*).value
      when .i16?
        io << @pointer.as(Int16*).value
      when .u16?
        io << @pointer.as(UInt16*).value
      when .i32?
        io << @pointer.as(Int32*).value
      when .u32?
        io << @pointer.as(UInt32*).value
      when .i64?
        io << @pointer.as(Int64*).value
      when .u64?
        io << @pointer.as(UInt64*).value
      when .i128?
        io << @pointer.as(Int128*).value
      when .u128?
        io << @pointer.as(UInt128*).value
      else
        raise "BUG: missing handling of Repl::Value#to_s(io) for #{type}"
      end
    when FloatType
      case type.kind
      when .f32?
        io << @pointer.as(Float32*).value
      when .f64?
        io << @pointer.as(Float64*).value
      else
        raise "BUG: missing handling of Repl::Value#to_s(io) for #{type}"
      end
    when type.program.string
      @pointer.as(UInt8**).value.unsafe_as(String).inspect(io)
    when PointerInstanceType
      pointer = @pointer.as(UInt8**).value
      io << type
      if pointer.null?
        io << ".null"
      else
        io << "@0x"
        pointer.address.to_s(io, base: 16)
      end
    when TupleInstanceType
      io << "{"
      type.tuple_types.each_with_index do |tuple_type, i|
        io << Value.new(@interpreter, @pointer + context.offset_of(type, i), tuple_type)
        io << ", " unless i == type.tuple_types.size - 1
      end
      io << "}"
    when MetaclassType, GenericClassInstanceMetaclassType
      type_id = @pointer.as(Int32*).value
      type = context.type_from_id(type_id)
      io << type
    when MixedUnionType
      type_id = @pointer.as(Int32*).value
      type = context.type_from_id(type_id)
      io << Value.new(@interpreter, @pointer + sizeof(Pointer(UInt8)), type)
    when InstanceVarContainer
      if type.struct?
        ptr = @pointer
        io << type
        io << "("
        all_instance_vars = type.all_instance_vars
        all_instance_vars.each_with_index do |(name, ivar), index|
          offset = context.offset_of(type, index)
          io << name
          io << '='
          io << Value.new(@interpreter, ptr + offset, ivar.type)
          io << ' ' unless index == all_instance_vars.size - 1
        end
        io << ")"
      else
        ptr = @pointer.as(UInt8**).value
        type_id = ptr.as(Int32*).value
        type = context.type_from_id(type_id)
        io << "#<"
        io << type
        io << ":0x"
        ptr.address.to_s(io, 16)
        type.all_instance_vars.each_with_index do |(name, ivar), index|
          offset = context.instance_offset_of(type, index)
          io << ' '
          io << name
          io << '='
          io << Value.new(@interpreter, ptr + offset, ivar.type)
        end
        io << ">"
      end
    else
      io << "BUG: missing handling of Repl::Value#to_s(io) for #{type}"
    end
  end

  private def context
    @interpreter.context
  end
end
