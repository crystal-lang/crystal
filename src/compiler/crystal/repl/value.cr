require "./repl"

struct Crystal::Repl::Value
  getter type : Type
  getter pointer : Pointer(Void)

  def initialize(value : Nil, @type : Type)
    @pointer = Pointer(Void).new(0)
  end

  def initialize(value : Bool, @type : Type)
    @pointer = Pointer(Void).new(value ? 1 : 0)
  end

  def initialize(value : Char, @type : Type)
    @pointer = Pointer(Void).new(value.ord)
  end

  def initialize(value : Int, @type : Type)
    @pointer = Pointer(Void).new(value)
  end

  def initialize(value : Float32, @type : Type)
    @pointer = Pointer(Void).new(value.unsafe_as(Int32))
  end

  def initialize(value : Float64, @type : Type)
    @pointer = Pointer(Void).new(value.unsafe_as(Int64))
  end

  def initialize(value : String, @type : Type)
    @pointer = Pointer(Void).new(value.object_id)
  end

  def initialize(value : Pointer(Void), @type : Type)
    @pointer = value
  end

  def initialize(value : Type, @type : Type)
    @pointer = Pointer(Void).new(value.object_id)
  end

  def truthy?
    case value
    when Nil
      false
    when Bool
      value == true
    else
      # TODO: missing pointer
      true
    end
  end

  def value
    type = @type
    case type
    when NilType
      nil
    when BoolType
      @pointer.unsafe_as(Bool)
    when IntegerType
      case type.kind
      when :i8
        @pointer.unsafe_as(Int8)
      when :u8
        @pointer.unsafe_as(UInt8)
      when :i16
        @pointer.unsafe_as(Int16)
      when :u16
        @pointer.unsafe_as(UInt16)
      when :i32
        @pointer.unsafe_as(Int32)
      when :u32
        @pointer.unsafe_as(UInt32)
      when :i64
        @pointer.unsafe_as(Int64)
      when :u64
        @pointer.unsafe_as(UInt64)
      else
        raise "BUG: missing handling of Repl value for #{type}"
      end
    when FloatType
      case type.kind
      when :f32
        @pointer.unsafe_as(Float32)
      when :f64
        @pointer.unsafe_as(Float64)
      else
        raise "BUG: missing handling of Repl value for #{type}"
      end
    when type.program.string
      @pointer.unsafe_as(String)
    when PointerInstanceType
      PointerWrapper.new(@pointer)
    when MetaclassType
      @pointer.unsafe_as(Type)
    else
      raise "BUG: missing handling of Repl value for #{type}"
    end
  end
end
