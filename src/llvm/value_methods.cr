module LLVM::ValueMethods
  def initialize(@unwrap : LibLLVM::ValueRef)
  end

  def name=(name)
    LibLLVM.set_value_name(self, name)
  end

  def name
    String.new LibLLVM.get_value_name(self)
  end

  def kind
    LibLLVM.get_value_kind(self)
  end

  def add_instruction_attribute(index : Int, attribute : LLVM::Attribute, context : LLVM::Context, type : LLVM::Type? = nil)
    return if attribute.value == 0

    attribute.each_kind do |kind|
      LibLLVM.add_call_site_attribute(self, index, attribute_ref(context, kind, type))
    end
  end

  private def attribute_ref(context, kind, type)
    if type.is_a?(Type) && Attribute.requires_type?(kind)
      {% if LibLLVM::IS_LT_120 %}
        raise "Type arguments are only supported on LLVM 12.0 or above"
      {% else %}
        LibLLVM.create_type_attribute(context, kind, type)
      {% end %}
    else
      LibLLVM.create_enum_attribute(context, kind, 0)
    end
  end

  def constant?
    LibLLVM.is_constant(self) != 0
  end

  def type
    Type.new LibLLVM.type_of(self)
  end

  def thread_local=(thread_local)
    LibLLVM.set_thread_local(self, thread_local ? 1 : 0)
  end

  def thread_local?
    LibLLVM.is_thread_local(self) != 0
  end

  def linkage=(linkage)
    LibLLVM.set_linkage(self, linkage)
  end

  def linkage
    LibLLVM.get_linkage(self)
  end

  def dll_storage_class=(storage_class)
    LibLLVM.set_dll_storage_class(self, storage_class)
  end

  def call_convention=(call_convention)
    LibLLVM.set_instruction_call_convention(self, call_convention)
  end

  def call_convention
    LibLLVM.get_instruction_call_convention(self)
  end

  def global_constant=(global_constant)
    LibLLVM.set_global_constant(self, global_constant ? 1 : 0)
  end

  def global_constant?
    LibLLVM.is_global_constant(self) != 0
  end

  def initializer=(initializer)
    LibLLVM.set_initializer(self, initializer)
  end

  def initializer
    init = LibLLVM.get_initializer(self)
    init ? LLVM::Value.new(init) : nil
  end

  def volatile=(volatile)
    LibLLVM.set_volatile(self, volatile ? 1 : 0)
  end

  def ordering=(ordering)
    LibLLVM.set_ordering(self, ordering)
  end

  def alignment=(bytes)
    LibLLVM.set_alignment(self, bytes)
  end

  def const_int_get_sext_value
    LibLLVM.const_int_get_sext_value(self)
  end

  def const_int_get_zext_value
    LibLLVM.const_int_get_zext_value(self)
  end

  def to_value
    LLVM::Value.new @unwrap
  end

  def dump
    LibLLVM.dump_value self
  end

  def inspect(io : IO) : Nil
    LLVM.to_io(LibLLVM.print_value_to_string(self), io)
  end

  def to_unsafe
    @unwrap
  end
end
