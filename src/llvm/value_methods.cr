module LLVM::ValueMethods
  getter :unwrap

  def initialize(@unwrap)
  end

  def name=(name)
    LibLLVM.set_value_name(self, name)
  end

  def name
    String.new LibLLVM.get_value_name(self)
  end

  def add_attribute(attribute)
    LibLLVM.add_attribute self, attribute
  end

  def attributes
    LibLLVM.get_attribute(self)
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
