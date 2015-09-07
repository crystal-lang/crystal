require "spec"

describe "Toplevel" do
  describe "loop" do
    it "yields" do
      i = 0
      loop do
        i += 1
        break if i == 3
      end
      i.should eq 3
    end

    it "returns an iterator" do
      iter = loop
      iter.next.should be_nil
      iter.next.should be_nil
      iter.next.should be_nil
      iter.rewind
      iter.next.should be_nil
      iter.next.should be_nil
      iter.next.should be_nil

      y = 0
      loop.with_index(2) do |i|
        i.should_not eq 0
        y += 1
        break if i == 3 || y == 5
      end

      y.should eq 2
    end
  end
end
