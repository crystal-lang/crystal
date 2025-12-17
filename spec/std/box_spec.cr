require "spec"

describe "Box" do
  it "boxes and unboxes" do
    a = 1
    box = Box.box(a)
    Box(Int32).unbox(box).should eq(1)
  end

  it "boxing a reference returns the same pointer" do
    a = "foo"
    box = Box.box(a)
    box.address.should eq(a.object_id)

    Box(String).unbox(box).should be(a)
  end

  it "boxing a pointer returns the same pointer" do
    a = 123
    b = pointerof(a)
    box = Box.box(b)
    box.address.should eq(b.address)

    Box(Pointer(Int32)).unbox(box).should eq(b)
  end

  it "boxing a nilable reference returns the same pointer" do
    a = "foo".as(String?)
    box = Box.box(a)
    box.address.should eq(a.object_id)

    b = Box(String?).unbox(box)
    b.should be_a(String)
    b.should be(a)
  end

  it "boxing a nilable value returns the same value" do
    a = 1.as(Int32?)
    box = Box.box(a)

    b = Box(Int32?).unbox(box)
    b.should be_a(Int32)
    b.should eq(a)
  end

  it "boxes with explicit type" do
    box = Box(Int32?).box(1)
    b = Box(Int32?).unbox(box)
    b.should be_a(Int32)
    b.should eq(1)
  end

  it "boxing nil returns a null pointer" do
    box = Box.box(nil)
    box.address.should eq(0)

    Box(Nil).unbox(box).should be_nil
  end

  describe "unboxing a null pointer" do
    it "returns nil if nilable" do
      Box(Nil).unbox(Pointer(Void).null).should be_nil
      Box(String?).unbox(Pointer(Void).null).should be_nil
      Box(Int32?).unbox(Pointer(Void).null).should be_nil
      Box(Int32 | String?).unbox(Pointer(Void).null).should be_nil
      Box(UInt8*).unbox(Pointer(Void).null).should eq Pointer(UInt8).null
    end

    it "raises if non-nilable" do
      expect_raises(NilAssertionError, "Unboxing null pointer") do
        Box(String).unbox(Pointer(Void).null)
      end
      expect_raises(NilAssertionError, "Unboxing null pointer") do
        Box(Int32).unbox(Pointer(Void).null)
      end
    end
  end

  it "boxing nil in a reference-like union returns a null pointer (#11839)" do
    box = Box.box(nil.as(String?))
    box.address.should eq(0)

    Box(String?).unbox(box).should be_nil
  end

  it "boxing nil in a value-like union doesn't crash (#11839)" do
    box = Box.box(nil.as(Int32?))

    Box(Int32?).unbox(box).should be_nil
  end
end
