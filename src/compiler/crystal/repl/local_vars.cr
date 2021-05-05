require "./repl"

class Crystal::Repl::LocalVars
  def initialize(@program : Program)
    @values = [] of UInt8
    @types = [] of Type
    @name_to_index = {} of String => Int32
  end

  def names
    @name_to_index.keys
  end

  def name_to_index(name : String, type : Type) : Int32
    index = @name_to_index[name]?
    unless index
      index = @values.size
      @name_to_index[name] = index
      @types << type
      sizeof_type(type).times do
        @values << 0_u8
      end
    end
    index
  end

  def index_to_name(index : Int32) : String
    @name_to_index.keys[index]
  end

  def pointerof(index : Int32)
    value = @values.to_unsafe + index
    value.as(Pointer(UInt8))
  end

  def sizeof_type(type) : Int32
    @program.size_of(type.sizeof_type).to_i32
  end
end
