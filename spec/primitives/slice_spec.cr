require "spec"
require "../support/number"
require "../support/interpreted"

private module Foo
  def self.foo
    Slice.literal(1)
  end
end

describe "Primitives: Slice" do
  describe ".literal" do
    {% for num in BUILTIN_NUMBER_TYPES %}
      it {{ "creates a read-only Slice(#{num})" }} do
        slice = Slice({{ num }}).literal(0, 1, 4, 9, 16, 25)
        slice.should be_a(Slice({{ num }}))
        slice.to_a.should eq([0, 1, 4, 9, 16, 25] of {{ num }})
        slice.read_only?.should be_true
      end

      # TODO: these should probably return the same pointers
      it "creates multiple literals" do
        slice1 = Slice({{ num }}).literal(1, 2, 3)
        slice2 = Slice({{ num }}).literal(1, 2, 3)
        slice1.should eq(slice2)
      end
    {% end %}

    {% for num, suffix in BUILTIN_NUMBER_SUFFIXES %}
      pending_interpreted {{ "creates a read-only Slice of #{num}" }} do
        slice = Slice.literal(1_{{ suffix.id }}, 2_{{ suffix.id }}, 3_{{ suffix.id }})
        slice.should be_a(Slice({{ num }}))
        slice.to_a.should eq([1, 2, 3] of {{ num }})
        slice.read_only?.should be_true
      end
    {% end %}

    it "links against slice literal from a different LLVM module" do
      Foo.foo.should eq(Slice.literal(1))
    end
  end
end
