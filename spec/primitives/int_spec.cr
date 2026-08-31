require "spec"
require "../support/number"
require "big"

{% for i in Int::Signed.union_types %}
  struct {{ i }}
    TEST_CASES = [MIN, MIN &+ 1, MIN &+ 2, -2, -1, 0, 1, 2, MAX &- 2, MAX &- 1, MAX] of {{ i }}
  end
{% end %}

{% for i in Int::Unsigned.union_types %}
  struct {{ i }}
    TEST_CASES = [MIN, MIN &+ 1, MIN &+ 2, MAX // 2 &- 1, MAX // 2, MAX // 2 &+ 1, MAX &- 2, MAX &- 1, MAX] of {{ i }}
  end
{% end %}

macro run_op_tests(t, u, op)
  it "overflow test #{{{ t }}} #{{{ op }}} #{{{ u }}}" do
    {{ t }}::TEST_CASES.each do |lhs|
      {{ u }}::TEST_CASES.each do |rhs|
        result = lhs.to_big_i {{ op.id }} rhs.to_big_i
        passes = {{ t }}::MIN <= result <= {{ t }}::MAX
        begin
          if passes
            (lhs {{ op.id }} rhs).should eq(lhs &{{ op.id }} rhs)
          else
            expect_raises(OverflowError) { lhs {{ op.id }} rhs }
          end
        rescue e : Spec::AssertionFailed
          raise Spec::AssertionFailed.new("#{e.message}: #{lhs} #{{{ op }}} #{rhs}", e.file, e.line)
        rescue e : OverflowError
          raise OverflowError.new("#{e.message}: #{lhs} #{{{ op }}} #{rhs}")
        end
      end
    end
  end
end

describe "Primitives: Int" do
  describe "#&+" do
    {% for int in BUILTIN_INTEGER_TYPES %}
      it "wraps around for {{ int }}" do
        ({{ int }}::MAX &+ {{ int }}.new(1)).should eq({{ int }}::MIN)
        ({{ int }}::MAX &+ 1_i64).should eq({{ int }}::MIN)
      end
    {% end %}
  end

  describe "#&-" do
    {% for int in BUILTIN_INTEGER_TYPES %}
      it "wraps around for {{ int }}" do
        ({{ int }}::MIN &- {{ int }}.new(1)).should eq({{ int }}::MAX)
        ({{ int }}::MIN &- 1_i64).should eq({{ int }}::MAX)
      end
    {% end %}
  end

  describe "#&*" do
    {% for int in BUILTIN_INTEGER_TYPES %}
      it "wraps around for {{ int }}" do
        %val{int} = {{ int }}::MAX // {{ int }}.new(2) &+ {{ int }}.new(1)
        (%val{int} &* {{ int }}.new(2)).should eq({{ int }}::MIN)
        (%val{int} &* 2_i64).should eq({{ int }}::MIN)
      end
    {% end %}
  end

  describe "#+" do
    {% for int1 in BUILTIN_INTEGER_TYPES %}
      {% for int2 in BUILTIN_INTEGER_TYPES %}
        run_op_tests {{ int1 }}, {{ int2 }}, :+
      {% end %}
    {% end %}
  end

  describe "#-" do
    {% for int1 in BUILTIN_INTEGER_TYPES %}
      {% for int2 in BUILTIN_INTEGER_TYPES %}
        run_op_tests {{ int1 }}, {{ int2 }}, :-
      {% end %}
    {% end %}
  end

  describe "#*" do
    {% for int1 in BUILTIN_INTEGER_TYPES %}
      {% for int2 in BUILTIN_INTEGER_TYPES %}
        run_op_tests {{ int1 }}, {{ int2 }}, :*
      {% end %}
    {% end %}
  end

  describe "#to_i" do
    {% for int1 in BUILTIN_INTEGER_TYPES %}
      {% for method, int2 in BUILTIN_INT_CONVERSIONS %}
        {% if int1 != int2 %}
          it {{ "raises on overflow for #{int1}##{method}" }} do
            if {{ int1 }}::MAX > {{ int2 }}::MAX
              expect_raises(OverflowError) do
                ({{ int1 }}.new!({{ int2 }}::MAX) &+ 1).{{ method }}
              end
            end

            if {{ int1 }}::MIN < {{ int2 }}::MIN
              expect_raises(OverflowError) do
                ({{ int1 }}.new!({{ int2 }}::MIN) &- 1).{{ method }}
              end
            end
          end
        {% end %}
      {% end %}
    {% end %}
  end

  describe "#to_i!" do
    it "works from negative values to unsigned types" do
      x = (-1).to_u!
      x.should be_a(UInt32)
      x.should eq(4294967295_u32)
    end

    it "works from greater values to smaller types" do
      x = 47866.to_i8!
      x.should be_a(Int8)
      x.should eq(-6_i8)
    end

    it "preserves negative sign" do
      x = (-1_i8).to_i!
      x.should be_a(Int32)
      x.should eq(-1_i32)
    end
  end

  describe "#unsafe_chr" do
    it "doesn't raise on overflow" do
      (0x41_i64 - 0x100000000_i64).unsafe_chr.should eq('A')
      0xFFFF_FFFF_0010_FFFF_u64.unsafe_chr.should eq('\u{10FFFF}')
    end
  end

  describe "#to_f" do
    it "raises on overflow for UInt128#to_f32" do
      expect_raises(OverflowError) { UInt128::MAX.to_f32 }
      expect_raises(OverflowError) { Float32::MAX.to_u128.succ.to_f32 } # Float32::MAX == 2 ** 128 - 2 ** 104
    end
  end

  describe "#to_f!" do
    it "doesn't raise on overflow for UInt128#to_f32" do
      UInt128::MAX.to_f32!.should eq(Float32::INFINITY)
      Float32::MAX.to_u128.succ.to_f32!.should eq(Float32::MAX)
    end
  end
end
