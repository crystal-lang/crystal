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

  def add_instruction_attribute(index : Int, attribute : LLVM::Attribute, context : LLVM::Context)
    return if attribute.value == 0
    {% if LibLLVM.has_constant?(:AttributeRef) %}
      attribute.each_kind do |kind|
        attribute_ref = LibLLVM.create_enum_attribute(context, kind, 0)
        LibLLVM.add_call_site_attribute(self, index, attribute_ref)
      end
    {% else %}
      LibLLVM.add_instr_attribute(self, index, attribute)
    {% end %}
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
    LibLLVMExt.set_ordering(self, ordering)
  end

  def alignment=(bytes)
    LibLLVM.set_alignment(self, bytes)
  end

  def to_value
    LLVM::Value.new unwrap
  end

  def dump
    LibLLVM.dump_value self
  end

  def inspect(io)
    LLVM.to_io(LibLLVM.print_value_to_string(self), io)
    self
  end

  def to_unsafe
    @unwrap
  end
end
