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

  def declare(name : String, type : Type) : Int32
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
    @bytesize += sizeof_type(type)
    index
  end

  def name_to_index(name : String) : Int32
    @name_to_index[name]
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

  def sizeof_type(type) : Int32
    @program.size_of(type.sizeof_type).to_i32
  end
end
