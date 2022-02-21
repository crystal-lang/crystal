require "spec"
require "crystal/pointer_linked_list.cr"

private struct TestedObject
  include Crystal::PointerLinkedList::Node

  property value : Int32

  def initialize(@value : Int32)
  end
end

private module ExpectOrderHelper
  macro by_next(*vars)
    {% sz = vars.size %}
    {% for var, index in vars %}
      {% if (index + 1) < sz %}
        {{ var.id }}.next.should eq(pointerof({{ vars[(index + 1)].id }}))
      {% end %}
    {% end %}
  end

  macro by_previous(*vars)
    {% sz = vars.size %}
    {% for var, index in vars %}
      {% if (index + 1) < sz %}
        {{ var.id }}.previous.should eq(pointerof({{ vars[(index + 1)].id }}))
      {% end %}
    {% end %}
  end
end

describe Crystal::PointerLinkedList do
  describe "empty?" do
    it "return true if there is no element in list" do
      list = Crystal::PointerLinkedList(TestedObject).new
      list.empty?.should be_true
    end
  end

  describe "push" do
    it "append the node into the list" do
      list = Crystal::PointerLinkedList(TestedObject).new

      x = TestedObject.new 0
      y = TestedObject.new 1
      z = TestedObject.new 2

      list.push pointerof(x)
      list.push pointerof(y)
      list.push pointerof(z)

      ExpectOrderHelper.by_next(x, y, z, x)
      ExpectOrderHelper.by_previous(x, z, y, x)
    end
  end

  describe "delete" do
    it "remove a node from list" do
      list = Crystal::PointerLinkedList(TestedObject).new

      x = TestedObject.new 0
      y = TestedObject.new 1
      z = TestedObject.new 2
      w = TestedObject.new 3

      list.push pointerof(x)
      list.push pointerof(y)
      list.push pointerof(z)
      list.push pointerof(w)

      list.delete pointerof(y)

      ExpectOrderHelper.by_next(x, z, w, x)
      ExpectOrderHelper.by_previous(x, w, z, x)
    end
  end

  describe "shift?" do
    it "remove and return the first element" do
      list = Crystal::PointerLinkedList(TestedObject).new

      x = TestedObject.new 0
      y = TestedObject.new 1
      z = TestedObject.new 2
      w = TestedObject.new 3

      list.push pointerof(x)
      list.push pointerof(y)
      list.push pointerof(z)
      list.push pointerof(w)

      obj = list.shift?

      typeof(obj).should eq(Pointer(TestedObject)?)

      obj.should_not be_nil
      obj.should eq(pointerof(x))

      ExpectOrderHelper.by_next(y, z, w, y)
      ExpectOrderHelper.by_previous(y, w, z, y)
    end

    it "return nil if list is empty" do
      list = Crystal::PointerLinkedList(TestedObject).new

      obj = list.shift?

      obj.should be_nil
    end
  end

  it "does each" do
    list = Crystal::PointerLinkedList(TestedObject).new

    x = TestedObject.new 1
    y = TestedObject.new 2
    z = TestedObject.new 4

    sum = 0

    list.push pointerof(x)
    list.push pointerof(y)
    list.push pointerof(z)

    list.each do |object_ptr|
      sum += object_ptr.value.value
    end

    sum.should eq(7)
  end
end
