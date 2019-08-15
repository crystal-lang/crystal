require "./value_methods"

struct LLVM::Function
  include LLVM::ValueMethods

  def basic_blocks
    BasicBlockCollection.new self
  end

  def call_convention
    LLVM::CallConvention.new LibLLVM.get_function_call_convention(self)
  end

  def call_convention=(cc)
    LibLLVM.set_function_call_convention(self, cc)
  end

  def add_attribute(attribute : Attribute, index = AttributeIndex::FunctionIndex)
    return if attribute.value == 0
    {% if LibLLVM.has_constant?(:AttributeRef) %}
      context = LibLLVM.get_module_context(LibLLVM.get_global_parent(self))
      attribute.each_kind do |kind|
        attribute_ref = LibLLVM.create_enum_attribute(context, kind, 0)
        LibLLVM.add_attribute_at_index(self, index, attribute_ref)
      end
    {% else %}
      case index
      when AttributeIndex::FunctionIndex
        LibLLVM.add_function_attr(self, attribute)
      when AttributeIndex::ReturnIndex
        raise "Unsupported: can't set attributes on function return type in LLVM < 3.9"
      else
        LibLLVM.add_attribute(params[index.to_i - 1], attribute)
      end
    {% end %}
  end

  def add_target_dependent_attribute(name, value)
    LibLLVM.add_target_dependent_function_attr self, name, value
  end

  def attributes(index = AttributeIndex::FunctionIndex)
    {% if LibLLVM.has_constant?(:AttributeRef) %}
      attrs = Attribute::None
      0.upto(LibLLVM.get_last_enum_attribute_kind) do |kind|
        if LibLLVM.get_enum_attribute_at_index(self, index, kind)
          attrs |= Attribute.from_kind(kind)
        end
      end
      attrs
    {% else %}
      case index
      when AttributeIndex::FunctionIndex
        LibLLVM.get_function_attr(self)
      when AttributeIndex::ReturnIndex
        raise "Unsupported: can't get attributes from function return type in LLVM < 3.9"
      else
        LibLLVM.get_attribute(params[index.to_i - 1])
      end
    {% end %}
  end

  def function_type
    Type.new LibLLVM.get_element_type(LibLLVM.type_of(self))
  end

  def return_type
    function_type.return_type
  end

  def varargs?
    function_type.varargs?
  end

  def params
    ParameterCollection.new self
  end

  def personality_function=(fn)
    LibLLVM.set_personality_fn(self, fn)
  end

  def delete
    LibLLVM.delete_function(self)
  end
end
