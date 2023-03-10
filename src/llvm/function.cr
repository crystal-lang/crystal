require "./value_methods"

struct LLVM::Function
  include LLVM::ValueMethods

  def self.from_value(value : LLVM::ValueMethods)
    new(value.to_unsafe)
  end

  def basic_blocks
    BasicBlockCollection.new self
  end

  def call_convention
    LLVM::CallConvention.new LibLLVM.get_function_call_convention(self)
  end

  def call_convention=(cc)
    LibLLVM.set_function_call_convention(self, cc)
  end

  def add_attribute(attribute : Attribute, index = AttributeIndex::FunctionIndex, type : Type? = nil)
    return if attribute.value == 0

    context = LibLLVM.get_module_context(LibLLVM.get_global_parent(self))
    attribute.each_kind do |kind|
      LibLLVM.add_attribute_at_index(self, index, attribute_ref(context, kind, type))
    end
  end

  def add_target_dependent_attribute(name, value)
    LibLLVM.add_target_dependent_function_attr self, name, value
  end

  def attributes(index = AttributeIndex::FunctionIndex)
    attrs = Attribute::None
    0.upto(LibLLVM.get_last_enum_attribute_kind) do |kind|
      if LibLLVM.get_enum_attribute_at_index(self, index, kind)
        attrs |= Attribute.from_kind(kind)
      end
    end
    attrs
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

  def naked?
    attributes.naked?
  end
end
