require "../../../spec_helper"
include Crystal

private def assert_coverage(code, expected_coverage, *, expected_error : String? = nil, focus : Bool = false, spec_file = __FILE__, spec_line = __LINE__)
  it focus: focus, file: spec_file, line: spec_line do
    processor = MacroCoverageProcessor.new

    compiler = Compiler.new
    compiler.prelude = "empty"
    compiler.no_codegen = true
    compiler.compile_configure_program(Compiler::Source.new(".", code), "fake-no-build") do |program|
      processor.configure program
    end

    processor.excludes << Path[Dir.current].to_posix.to_s
    processor.includes << "."

    hits = processor.compute_coverage

    unless hits = hits["."]?
      fail "Failed to generate coverage", file: spec_file, line: spec_line
    end

    coverage_exception = processor.coverage_interrupt_exception

    if expected_error
      err = coverage_exception.should_not be_nil, file: spec_file, line: spec_line
      err.inspect_with_backtrace.should contain(expected_error), file: spec_file, line: spec_line
    else
      coverage_exception.should be_nil, file: spec_file, line: spec_line
    end

    hits.should eq(expected_coverage), file: spec_file, line: spec_line
  end
end

describe "macro_code_coverage" do
  assert_coverage <<-'CR', {1 => 1}
    {{ "foo" }}
    CR

  assert_coverage <<-'CR', {2 => 1, 3 => 1}, expected_error: "undefined macro method 'NumberLiteral#sdfds'"
    {%
      a = 1
      b = 2.sdfds
      c = 3
    %}
    CR

  assert_coverage <<-'CR', {1 => "1/2"}, expected_error: "oh noes im an error"
    {{ true ? raise("oh noes im an error") : 0 }}
    CR

  assert_coverage <<-'CR', {1 => "1/2"}
    {{ true ? 1 : 0 }}
    CR

  assert_coverage <<-'CR', {1 => 1, 2 => "1/2"}
    {% begin %}
      {{true ? 1 : 0}} + {{2}}
    {% end %}
    CR

  assert_coverage <<-'CR', {1 => "1/3"}
    {{ true ? 1 : x == 2 ? 2 : 3 }}
    CR

  assert_coverage <<-'CR', {2 => "2/3"}
    macro test(x)
    {{ x == 1 ? 1 : x == 2 ? 2 : 3 }}
    end

    test(1)
    test(2)
    CR

  assert_coverage <<-'CR', {2 => "3/3"}
    macro test(x)
    {{ x == 1 ? 1 : x == 2 ? 2 : 3 }}
    end

    test(1)
    test(2)
    test(3)
    CR

  assert_coverage <<-'CR', {2 => "3/3"}
    macro test(x)
      {{ x == 1 ? 1 : x == 2 ? 2 : 3 }}
    end

    test(1)
    test(2)
    test(3)
    test(4)
    CR

  # 1/2 since the raise would prevent the 2nd execution
  assert_coverage <<-'CR', {2 => "1/2"}, expected_error: "oh noes im an error"
    macro test(x)
      {{ 1 == x ? raise("oh noes im an error") : 0 }}
    end

    test(1)
    test(2)
    CR

  assert_coverage <<-'CR', {2 => "2/2"}, expected_error: "oh noes im an error"
    macro test(x)
      {{ 1 == x ? raise("oh noes im an error") : 0 }}
    end

    test(2)
    test(1)
    CR

  assert_coverage <<-'CR', {1 => "1/2"}
    {% tags = (tags = (1 + 1)) ? tags : nil %}
    CR

  assert_coverage <<-'CR', {1 => 1, 2 => "1/2", 3 => 3}
    {% for type in [1, 2, 3] %}
      {% tags = (tags = type) ? tags : nil %}
      {% tags %}
    {% end %}
    CR

  assert_coverage <<-'CR', {1 => "1/2"}
    {% if true %}1{% else %}0{% end %}
    CR

  assert_coverage <<-'CR', {1 => "1/3"}
    {% if false %}1{% elsif false %}2{% else %}3{% end %}
    CR

  assert_coverage <<-'CR', {1 => "1/6"}
    {% if false %}{% if false %}1{% else %}2{% end %}{% elsif false %}3{% else %}{% if false %}4{% elsif false %}5{% else %}6{% end %}{% end %}
    CR

  assert_coverage <<-'CR', {1 => "1/6"}
    {% if false; if false; 1; else 2; end; elsif false; 3; else; if false; 4; elsif false; 5; else 6; end; end %}
    CR

  assert_coverage <<-'CR', {1 => "1/5"}
    {% unless false; if false; 1; else 2; end; else; if false; 4; elsif false; 5; else 6; end; end %}
    CR

  assert_coverage <<-'CR', {1 => 1}, expected_error: "oh noes im an error"
    {% raise "oh noes im an error" %}
    {{ 2 }}
    CR

  assert_coverage <<-'CR', {1 => 1, 2 => "1/2", 3 => 1}
    {% 1 %}
    {% 2 if false %}
    {% 3 %}
    CR

  assert_coverage <<-'CR', {1 => 1, 2 => "1/2", 3 => 1}
    {% 1 %}
    {% 2 if true %}
    {% 3 %}
    CR

  assert_coverage <<-'CR', {1 => 1, 2 => "1/2", 3 => 1}
    {% 1 %}
    {% 2 unless true %}
    {% 3 %}
    CR

  assert_coverage <<-'CR', {1 => 1, 2 => "1/2", 3 => 1}
    {% 1 %}
    {% 2 unless false %}
    {% 3 %}
    CR

  assert_coverage <<-'CR', {2 => "1/2"}
    macro test(v)
      {{3 if v == 1}}
    end

    test 0
    test 2
    CR

  assert_coverage <<-'CR', {2 => "2/2"}
    macro test(v)
      {{3 if v == 1}}
    end

    test 2
    test 1
    CR

  assert_coverage <<-'CR', {2 => "2/2"}
    macro test(v)
      {{3 if v == 1}}
    end

    test 1
    test 2
    test 1
    CR

  assert_coverage <<-'CR', {2 => 1, 3 => "1/2"}, expected_error: "oh noes im an error"
    {%
      if true
        raise "oh noes im an error" if Int32 <= Number
      end
    %}
    CR

  assert_coverage <<-'CR', {4 => 1, 5 => "1/2"}
    macro finished
      {% verbatim do %}
        {%
          if true
            a = 1 if true
          end
        %}
      {% end %}
    end
    CR

  assert_coverage <<-'CR', {4 => 1, 5 => 1, 7 => 0}, expected_error: "oh noes im an error"
    macro finished
      {% verbatim do %}
        {%
          if true
            raise "oh noes im an error"
          else
            123
          end
        %}
      {% end %}
    end
    CR

  assert_coverage <<-'CR', {1 => 1, 2 => 0, 4 => 1}
    {% unless true %}
      {{0}}
    {% else %}
      {{1}}
    {% end %}
    CR

  assert_coverage <<-'CR', {1 => 1, 2 => 1, 4 => 0}
    {% unless false %}
      {{0}}
    {% else %}
      {{1}}
    {% end %}
    CR

  assert_coverage <<-'CR', {2 => 1, 4 => 1}
    {%
      a, b, c = {1, 2, 3}

      a + b + c
    %}
    CR

  assert_coverage <<-'CR', {2 => 2, 6 => 1, 10 => 1}
    macro test(&)
      {{yield}}
    end

    test do
      {{2 + 1}}
    end

    test do
      {{9 + 12}}
    end
    CR

  assert_coverage <<-'CR', {2 => 2, 3 => "1/2", 4 => 2, 8 => 0, 13 => 0}
    macro test(&)
      {{ 1 + 1 }}
      {{yield if false}}
      {{ 2 + 2 }}
    end

    test do
      {{2 + 1}}
      {{1 + 2}}
    end

    test do
      {{4 + 5}}
      {{5 + 4}}
    end
    CR

  assert_coverage <<-'CR', {1 => 1, 2 => 1, 3 => 3, 4 => 1, 5 => 2, 6 => 0, 8 => 2}
    {% begin %}
      {% for v in {1, 2, 3} %}
        {% if v == 2 %}
          {{v * 2}}
        {% elsif v > 5 %}
          {{v * 5}}
        {% else %}
          {{v}}
        {% end %}
      {% end %}
    {% end %}
    CR

  assert_coverage <<-'CR', {1 => 1, 2 => 1, 4 => 2, 5 => 2, 7 => 2}
    {% begin %}
      {% for v in [1, 2] %}
        {%
          0 + (10 * 10)
          20 * 20
        %}
        {% 30 * 30 %}
      {% end %}
    {% end %}
    CR

  assert_coverage <<-'CR', {1 => 1, 2 => 1, 4 => "1/2", 5 => 2, 7 => 2}
    {% begin %}
      {% for v in [1, 2] %}
        {%
          0 + (10 * 10) if false
          20 * 20
        %}
        {% 30 * 30 %}
      {% end %}
    {% end %}
    CR

  assert_coverage <<-'CR', {4 => 1, 5 => 1}
    macro finished
      {% verbatim do %}
        {%
          10 * 10
          10 * 20
        %}
      {% end %}
    end
    CR

  assert_coverage <<-'CR', {1 => 1, 3 => 0}
    {% if false %}
      # foo
      {% 1 + 1 %}
    {% end %}
    CR

  assert_coverage <<-'CR', {1 => 1, 2 => 1, 3 => 2, 4 => 1, 6 => 1}
    {% begin %}
      {% for vals in [[] of Int32, [1]] %}
        {% if vals.empty? %}
          {{1 + 1}}
        {% else %}
          {{2 + 2}}
        {% end %}
      {% end %}
    {% end %}
    CR

  assert_coverage <<-'CR', {3 => 1, 6 => 1, 7 => 1}
    macro finished
      {% verbatim do %}
        {% 10 * 10 %}

        {%
          20 * 20
          30 * 30
        %}
      {% end %}
    end
    CR

  assert_coverage <<-'CR', {4 => 1, 7 => 1}
    macro finished
      {% verbatim do %}
        {%
          10 * 10

          # Foo
          10 * 20
        %}
      {% end %}
    end
    CR

  assert_coverage <<-'CR', {4 => 1, 8 => 1, 10 => 1}
    macro finished
      {% verbatim do %}
        {%
          10 * 10

          # Foo

          10 * 20

          10 * 10
        %}
      {% end %}
    end
    CR

  assert_coverage <<-'CR', {4 => 1, 8 => 1, 9 => 1, 13 => 1, 16 => 1, 17 => 1, 22 => 1}
    macro finished
      {% verbatim do %}
        {%
          10

          # Foo

          20
          30

          # Bar

          40
        %}
        {%
          50
          60
        %}


        {%
          70
        %}
      {% end %}
    end
    CR

  assert_coverage <<-'CR', {4 => 1, 5 => 3, 6 => 1, 7 => 2, 8 => 1, 10 => 1, 13 => 3}
    macro finished
      {% verbatim do %}
        {%
          [0, 1, 2].each do |val|
            str = if val >= 2
                    "greater or equal to 2"
                  elsif val == 1
                    "equals 1"
                  else
                    "other"
                  end

            "Got: " + str
          end
        %}
      {% end %}
    end
    CR

  assert_coverage <<-'CR', {4 => 1, 6 => 1, 7 => 1, 8 => 1, 9 => 1}
    macro finished
      {% verbatim do %}
        {%
          data = {__nil: nil}

          data["foo"] = {
            id: 1, active: true,
            name: "foo".upcase,
            pie: 3.14,
          }
        %}
      {% end %}
    end
    CR

  assert_coverage <<-'CR', {4 => 1, 5 => 1, 7 => 1, 8 => 1, 9 => 1, 10 => 1, 11 => 1, 12 => 1}
    macro finished
      {% verbatim do %}
        {%
          data = {__nil: nil}
          num = 4

          data["foo"] = {
            var: num,
            hash_literal: {} of Nil => Nil,
            named_tuple_literal: {id: 10},
            array_literal: [] of Nil,
            tuple_literal: {1, 2, 3},
          }
        %}
      {% end %}
    end
    CR

  assert_coverage <<-'CR', {3 => 1}
    macro finished
      {% verbatim do %}
        {% [1, 2, 3].find(&.+.==(2)) %}
      {% end %}
    end
    CR

  assert_coverage <<-'CR', {3 => 1, 4 => 0}
    macro finished
      {% verbatim do %}
        {% if false %}
          {% raise "Oh noes" %}
        {% end %}
      {% end %}
    end
    CR

  assert_coverage <<-'CR', {4 => 1, 7 => 1}
    macro finished
      {% verbatim do %}
        {%
          if true
            # Some comment
            # Another comment
            10
          end
        %}
      {% end %}
    end
    CR

  assert_coverage <<-'CR', {2 => 1, 5 => 1}
    {%
      if true
        # Some comment
        # Another comment
        10
      end
    %}
    CR

  assert_coverage <<-'CR', {4 => "1/2"}
    macro finished
      {% verbatim do %}
        {%
          pp 1 if false
        %}
      {% end %}
    end
    CR

  assert_coverage <<-'CR', {2 => 1, 4 => 0}
    macro test(v)
      {% if v > 1 %}
        {%
          pp v.stringify
        %}
      {% end %}
    end

    test 1
    CR

  assert_coverage <<-'CR', {2 => 1, 4 => 0}
    macro test(v)
      {% if v > 1 %}
        {%
          val = v.stringify

          pp val
        %}
      {% end %}
    end

    test 1
    CR

  assert_coverage <<-'CR', {2 => 1, 4 => 1, 6 => 1, 9 => 1, 10 => 1, 13 => 0}
    macro test(v)
      {% if v > 1 %}
        {%
          val = v.stringify

          val = "foo"
        %}

        {% if v == 2 %}
          {{v}}
        {% else %}
          {%
            pp v * 2
          %}
        {% end %}
      {% end %}
    end

    test 2
    CR

  assert_coverage <<-'CR', {1 => 1, 2 => 0}
    {% for val in [] of Nil %}
      {% pp 1 %}
    {% end %}
    CR

  assert_coverage <<-'CR', {1 => 1, 2 => 0}
    {% for val in {} of Nil => Nil %}
      {% pp 1 %}
    {% end %}
    CR

  assert_coverage <<-'CR', {1 => 1, 2 => 0}
    {% for val in (0...0) %}
      {% pp 1 %}
    {% end %}
    CR

  assert_coverage <<-'CR', {2 => 1, 3 => 0}
    {%
      ([] of Nil).each do |v|
        pp v
        pp 123
      end
    %}
    CR

  assert_coverage <<-'CR', {2 => 1, 3 => 0}
    {%
      ([] of Nil).each do |(a, b, c)|
        pp v
        pp 123
      end
    %}
    CR

  assert_coverage <<-'CR', {2 => 1, 3 => 0}
    {%
      ({} of Nil => Nil).each do |v|
        pp v
        pp 123
      end
    %}
    CR

  assert_coverage <<-'CR', {2 => 1, 3 => 0}
    {%
      (0...0).each do |v|
        pp v
        pp 123
      end
    %}
    CR

  assert_coverage <<-'CR', {2 => 1, 3 => 0}
    {%
      ([] of Nil).map do |v|
        pp v
        pp 123
      end
    %}
    CR

  assert_coverage <<-'CR', {2 => 1, 3 => 0}
    {%
      ([] of Nil).find do |v|
        v > 1
      end
    %}
    CR

  assert_coverage <<-'CR', {2 => "1/3"}
    {%
      v = false || true || false
    %}
    CR

  assert_coverage <<-'CR', {2 => "2/2"}
    {%
      true && false
    %}
    CR

  assert_coverage <<-'CR', {2 => "1/3"}
    {%
      v = 1 || 2 || raise "Oh noes"
    %}
    CR

  assert_coverage <<-'CR', {2 => "1/3"}
    macro test(one, two, three)
      {{one || two || three}}
    end

    test true, false, false
    CR

  assert_coverage <<-'CR', {2 => "2/3"}
    macro test(one, two, three)
      {{one || two || three}}
    end

    test true, false, false
    test false, true, false
    CR

  assert_coverage <<-'CR', {2 => "3/3"}
    macro test(one, two, three)
      {{one || two || three}}
    end

    test true, false, false
    test false, true, false
    test false, false, true
    CR

  assert_coverage <<-'CR', {2 => "3/3"}
    {%
      v = 1 && 2 && 3
    %}
    CR

  assert_coverage <<-'CR', {2 => "3/3"}, expected_error: "oh noes im an error"
    {%
      v = 1 && 2 && raise "oh noes im an error"
    %}
    CR

  assert_coverage <<-'CR', {4 => 1, 6 => 1, 10 => 1}
    macro finished
      {% verbatim do %}
        {%
          ({"a" => "b"} of Nil => Nil).each do |k, v|
            # stuff and things
            k + v

            # foo bar

            k + v
          end
        %}
      {% end %}
    end
    CR

  assert_coverage <<-'CR', {4 => 1, 6 => 1, 7 => 0, 11 => 1, 12 => 1, 15 => 1}
    macro finished
      {% verbatim do %}
        {%
          a = nil

          if false
            a = 1

            # Scalar value
          else
            a = 4
            b = 5
          end

          a
        %}
      {% end %}
    end
    CR

  assert_coverage <<-'CR', {5 => 1, 6 => 1, 7 => 1, 8 => 1}
    macro finished
      {% verbatim do %}
        {%
          {
            type:     String,
            services: [4, 1, 12]
              .sort_by { |v| v }
              .map { |v| v },
          }
        %}
      {% end %}
    end
    CR

  assert_coverage <<-'CR', {4 => 1, 5 => 1, 6 => 1}
    macro finished
      {% verbatim do %}
        {%
        val = "foo"
                .strip
                .strip.strip
        %}
      {% end %}
    end
    CR

  assert_coverage <<-'CR', {4 => 1, 6 => 1, 7 => 0, 9 => 1}
    macro finished
      {% verbatim do %}
        {%
          if true &&
              (
                true ||
                false
              )
            1
          end
        %}
      {% end %}
    end
    CR

  assert_coverage <<-'CR', {4 => 1, 5 => 1, 6 => 0, 8 => 1, 9 => 1}
    macro finished
      {% verbatim do %}
        {%
          if (
              true ||
              false
            ) &&
            true
            1
          end
        %}
      {% end %}
    end
    CR

  assert_coverage <<-'CR', {4 => 1, 5 => 1, 6 => 1, 8 => 0, 9 => 0}
    macro finished
      {% verbatim do %}
        {%
          if (
              false ||
              false
            ) &&
            true
            1
          end
        %}
      {% end %}
    end
    CR

  assert_coverage <<-'CR', {4 => "1/2", 5 => 1, 6 => 1}
    macro finished
      {% verbatim do %}
        {%
          if (true || false) &&
            true
            1
          end
        %}
      {% end %}
    end
    CR

  assert_coverage <<-'CR', {4 => "2/2", 5 => 0, 6 => 0}
    macro finished
      {% verbatim do %}
        {%
          if (true && false) &&
            true
            1
          end
        %}
      {% end %}
    end
    CR

  assert_coverage <<-'CR', {4 => 1, 6 => 1, 7 => 0, 9 => 1}
    macro finished
      {% verbatim do %}
        {%
          if (type = Number) &&
              (
                Int32 <= type ||
                false
              )
            1
          end
        %}
      {% end %}
    end
    CR

  assert_coverage <<-'CR', {4 => 1, 6 => 1, 7 => 0, 9 => 1}
    macro finished
      {% verbatim do %}
        {%
          if (type = Number) &&
              (
                Int32 <= type ||
                (type < Int && Int8 <= Number)
              )
            1
          end
        %}
      {% end %}
    end
    CR

  assert_coverage <<-'CR', {2 => 1, 4 => 0, 7 => 0}
    {%
      if (type = nil) &&
          (
            Int32 <= type ||
            (type < Int && Int8 <= Number)
          )
        id
      end
    %}
    CR
end
