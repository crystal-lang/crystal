# Builds a `String` through a UTF-16 `IO`.
#
# Similar to `String.build`, but the yielded `IO` is configured to use the
# UTF-16 encoding, and the written contents are decoded back into a UTF-8
# `String`. This method is mainly used by `assert_prints` to test the behaviour
# of string-generating methods under different encodings.
#
# Raises if the `without_iconv` flag is set.
def string_build_via_utf16(& : IO -> _)
  {% if flag?(:without_iconv) %}
    raise NotImplementedError.new("string_build_via_utf16")
  {% else %}
    io = IO::Memory.new
    io.set_encoding(IO::ByteFormat::SystemEndian == IO::ByteFormat::LittleEndian ? "UTF-16LE" : "UTF-16BE")
    yield io
    byte_slice = io.to_slice
    utf16_slice = byte_slice.unsafe_slice_of(UInt16)
    String.from_utf16(utf16_slice)
  {% end %}
end

# Asserts that the given *call* and its `IO`-accepting variants produce the
# given string *str*.
#
# Given a call of the form `foo.bar(*args, **opts)`, tests the following cases:
#
# * This call itself should return a `String` equal to *str*.
# * `String.build { |io| foo.bar(io, *args, **opts) }` should be equal to
#   `str.scrub`; writing to a `String::Builder` must not produce any invalid
#   UTF-8 byte sequences.
# * `string_build_via_utf16 { |io| foo.bar(io, *args, **opts) }` should also be
#   equal to `str.scrub`; that is, the `IO` overload should not fail when the
#   `IO` argument uses a non-default encoding. This case is skipped if the
#   `without_iconv` flag is set.
macro assert_prints(call, str, *, file = __FILE__, line = __LINE__)
  %str = ({{ str }}).as(String)
  %file = {{ file }}
  %line = {{ line }}

  %result = {{ call }}
  %result.should be_a(String), file: %file, line: %line
  %result.should eq(%str), file: %file, line: %line

  String.build do |io|
    {% if call.receiver %}{{ call.receiver }}.{% end %}{{ call.name }}(
      io,
      {% for arg in call.args %} {{ arg }}, {% end %}
      {% if call.named_args %} {% for narg in call.named_args %} {{ narg.name }}: {{ narg.value }}, {% end %} {% end %}
    ) {{ call.block }}
  end.should eq(%str.scrub), file: %file, line: %line

  {% unless flag?(:without_iconv) %}
    string_build_via_utf16 do |io|
      {% if call.receiver %}{{ call.receiver }}.{% end %}{{ call.name }}(
        io,
        {% for arg in call.args %} {{ arg }}, {% end %}
        {% if call.named_args %} {% for narg in call.named_args %} {{ narg.name }}: {{ narg.value }}, {% end %} {% end %}
      ) {{ call.block }}
    end.should eq(%str.scrub), file: %file, line: %line
  {% end %}
end
