require "./repl"

class Crystal::Repl::LocalVars
  def initialize
    @vars = [] of Value
    @name_to_index = {} of String => Int32
  end

  def names
    @name_to_index.keys
  end

  def name_to_index(name : String) : Int32
    index = @name_to_index[name]?
    unless index
      index = @name_to_index.size
      @name_to_index[name] = index

      value = uninitialized Value
      @vars << value
    end
    index
  end

  def [](index : Int32) : Value
    @vars[index]
  end

  def []=(index : Int32, value : Value) : Value
    @vars[index] = value
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
