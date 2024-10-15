require "c_types"

{% if flag?(:win32) %}
  @[Link({{ flag?(:static) ? "libucrt" : "ucrt" }})]
{% end %}
lib LibC
  alias Char = CTypes::Char
  alias UChar = CTypes::UChar
  alias SChar = CTypes::SChar
  alias Short = CTypes::Short
  alias UShort = CTypes::UShort
  alias Int = CTypes::Int
  alias UInt = CTypes::UInt
  alias Long = CTypes::Long
  alias ULong = CTypes::ULong
  alias LongLong = CTypes::LongLong
  alias ULongLong = CTypes::ULongLong
  alias Float = CTypes::Float
  alias Double = CTypes::Double

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
