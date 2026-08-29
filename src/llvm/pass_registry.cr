{% unless LibLLVM::IS_LT_170 %}
  @[Deprecated("The legacy pass manager was removed in LLVM 17. Use `LLVM::PassBuilderOptions` instead")]
{% end %}
struct LLVM::PassRegistry
  def self.instance : self
    new LibLLVM.get_global_pass_registry
  end

  def initialize(@unwrap : LibLLVM::PassRegistryRef)
  end

  {% begin %}
    Inits = %w[
      initialize_core
      initialize_transform_utils
      initialize_scalar_opts
      {% if LibLLVM::IS_LT_160 %} initialize_obj_c_arc_opts {% end %}
      initialize_vectorization
      initialize_inst_combine
      initialize_ipo
      {% if LibLLVM::IS_LT_160 %} initialize_instrumentation {% end %}
      initialize_analysis
      initialize_ipa
      initialize_code_gen
      initialize_target
    ]
  {% end %}

  {% for name in Inits %}
    def {{ name.id }}
      LibLLVM.{{ name.id }} self
    end
  {% end %}

  def initialize_all
    {% for name in Inits %}
      {{ name.id }}
    {% end %}
  end

  def to_unsafe
    @unwrap
  end
end
