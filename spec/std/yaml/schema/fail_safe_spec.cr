require "spec"
require "yaml"

private def it_parses(string, expected, file = __FILE__, line = __LINE__)
  it "parses #{string.inspect}", file, line do
    YAML::Schema::FailSafe.parse(string).should eq(expected)
  end
end

private def it_raises_on_parse(string, message, file = __FILE__, line = __LINE__)
  it "raises on parse #{string.inspect}", file, line do
    expect_raises(YAML::ParseException, message) do
      YAML::Schema::FailSafe.parse(string)
    end
  end
end

private def it_parses_all(string, expected, file = __FILE__, line = __LINE__)
  it "parses all #{string.inspect}", file, line do
    YAML::Schema::FailSafe.parse_all(string).should eq(expected)
  end
end

private def it_raises_on_parse_all(string, message, file = __FILE__, line = __LINE__)
  it "raises on parse all #{string.inspect}", file, line do
    expect_raises(YAML::ParseException, message) do
      YAML::Schema::FailSafe.parse_all(string)
    end
  end
end

describe YAML::Schema::FailSafe do
  # parse
  it_parses "123", "123"
  it_parses %(
    context:
        replace_me: "Yes please!"
  ), {"context" => {"replace_me" => "Yes please!"}}
  it_parses %(
    first:
      document:

    second:
      document:
  ), {"first" => {"document" => ""}, "second" => {"document" => ""}}
  it_raises_on_parse %(
    this: "gives"
      an: "error"
  ), "did not find expected key at line 3, column 7, while parsing a block mapping at line 2, column 5"
  it_raises_on_parse ":", "did not find expected key at line 1, column 1, while parsing a block mapping at line 1, column 1"

  # parse_all
  it_parses "321", "321"
  it_parses_all %(
    context:
        replace_me: "Yes please!"
  ), [{"context" => {"replace_me" => "Yes please!"}}]
  it_parses_all %(
    foo:
      bar: 123

    bar:
      foo: 321
  ), [{"foo" => {"bar" => "123"}, "bar" => {"foo" => "321"}}]
  it_raises_on_parse_all %(
    this: "raises"
      an: "yaml"
        parse: "exception"
  ), "did not find expected key at line 3, column 7, while parsing a block mapping at line 2, column 5"
  it_raises_on_parse_all ":", "did not find expected key at line 1, column 1, while parsing a block mapping at line 1, column 1"
end
