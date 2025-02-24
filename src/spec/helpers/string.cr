module Spec::Methods
  # Asserts that the given *call* and its `IO`-accepting variant both match the
  # given *expectation*, used to test string printing.
  #
  # Given a call of the form `foo.bar(*args, **opts)`, this tests the following
  # cases:
  #
  # * The call itself. Additionally this call must return a `String`.
  # * `String.build { |io| foo.bar(io, *args, **opts) }`, which constructs a
  #   `String` via an `IO` overload.
  # * `io = ...; foo.bar(io, *args, **opts); io.to_s`, where `io` is an `IO`
  #   configured to use the UTF-16 encoding, and contents written to it are
  #   decoded back into a UTF-8 `String`. This case ensures that the `IO`
  #   overload does not produce malformed UTF-8 byte sequences via a non-default
  #   encoding. This case is skipped if the `without_iconv` flag is set.
  #
  # The overload that accepts a *str* argument is usually easier to work with.
  macro assert_prints(call, *, should expectation, file = __FILE__, line = __LINE__)
    %expectation = {{ expectation }}
    %file = {{ file }}
    %line = {{ line }}

    %result = {{ call }}
    %result.should be_a(::String), file: %file, line: %line
    %result.should(%expectation, file: %file, line: %line)

    ::String.build do |io|
      {% if call.receiver %}{{ call.receiver }}.{% end %}{{ call.name }}(
        io,
        {% for arg in call.args %} {{ arg }}, {% end %}
        {% if call.named_args %} {% for narg in call.named_args %} {{ narg.name }}: {{ narg.value }}, {% end %} {% end %}
      ) {{ call.block }}
    end.should(%expectation, file: %file, line: %line)

    {% unless flag?(:without_iconv) %}
      %utf16_io = ::IO::Memory.new
      %utf16_io.set_encoding(::IO::ByteFormat::SystemEndian == ::IO::ByteFormat::LittleEndian ? "UTF-16LE" : "UTF-16BE")
      {% if call.receiver %}{{ call.receiver }}.{% end %}{{ call.name }}(
        %utf16_io,
        {% for arg in call.args %} {{ arg }}, {% end %}
        {% if call.named_args %} {% for narg in call.named_args %} {{ narg.name }}: {{ narg.value }}, {% end %} {% end %}
      ) {{ call.block }}
      %result = ::String.from_utf16(%utf16_io.to_slice.unsafe_slice_of(::UInt16))
      %result.should(%expectation, file: %file, line: %line)
    {% end %}
  end

  # Asserts that the given *call* and its `IO`-accepting variant both produce
  # the given string *str*.
  #
  # Equivalent to `assert_prints call, should: eq(str)`. *str* must be validly
  # encoded in UTF-8.
  #
  # ```
  # require "spec"
  # require "spec/helpers/string"
  #
  # it "prints integers with `Int#to_s`" do
  #   assert_prints 123.to_s, "123"
  #   assert_prints 123.to_s(16), "7b"
  # end
  # ```
  #
  # Methods that do not follow the convention of `IO`-accepting and
  # `String`-returning overloads can also be tested as long as suitable wrapper
  # methods are defined:
  #
  # ```
  # require "spec"
  # require "spec/helpers/string"
  #
  # private def fprintf(format, *args)
  #   sprintf(format, *args)
  # end
  #
  # private def fprintf(io : IO, format, *args)
  #   io.printf(format, *args)
  # end
  #
  # it "prints with `sprintf` and `IO#printf`" do
  #   assert_prints fprintf("%d", 123), "123"
  #   assert_prints fprintf("%x %b", 123, 6), "7b 110"
  # end
  # ```
  macro assert_prints(call, str, *, file = __FILE__, line = __LINE__)
    %str = ({{ str }}).as(::String)
    unless %str.valid_encoding?
      ::fail "`str` contains invalid UTF-8 byte sequences: #{%str.inspect}", file: {{ file }}, line: {{ line }}
    end
    assert_prints({{ call }}, should: eq(%str), file: {{ file }}, line: {{ line }})
  end
end
