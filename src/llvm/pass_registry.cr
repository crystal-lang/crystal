{% skip_file unless LibLLVM::IS_LT_170 %}

struct LLVM::PassRegistry
  def self.instance : self
    new LibLLVM.get_global_pass_registry
  end

  def initialize(@unwrap : LibLLVM::PassRegistryRef)
  end

  Inits = %w(
    initialize_core
    initialize_transform_utils
    initialize_scalar_opts
    initialize_obj_c_arc_opts
    initialize_vectorization
    initialize_inst_combine
    initialize_ipo
    initialize_instrumentation
    initialize_analysis
    initialize_ipa
    initialize_code_gen
    initialize_target
  )

  {% for name in Inits %}
    {% if LibLLVM.has_method?(name) %}
      def {{name.id}}
        LibLLVM.{{name.id}} self
      end
    {% end %}
  {% end %}

  def initialize_all
    {% for name in Inits %}
      {% if LibLLVM.has_method?(name) %}
        {{name.id}}
      {% end %}
    {% end %}
  end

  def to_unsafe
    @unwrap
  end
end
