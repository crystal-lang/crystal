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

  {% unless LibLLVM::IS_LT_170 %}
    def set_inliner_threshold(threshold : Int)
      LibLLVM.pass_builder_options_set_inliner_threshold(self, threshold)
    end
  {% end %}

  def set_loop_unrolling(enabled : Bool)
    LibLLVM.pass_builder_options_set_loop_unrolling(self, enabled)
  end

  def set_loop_vectorization(enabled : Bool)
    LibLLVM.pass_builder_options_set_loop_vectorization(self, enabled)
  end

  def set_slp_vectorization(enabled : Bool)
    LibLLVM.pass_builder_options_set_slp_vectorization(self, enabled)
  end
end
