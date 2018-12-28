require "../../spec_helper"

{% if flag?(:darwin) %}
SupportedInts = [UInt8, UInt16, UInt32, UInt64, UInt128, Int8, Int16, Int32, Int64, Int128]

PreviewOverflowFlags = ["preview_overflow"]
{% else %}
# Skip Int128 and UInt128 on linux platforms due to compiler-rt dependency.
# PreviewOverflowFlags includes compiler_rt flag to support Int64 overflow
# detection in 32 bits platforms.
SupportedInts = [UInt8, UInt16, UInt32, UInt64, Int8, Int16, Int32, Int64]

PreviewOverflowFlags = ["preview_overflow", "compiler_rt"]
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

  describe "+ addition" do
    {% for type in SupportedInts %}
      it "raises overflow for {{type}}" do
        run(%(
          require "prelude"
          begin
            {{type}}::MAX + {{type}}.new(1)
            0
          rescue OverflowError
            1
          end
        ), flags: PreviewOverflowFlags).to_i.should eq(1)
      end

      it "raises overflow for {{type}} + Int64" do
        run(%(
          require "prelude"
          begin
            {{type}}::MAX + 1_i64
            0
          rescue OverflowError
            1
          end
        ), flags: PreviewOverflowFlags).to_i.should eq(1)
      end
    {% end %}
  end

  describe "- subtraction" do
    {% for type in SupportedInts %}
      it "raises overflow for {{type}}" do
        run(%(
          require "prelude"
          begin
            {{type}}::MIN - {{type}}.new(1)
            0
          rescue OverflowError
            1
          end
        ), flags: PreviewOverflowFlags).to_i.should eq(1)
      end

      it "raises overflow for {{type}} - Int64" do
        run(%(
          require "prelude"
          begin
            {{type}}::MIN - 1_i64
            0
          rescue OverflowError
            1
          end
        ), flags: PreviewOverflowFlags).to_i.should eq(1)
      end
    {% end %}
  end

  describe "* multiplication" do
    {% for type in SupportedInts %}
      it "raises overflow for {{type}}" do
        run(%(
          require "prelude"
          begin
            ({{type}}::MAX / {{type}}.new(2) &+ {{type}}.new(1)) * {{type}}.new(2)
            0
          rescue OverflowError
            1
          end
        ), flags: PreviewOverflowFlags).to_i.should eq(1)
      end

      it "raises overflow for {{type}} * Int64" do
        run(%(
          require "prelude"
          begin
            ({{type}}::MAX / {{type}}.new(2) &+ {{type}}.new(1)) * 2_i64
            0
          rescue OverflowError
            1
          end
        ), flags: PreviewOverflowFlags).to_i.should eq(1)
      end
    {% end %}
  end
end
