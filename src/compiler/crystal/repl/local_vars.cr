require "./repl"

class Crystal::Repl::LocalVars
  def initialize
    @vars = [] of Value
    @name_to_index = {} of String => Int32
  end

  def names
    @name_to_index.keys
  end

  def [](name : String) : Value
    index = @name_to_index[name]
    @vars[index]
  end

  def []=(name : String, value : Value) : Value
    index = @name_to_index[name]?
    if index
      @vars[index] = value
    else
      index = @name_to_index.size
      @name_to_index[name] = index
      @vars << value
    end
    value
  end

  def pointerof(name)
    index = @name_to_index[name]

    type = @vars[index].type
    pointer_type = type.program.pointer_of(type)

    value = @vars.to_unsafe + index
    Value.new(value.as(Pointer(Value)), pointer_type)
  end
end
