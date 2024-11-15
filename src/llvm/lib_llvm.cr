{% begin %}
  {% if flag?(:msvc) && !flag?(:static) %}
    {% config = nil %}
    {% for dir in Crystal::LIBRARY_PATH.split(Crystal::System::Process::HOST_PATH_DELIMITER) %}
      {% config ||= read_file?("#{dir.id}/llvm_VERSION") %}
    {% end %}

    {% unless config %}
      {% raise "Cannot determine LLVM configuration; ensure the file `llvm_VERSION` exists under `CRYSTAL_LIBRARY_PATH`" %}
    {% end %}

    {% lines = config.lines.map(&.chomp) %}
    {% llvm_version = lines[0] %}
    {% llvm_targets = lines[1] %}
    {% llvm_ldflags = lines[2] %}

    @[Link("llvm")]
    {% if compare_versions(Crystal::VERSION, "1.11.0-dev") >= 0 %}
      @[Link(dll: "LLVM-C.dll")]
    {% end %}
    lib LibLLVM
    end
  {% else %}
    {% llvm_config = env("LLVM_CONFIG") || `sh #{__DIR__}/ext/find-llvm-config`.stringify %}
    {% llvm_version = `#{llvm_config.id} --version`.stringify %}
    {% llvm_targets = env("LLVM_TARGETS") || `#{llvm_config.id} --targets-built`.stringify %}
    {% llvm_ldflags = "`#{llvm_config.id} --libs --system-libs --ldflags#{" --link-static".id if flag?(:static)}#{" 2> /dev/null".id unless flag?(:win32)}`" %}

    {% unless flag?(:win32) %}
      @[Link("stdc++")]
      lib LibLLVM
      end
    {% end %}
  {% end %}

  @[Link(ldflags: {{ llvm_ldflags }})]
  lib LibLLVM
    VERSION = {{ llvm_version.strip.gsub(/git/, "").gsub(/rc.*/, "") }}
    BUILT_TARGETS = {{ llvm_targets.strip.downcase.split(' ').map(&.id.symbolize) }}
  end
{% end %}

# Supported library versions:
#
# * LLVM (8-19; aarch64 requires 13+)
#
# See https://crystal-lang.org/reference/man/required_libraries.html#other-stdlib-libraries
{% begin %}
  lib LibLLVM
    IS_180 = {{LibLLVM::VERSION.starts_with?("18.0")}}
    IS_170 = {{LibLLVM::VERSION.starts_with?("17.0")}}
    IS_160 = {{LibLLVM::VERSION.starts_with?("16.0")}}
    IS_150 = {{LibLLVM::VERSION.starts_with?("15.0")}}
    IS_140 = {{LibLLVM::VERSION.starts_with?("14.0")}}
    IS_130 = {{LibLLVM::VERSION.starts_with?("13.0")}}
    IS_120 = {{LibLLVM::VERSION.starts_with?("12.0")}}
    IS_111 = {{LibLLVM::VERSION.starts_with?("11.1")}}
    IS_110 = {{LibLLVM::VERSION.starts_with?("11.0")}}
    IS_100 = {{LibLLVM::VERSION.starts_with?("10.0")}}
    IS_90 = {{LibLLVM::VERSION.starts_with?("9.0")}}
    IS_80 = {{LibLLVM::VERSION.starts_with?("8.0")}}

    IS_LT_90 = {{compare_versions(LibLLVM::VERSION, "9.0.0") < 0}}
    IS_LT_100 = {{compare_versions(LibLLVM::VERSION, "10.0.0") < 0}}
    IS_LT_110 = {{compare_versions(LibLLVM::VERSION, "11.0.0") < 0}}
    IS_LT_120 = {{compare_versions(LibLLVM::VERSION, "12.0.0") < 0}}
    IS_LT_130 = {{compare_versions(LibLLVM::VERSION, "13.0.0") < 0}}
    IS_LT_140 = {{compare_versions(LibLLVM::VERSION, "14.0.0") < 0}}
    IS_LT_150 = {{compare_versions(LibLLVM::VERSION, "15.0.0") < 0}}
    IS_LT_160 = {{compare_versions(LibLLVM::VERSION, "16.0.0") < 0}}
    IS_LT_170 = {{compare_versions(LibLLVM::VERSION, "17.0.0") < 0}}
    IS_LT_180 = {{compare_versions(LibLLVM::VERSION, "18.0.0") < 0}}
    IS_LT_190 = {{compare_versions(LibLLVM::VERSION, "19.0.0") < 0}}
  end
{% end %}

lib LibLLVM
  alias Char = LibC::Char
  alias Int = LibC::Int
  alias UInt = LibC::UInt
  alias LongLong = LibC::LongLong
  alias ULongLong = LibC::ULongLong
  alias Double = LibC::Double
  alias SizeT = LibC::SizeT
end

require "./lib_llvm/**"
