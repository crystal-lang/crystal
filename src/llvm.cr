require "./llvm/**"
require "c/string"

module LLVM
  # Returns the runtime version of LLVM.
  #
  # Starting with LLVM 16, this method returns the version as reported by
  # `LLVMGetVersion` at runtime. Older versions of LLVM do not expose this
  # information, so the value falls back to `LibLLVM::VERSION` which is
  # determined at compile time and might slightly be out of sync to the
  # dynamic library loaded at runtime.
  def self.version
    {% if LibLLVM.has_method?(:get_version) %}
      LibLLVM.get_version(out major, out minor, out patch)
      "#{major}.#{minor}.#{patch}"
    {% else %}
      LibLLVM::VERSION
    {% end %}
  end

  {% for target in LibLLVM::ALL_TARGETS %}
    {% name = target.downcase.id %}
    @@initialized_{{ name }} = Atomic(Bool).new(false)

    def self.init_{{ name }} : Nil
      return if @@initialized_{{ name }}.swap(true)

      \{% if LibLLVM::BUILT_TARGETS.includes?({{ name.symbolize }}) %}
        LibLLVM.initialize_{{ name }}_target_info
        LibLLVM.initialize_{{ name }}_target
        LibLLVM.initialize_{{ name }}_target_mc
        LibLLVM.initialize_{{ name }}_asm_printer
        LibLLVM.initialize_{{ name }}_asm_parser
        LibLLVM.link_in_mc_jit
      \{% else %}
        raise "ERROR: LLVM was built without {{ target.id }} target"
      \{% end %}
    end
  {% end %}

  def self.init_native_target : Nil
    {% if flag?(:i386) || flag?(:x86_64) %}
      init_x86
    {% elsif flag?(:aarch64) %}
      init_aarch64
    {% elsif flag?(:arm) %}
      init_arm
    {% elsif flag?(:wasm32) %}
      init_webassembly
    {% elsif flag?(:avr) %}
      init_avr
    {% else %}
      {% raise "Unsupported platform" %}
    {% end %}
  end

  def self.init_all_targets : Nil
    {% for target in LibLLVM::ALL_TARGETS %}
      {% name = target.downcase.id %}
      \{% if LibLLVM::BUILT_TARGETS.includes?({{ name.symbolize }}) %}
        init_{{ name }}
      \{% end %}
    {% end %}
  end

  @[Deprecated("This method has no effect")]
  def self.start_multithreaded : Bool
    if multithreaded?
      true
    else
      LibLLVM.start_multithreaded != 0
    end
  end

  @[Deprecated("This method has no effect")]
  def self.stop_multithreaded
    if multithreaded?
      LibLLVM.stop_multithreaded
    end
  end

  def self.multithreaded? : Bool
    LibLLVM.is_multithreaded != 0
  end

  def self.default_target_triple : String
    chars = LibLLVM.get_default_target_triple
    case triple = string_and_dispose(chars)
    when .starts_with?("aarch64-unknown-linux-android")
      # remove API version
      "aarch64-unknown-linux-android"
    when .starts_with?("x86_64-pc-solaris")
      # remove API version
      "x86_64-pc-solaris"
    else
      triple
    end
  end

  def self.host_cpu_name : String
    String.new LibLLVM.get_host_cpu_name
  end

  def self.normalize_triple(triple : String) : String
    normalized = LibLLVM.normalize_target_triple(triple)
    normalized = LLVM.string_and_dispose(normalized)

    normalized
  end

  def self.to_io(chars, io) : Nil
    io.write_string Slice.new(chars, LibC.strlen(chars))
    LibLLVM.dispose_message(chars)
  end

  def self.string_and_dispose(chars) : String
    string = String.new(chars)
    LibLLVM.dispose_message(chars)
    string
  end

  def self.parse_command_line_options(options : Enumerable(String), overview : String = "") : Nil
    c_strs = options.to_a(&.to_unsafe)
    LibLLVM.parse_command_line_options(c_strs.size, c_strs, overview)
  end

  protected def self.assert(error : LibLLVM::ErrorRef)
    if error
      chars = LibLLVM.get_error_message(error)
      raise String.new(chars).tap { LibLLVM.dispose_error_message(chars) }
    end
  end

  {% unless LibLLVM::IS_LT_130 %}
    def self.run_passes(module mod : Module, passes : String, target_machine : TargetMachine, options : PassBuilderOptions)
      LibLLVM.run_passes(mod, passes, target_machine, options)
    end
  {% end %}

  DEBUG_METADATA_VERSION = 3
end
