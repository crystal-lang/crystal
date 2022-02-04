require "spec"

private class ComparableTestClass
  include Comparable(Int)

  def initialize(@value : Int32, @return_nil = false)
  end

  def <=>(other : Int)
    return nil if @return_nil

    @value <=> other
  end
end

describe Comparable do
  it "can compare against Int (#2461)" do
    obj = ComparableTestClass.new(4)
    (obj == 3).should be_false
    (obj == 4).should be_true

    (obj < 3).should be_false
    (obj < 4).should be_false

    (obj > 3).should be_true
    (obj > 4).should be_false

    (obj <= 3).should be_false
    (obj <= 4).should be_true
    (obj <= 5).should be_true

    (obj >= 3).should be_true
    (obj >= 4).should be_true
    (obj >= 5).should be_false
  end

  it "checks for nil" do
    obj = ComparableTestClass.new(4, return_nil: true)

    (obj < 1).should be_false
    (obj <= 1).should be_false
    (obj == 1).should be_false
    (obj >= 1).should be_false
    (obj > 1).should be_false
  end

  describe "clamp" do
    describe "number" do
      it "clamps integers" do
        -5.clamp(-10, 100).should eq(-5)
        -5.clamp(10, 100).should eq(10)
        5.clamp(10, 100).should eq(10)
        50.clamp(10, 100).should eq(50)
        500.clamp(10, 100).should eq(100)

        50.clamp(10..100).should eq(50)

        50.clamp(10..nil).should eq(50)
        50.clamp(10...nil).should eq(50)
        5.clamp(10..nil).should eq(10)
        5.clamp(10...nil).should eq(10)

        5.clamp(nil..10).should eq(5)
        50.clamp(nil..10).should eq(10)
      end

      it "clamps floats" do
        -5.5.clamp(-10.1, 100.1).should eq(-5.5)
        -5.5.clamp(10.1, 100.1).should eq(10.1)
        5.5.clamp(10.1, 100.1).should eq(10.1)
        50.5.clamp(10.1, 100.1).should eq(50.5)
        500.5.clamp(10.1, 100.1).should eq(100.1)

        50.5.clamp(10.1..100.1).should eq(50.5)
      end

      it "fails with an exclusive range" do
        expect_raises(ArgumentError) do
          range = Range.new(1, 2, exclusive: true)
          5.clamp(range)
        end
      end
    end

    describe "String" do
      it "clamps strings" do
        "e".clamp("a", "s").should eq "e"
        "e".clamp("f", "s").should eq "f"
        "e".clamp("a", "c").should eq "c"
        "this".clamp("thief", "thin").should eq "thin"
      end
    end
  end
end
