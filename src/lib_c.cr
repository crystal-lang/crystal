# Supported library versions:
#
# * glibc (2.26+)
# * musl libc (1.2+)
# * system libraries of several BSDs
# * macOS system library (11+)
# * MSVCRT
# * WASI
# * bionic libc
#
# See https://crystal-lang.org/reference/man/required_libraries.html#system-library
{% if flag?(:msvc) %}
  @[Link({{ flag?(:static) ? "libucrt" : "ucrt" }})]
{% end %}
lib LibC
  alias Char = UInt8
  alias UChar = Char
  alias SChar = Int8
  alias Short = Int16
  alias UShort = UInt16
  alias Int = Int32
  alias UInt = UInt32

  {% if flag?(:bits32) || flag?(:win32) %}
    alias Long = Int32
    alias ULong = UInt32
  {% elsif flag?(:bits64) %}
    alias Long = Int64
    alias ULong = UInt64
  {% else %}
    {% raise "Architecture with unsupported word size" %}
  {% end %}

  alias LongLong = Int64
  alias ULongLong = UInt64
  alias Float = Float32
  alias Double = Float64

  {% if flag?(:android) %}
    {% default_api_version = 31 %}
    {% min_supported_version = 24 %}
    {% api_version_var = env("ANDROID_PLATFORM") || env("ANDROID_NATIVE_API_LEVEL") %}
    {% api_version = api_version_var ? api_version_var.gsub(/^android-/, "").to_i : default_api_version %}
    {% raise "TODO: Support Android API level below #{min_supported_version}" unless api_version >= min_supported_version %}
    ANDROID_API = {{ api_version }}
  {% end %}

  $environ : Char**
end
