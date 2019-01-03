require "../../spec_helper"

{% if flag?(:bits64) %}
SupportedInts = [UInt8, UInt16, UInt32, UInt64, UInt128, Int8, Int16, Int32, Int64, Int128]
{% else %}
# skip Int128 and UInt128 on 32 bits platforms
SupportedInts = [UInt8, UInt16, UInt32, UInt64, Int8, Int16, Int32, Int64]
{% end %}

describe "Code gen: arithmetics primitives" do
  describe "&+ addition" do
    {% for type in SupportedInts %}
      it "wrap around for {{type}}" do
        run(%(
          require "prelude"
          {{type}}::MAX &+ {{type}}.new(1) == {{type}}::MIN
        )).to_b.should be_true
      end

      it "wrap around for {{type}} + Int64" do
        run(%(
          require "prelude"
          {{type}}::MAX &+ 1_i64 == {{type}}::MIN
        )).to_b.should be_true
      end
    {% end %}
  end

  describe "&- subtraction" do
    {% for type in SupportedInts %}
      it "wrap around for {{type}}" do
        run(%(
          require "prelude"
          {{type}}::MIN &- {{type}}.new(1) == {{type}}::MAX
        )).to_b.should be_true
      end

      it "wrap around for {{type}} - Int64" do
        run(%(
          require "prelude"
          {{type}}::MIN &- 1_i64 == {{type}}::MAX
        )).to_b.should be_true
      end
    {% end %}
  end

  describe "&* multiplication" do
    {% for type in SupportedInts %}
      it "wrap around for {{type}}" do
        run(%(
          require "prelude"
          ({{type}}::MAX / {{type}}.new(2) &+ {{type}}.new(1)) &* {{type}}.new(2) == {{type}}::MIN
        )).to_b.should be_true
      end

      it "wrap around for {{type}} + Int64" do
        run(%(
          require "prelude"
          ({{type}}::MAX / {{type}}.new(2) &+ {{type}}.new(1)) &* 2_i64 == {{type}}::MIN
        )).to_b.should be_true
      end
    {% end %}
  end
end
