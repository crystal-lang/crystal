struct LLVM::PassRegistry
  def self.instance
    new LibLLVM.get_global_pass_registry
  end

  def initialize(@unwrap)
  end

  Inits = %w(core transform_utils scalar_opts obj_c_arc_opts vectorization inst_combine ipo instrumentation analysis ipa code_gen target)

  {% for name in Inits %}
    def initialize_{{name.id}}
      LibLLVM.initialize_{{name.id}} self
    end
  {% end %}

  def initialize_all
    {% for name in Inits %}
      initialize_{{name.id}}
    {% end %}
  end

  def to_unsafe
    @unwrap
  end
end
