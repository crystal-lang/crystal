require "../../spec_helper"

{% if flag?(:darwin) %}
  SupportedInts            = [UInt8, UInt16, UInt32, UInt64, UInt128, Int8, Int16, Int32, Int64, Int128]
  SupportedIntsConversions = {
    to_i8: Int8, to_i16: Int16, to_i32: Int32, to_i64: Int64, to_i128: Int128,
    to_u8: UInt8, to_u16: UInt16, to_u32: UInt32, to_u64: UInt64, to_u128: UInt128,
  }
{% else %}
  # Skip Int128 and UInt128 on linux platforms due to compiler-rt dependency.
  # PreviewOverflowFlags includes compiler_rt flag to support Int64 overflow
  # detection in 32 bits platforms.
  SupportedInts            = [UInt8, UInt16, UInt32, UInt64, Int8, Int16, Int32, Int64]
  SupportedIntsConversions = {
    to_i8: Int8, to_i16: Int16, to_i32: Int32, to_i64: Int64,
    to_u8: UInt8, to_u16: UInt16, to_u32: UInt32, to_u64: UInt64,
  }
{% end %}

describe "Code gen: arithmetic primitives" do
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
          ({{type}}::MAX // {{type}}.new(2) &+ {{type}}.new(1)) &* {{type}}.new(2) == {{type}}::MIN
        )).to_b.should be_true
      end

      it "wrap around for {{type}} + Int64" do
        run(%(
          require "prelude"
          ({{type}}::MAX // {{type}}.new(2) &+ {{type}}.new(1)) &* 2_i64 == {{type}}::MIN
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
        )).to_i.should eq(1)
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
        )).to_i.should eq(1)
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
        )).to_i.should eq(1)
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
        )).to_i.should eq(1)
      end
    {% end %}
  end

  describe "* multiplication" do
    {% for type in SupportedInts %}
      it "raises overflow for {{type}}" do
        run(%(
          require "prelude"
          begin
            ({{type}}::MAX // {{type}}.new(2) &+ {{type}}.new(1)) * {{type}}.new(2)
            0
          rescue OverflowError
            1
          end
        )).to_i.should eq(1)
      end

      it "raises overflow for {{type}} * Int64" do
        run(%(
          require "prelude"
          begin
            ({{type}}::MAX // {{type}}.new(2) &+ {{type}}.new(1)) * 2_i64
            0
          rescue OverflowError
            1
          end
        )).to_i.should eq(1)
      end
    {% end %}
  end

  describe ".to_i conversions" do
    {% for method, path_type in SupportedIntsConversions %}
      {% type = path_type.resolve %}

      {% if ![UInt64, Int128, UInt128].includes?(type) %}
        it "raises overflow if greater than {{type}}::MAX" do
          run(%(
            require "prelude"

            v = UInt64.new({{type}}::MAX) + 1_u64

            begin
              v.{{method}}
              0
            rescue OverflowError
              1
            end
          )).to_i.should eq(1)
        end
      {% end %}

      {% if ![UInt128].includes?(type) && SupportedInts.includes?(UInt128) %}
        it "raises overflow if greater than {{type}}::MAX (using UInt128)" do
          run(%(
            require "prelude"

            v = UInt128.new({{type}}::MAX) + 1_u128

            begin
              v.{{method}}
              0
            rescue OverflowError
              1
            end
          )).to_i.should eq(1)
        end
      {% end %}

      {% if ![Int64, Int128, UInt128].includes?(type) %}
        it "raises overflow if lower than {{type}}::MIN" do
          run(%(
            require "prelude"

            v = Int64.new({{type}}::MIN) - 1_i64

            begin
              v.{{method}}
              0
            rescue OverflowError
              1
            end
          )).to_i.should eq(1)
        end
      {% end %}

      {% if [UInt16, UInt32, UInt64].includes?(type) %}
        it "raises overflow if lower than {{type}}::MIN (#9997)" do
          run(%(
            require "prelude"

            v = -1_i8

            begin
              v.{{method}}
              0
            rescue OverflowError
              1
            end
          )).to_i.should eq(1)
        end
      {% end %}

      {% if ![Int128].includes?(type) && SupportedInts.includes?(Int128) %}
        it "raises overflow if lower than {{type}}::MIN (using Int128)" do
          run(%(
            require "prelude"

            v = Int128.new({{type}}::MIN) - 1_i128

            begin
              v.{{method}}
              0
            rescue OverflowError
              1
            end
          )).to_i.should eq(1)
        end
      {% end %}

      {% for float_type in [Float32, Float64] %}
        it "raises overflow if greater than {{type}}::MAX (from {{float_type}})" do
          {% if type == UInt128 && float_type == Float32 %}
            # since `Float32::MAX < UInt128::MAX`, we have to ensure that the
            # former does not overflow while positive infinity does
            run(%(
              require "prelude"

              begin
                Float32::INFINITY.to_u128
                0
              rescue OverflowError
                begin
                  Float32::MAX.to_u128
                  1
                rescue OverflowError
                  2
                end
              end
            )).to_i.should eq(1)
          {% else %}
            run(%(
              require "prelude"

              v = {{float_type}}.new({{type}}::MAX) * {{float_type}}.new(1.5)

              begin
                v.{{method}}
                0
              rescue OverflowError
                1
              end
            )).to_i.should eq(1)
          {% end %}
        end

        {% if [Int64, Int128, UInt64].includes?(type) ||
                (type == UInt128 && float_type == Float64) ||
                ([Int32, UInt32].includes?(type) && float_type == Float32) %}
          it "raises overflow if equal to {{type}}::MAX (from {{float_type}})" do
            run(%(
              require "prelude"

              v = {{float_type}}.new({{type}}::MAX)

              begin
                v.{{method}}
                0
              rescue OverflowError
                1
              end
            )).to_i.should eq(1)
          end
        {% end %}

        it "raises overflow if lower than {{type}}::MIN (from {{float_type}})" do
          run(%(
            require "prelude"

            v = {{float_type}}.new({{type}}::MIN) * {{float_type}}.new(1.5) - {{float_type}}.new(1.0)

            begin
              v.{{method}}
              0
            rescue OverflowError
              1
            end
          )).to_i.should eq(1)
        end
      {% end %}
    {% end %}

    {% begin %}
      it "raises overflow if not a number" do
        run(%(
          require "prelude"

          results = 0_u64

          {% for float_type in [Float32, Float64] %}
            {% for method, path_type in SupportedIntsConversions %}
              results <<= 1
              begin
                {{float_type}}::NAN.{{method}}
                results |= 1
              rescue OverflowError
              end
            {% end %}
          {% end %}

          results
          )).to_u64.should eq(0)
      end
    {% end %}
  end

  describe ".to_f conversions" do
    {% if SupportedInts.includes?(Int128) %}
      it "raises overflow if greater than Float32::MAX (from UInt128)" do
        run(%(
          require "prelude"

          begin
            UInt128::MAX.to_f32
            0
          rescue OverflowError
            1
          end
        )).to_i.should eq(1)
      end
    {% end %}

    it "raises overflow if greater than Float32::MAX" do
      run(%(
        require "prelude"

        v = Float64.new(Float32::MAX) * 1.5_f64

        begin
          v.to_f32
          0
        rescue OverflowError
          1
        end
      )).to_i.should eq(1)
    end

    it "raises overflow if lower than Float32::MIN" do
      run(%(
        require "prelude"

        v = Float64.new(Float32::MIN) * 1.5_f64

        begin
          v.to_f32
          0
        rescue OverflowError
          1
        end
      )).to_i.should eq(1)
    end
  end
end
