{% skip_file unless compare_versions(Crystal::VERSION, "0.35.0-0") > 0 %}

require "big"
require "spec"
require "../support/number"

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

describe "overflow" do
  {% for t in BUILTIN_INTEGER_TYPES %}
    {% for u in BUILTIN_INTEGER_TYPES %}
      run_op_tests {{t}}, {{u}}, :+
      run_op_tests {{t}}, {{u}}, :-
      run_op_tests {{t}}, {{u}}, :*
    {% end %}
  {% end %}
end
