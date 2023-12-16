{% begin %}
lib LibLLVM
  LLVM_CONFIG = {{ env("LLVM_CONFIG") || `#{__DIR__}/ext/find-llvm-config`.stringify }}
end
{% end %}

{% begin %}
  {% unless flag?(:win32) %}
    @[Link("stdc++")]
  {% end %}
  @[Link(ldflags: {{"`#{LibLLVM::LLVM_CONFIG} --libs --system-libs --ldflags#{" --link-static".id if flag?(:static)}#{" 2> /dev/null".id unless flag?(:win32)}`"}})]
  lib LibLLVM
    VERSION = {{`#{LibLLVM::LLVM_CONFIG} --version`.chomp.stringify.gsub(/git/, "")}}
    BUILT_TARGETS = {{ (
                         env("LLVM_TARGETS") || `#{LibLLVM::LLVM_CONFIG} --targets-built`
                       ).strip.downcase.split(' ').map(&.id.symbolize) }}
  end
{% end %}

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
