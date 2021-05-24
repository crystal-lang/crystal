require "./repl"

class Crystal::Repl::Context
  getter program : Program
  getter defs : Hash(Def, CompiledDef)

  def initialize(@program : Program)
    @defs = {} of Def => CompiledDef
    @defs.compare_by_identity
  end

  def sizeof_type(node : ASTNode) : Int32
    type = node.type?
    if type
      sizeof_type(node.type)
    else
      node.raise "BUG: missing type for #{node} (#{node.class})"
    end
  end

  def sizeof_type(type : Type) : Int32
    @program.size_of(type.sizeof_type).to_i32
  end

  def instance_sizeof_type(type : Type) : Int32
    @program.instance_size_of(type.sizeof_type).to_i32
  end

  def offset_of(type : Type, index : Int32) : Int32
    @program.offset_of(type.sizeof_type, index).to_i32
  end

  def instance_offset_of(type : Type, index : Int32) : Int32
    @program.instance_offset_of(type.sizeof_type, index).to_i32
  end

  def ivar_offset(type : Type, name : String) : Int32
    ivar_index = type.index_of_instance_var(name).not_nil!

    if type.passed_by_value?
      @program.offset_of(type.sizeof_type, ivar_index).to_i32
    else
      @program.instance_offset_of(type.sizeof_type, ivar_index).to_i32
    end
  end

  def type_id(type : Type) : Int32
    @program.llvm_id.type_id(type)
  end

  def type_from_id(id : Int32) : Type
    @program.llvm_id.type_from_id(id)
  end
end
