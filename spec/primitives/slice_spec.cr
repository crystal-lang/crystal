require "spec"
require "../support/number"

describe "Primitives: Slice" do
  describe ".literal" do
    {% for num in BUILTIN_NUMBER_TYPES %}
      it {{ "creates a read-only Slice(#{num})" }} do
        slice = Slice({{ num }}).literal(0, 1, 4, 9, 16, 25)
        slice.should be_a(Slice({{ num }}))
        slice.to_a.should eq([0, 1, 4, 9, 16, 25] of {{ num }})
        slice.read_only?.should be_true
      end
    {% end %}
  end
end
