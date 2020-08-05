{% skip_file unless compare_versions(Crystal::VERSION, "0.35.0-0") > 0 %}

require "big"
require "spec"

{% for i in Int::Signed.union_types %}
  struct {{i}}
    TEST_CASES = [MIN, MIN &+ 1, MIN &+ 2, -1, 0, 1, MAX &- 2, MAX &- 1, MAX] of {{i}}
  end
{% end %}

{% for i in Int::Unsigned.union_types %}
  struct {{i}}
    TEST_CASES = [MIN, MIN &+ 1, MIN &+ 2, MAX &- 2, MAX &- 1, MAX] of {{i}}
  end
{% end %}

macro run_op_tests(t, u, op)
  it "overflow test #{{{t}}} #{{{op}}} #{{{u}}}" do
    {{t}}::TEST_CASES.each do |lhs|
      {{u}}::TEST_CASES.each do |rhs|
        result = lhs.to_big_i {{op.id}} rhs.to_big_i
        passes = {{t}}::MIN <= result <= {{t}}::MAX
        begin
          if passes
            (lhs {{op.id}} rhs).should eq(lhs &{{op.id}} rhs)
          else
            expect_raises(OverflowError) { lhs {{op.id}} rhs }
          end
        rescue e : Spec::AssertionFailed
          raise Spec::AssertionFailed.new("#{e.message}: #{lhs} #{{{op}}} #{rhs}", e.file, e.line)
        rescue e : OverflowError
          raise OverflowError.new("#{e.message}: #{lhs} #{{{op}}} #{rhs}")
        end
      end
    end
  end
end

{% if flag?(:darwin) %}
  private OVERFLOW_TEST_TYPES = [Int8, UInt8, Int16, UInt16, Int32, UInt32, Int64, UInt64, Int128, UInt128]
{% else %}
  private OVERFLOW_TEST_TYPES = [Int8, UInt8, Int16, UInt16, Int32, UInt32, Int64, UInt64]
{% end %}

describe "overflow" do
  {% for t in OVERFLOW_TEST_TYPES %}
    {% for u in OVERFLOW_TEST_TYPES %}
      run_op_tests {{t}}, {{u}}, :+
      run_op_tests {{t}}, {{u}}, :-
      run_op_tests {{t}}, {{u}}, :*
    {% end %}
  {% end %}
end
