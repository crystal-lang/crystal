require "./repl"

class Crystal::Repl::LocalVars
  def initialize
    @values = [] of Pointer(Void)
    @types = [] of Type
    @name_to_index = {} of String => Int32
  end

  def names
    @name_to_index.keys
  end

  def [](name : String)
    index = @name_to_index[name]
    Value.new(@values[index], @types[index])
  end

  def []=(name : String, value : Value)
    index = @name_to_index[name]?
    if index
      @values[index] = value.pointer
      @types[index] = value.type
    else
      index = @name_to_index.size
      @name_to_index[name] = index
      @values << value.pointer
      @types << value.type
    end
    value
  end

  def pointerof(name)
    index = @name_to_index[name]
    value = @values.to_unsafe + index

    type = @types[index]
    pointer_type = type.program.pointer_of(type)

    Value.new(value.as(Pointer(Void)), pointer_type)
  end
end
