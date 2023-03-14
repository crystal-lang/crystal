{% skip_file if LibLLVM::IS_LT_130 %}

class LLVM::PassBuilderOptions
  def initialize
    @options = LibLLVM.create_pass_builder_options
    @disposed = false
  end

  def self.new(&)
    options = new
    begin
      yield options
    ensure
      options.finalize
    end
  end

  def to_unsafe
    @options
  end

  def finalize
    return if @disposed
    @disposed = true

    LibLLVM.dispose_pass_builder_options(self)
  end
end
