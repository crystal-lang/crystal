require "spec"
require "../support/finalize"
require "../support/interpreted"

private class Inner
  include FinalizeCounter

  def initialize(@key : String)
  end
end

private class Outer
  @inner = Inner.new("reference-storage")
end

describe "Primitives: pointer" do
  describe ".malloc" do
    pending_interpreted "is non-atomic for ReferenceStorage(T) if T is non-atomic (#14692)" do
      FinalizeState.reset
      outer = Outer.unsafe_construct(Pointer(ReferenceStorage(Outer)).malloc(1))
      GC.collect
      FinalizeState.count("reference-storage").should eq(0)
    end
  end
end
