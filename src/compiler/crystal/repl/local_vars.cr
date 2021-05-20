require "./repl"

class Crystal::Repl::LocalVars
  def initialize(@program : Program)
    @types = {} of String => Type
    @name_to_index = {} of String => Int32
    @bytesize = 0
  end

  def bytesize
    @bytesize
  end

  def names
    @name_to_index.keys
  end

  def declare(name : String, type : Type) : Nil
    is_self = name == "self"
    return if is_self && type.is_a?(Program)

    index = @name_to_index[name]?
    if index
      existing_type = @types[name]
      if existing_type != type
        raise "BUG: redeclaring local variable with a different type is not yet supported (#{name} from #{existing_type} to #{type})"
      end
      return index
    end

    index = @bytesize
    @name_to_index[name] = index

    @types[name] = type

    if is_self && type.passed_by_value?
      @bytesize += sizeof(Pointer(UInt8))
    else
      @bytesize += sizeof_type(type)
    end
  end

  def name_to_index(name : String) : Int32
    @name_to_index[name]
  end

  def name_to_index?(name : String) : Int32?
    @name_to_index[name]?
  end

  def index_to_name(index : Int32) : String
    @name_to_index.each do |name, i|
      return name if i == index
    end
    raise KeyError.new
  end

  def type(name : String) : Type
    @types[name]
  end

  def each_name_index_and_size
    names_and_indexes = @name_to_index.to_a
    names_and_indexes.each_with_index do |(name, index), i|
      next_index = names_and_indexes[i + 1]?.try &.[1]
      if next_index
        yield name, index, next_index - index
      else
        yield name, index, @bytesize - index
      end
    end
  end

  private def sizeof_type(type) : Int32
    @program.size_of(type.sizeof_type).to_i32
  end
end
