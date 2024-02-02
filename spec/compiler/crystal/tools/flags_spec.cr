require "../../../spec_helper"
include Crystal

private def parse_flags(source)
  Crystal::Command::FlagsVisitor.new.tap do |visitor|
    Parser.parse(source).accept(visitor)
  end
end

describe Crystal::Command::FlagsVisitor do
  it "different flags" do
    visitor = parse_flags <<-CRYSTAL
      {%
        flag?(:foo)
        flag?("bar")
        flag?(1)
        flag?(true)
      %}
      CRYSTAL
    visitor.flag_names.should eq %w[1 bar foo true]
  end

  it "unique flags" do
    visitor = parse_flags <<-CRYSTAL
      {%
        flag?(:foo)
        flag?("foo")
        flag?(:foo)
      %}
      CRYSTAL
    visitor.flag_names.should eq %w[foo]
  end

  it "only macro" do
    visitor = parse_flags <<-CRYSTAL
      flag?(:flag)
      f.flag?(:foo)
      F.flag?(:bar)
      {% f.flag?(:baz) %}
      {% f.flag?(:qux, other: true) %}
      CRYSTAL
    visitor.flag_names.should eq %w[]
  end
end
