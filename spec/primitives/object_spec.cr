require "spec"

EQ_OPERATORS = %w(<= >= == != []= ===)

# NOTE: a fresh compiler is needed to define these methods as they are a syntax
# error in older versions, so for convenience the specs for `Object.delegate`
# are grouped under the primitive specs, even though no primitive methods are
# actually involved
private class Foo
  {% for op in EQ_OPERATORS %}
    def {{ op.id }}(*args, **opts)
      [args, opts]
    end

    def {{ op.id }}(*args, **opts, &)
      [args, opts, yield]
    end
  {% end %}
end

private class FooDelegate
  @foo = Foo.new

  {% for op in EQ_OPERATORS %}
    delegate {{ op.id.symbolize }}, to: @foo
  {% end %}
end

describe Object do
  describe "delegate" do
    {% for op in EQ_OPERATORS %}
      it "forwards \#{{ op.id }} with multiple parameters" do
        FooDelegate.new.{{ op.id }}(1, 2, a: 3, b: 4).should eq [{1, 2}, {a: 3, b: 4}]
      end

      it "forwards \#{{ op.id }} with multiple parameters and block parameter" do
        FooDelegate.new.{{ op.id }}(1, 2, a: 3, b: 4) { 5 }.should eq [{1, 2}, {a: 3, b: 4}, 5]
      end
    {% end %}
  end
end
