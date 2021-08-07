require "spec"
require "spec/helpers/iterate"

describe Spec::Methods do
  describe ".assert_iterates_yielding" do
    it "basic" do
      assert_iterates_yielding [1, 2, 3], (1..3).each
    end

    it "more than expected elements" do
      expect_raises Spec::AssertionFailed, "Reached iteration limit 3 receiving value 4" do
        assert_iterates_yielding [1, 2, 3], (1..4).each
      end
    end

    it "less than expected elements" do
      expect_raises Spec::AssertionFailed, /Expected: \[1, 2, 3\]\n\s+got: \[1, 2\]/ do
        assert_iterates_yielding [1, 2, 3], (1..2).each
      end
    end

    it "ensures type equality" do
      expect_raises Spec::AssertionFailed, "Mismatching type, expected: 1.0 (Float64), got: 1 (Int32) at 0" do
        assert_iterates_yielding [1.0, 2.0, 3.0] of Int32 | Float64, (1..3).each
      end
    end

    it "infinite" do
      assert_iterates_yielding [1, 2, 3], (1..).each, infinite: true

      expect_raises Spec::AssertionFailed, "Reached iteration limit 3 receiving value 4" do
        assert_iterates_yielding [1, 2, 3], (1..).each, infinite: false
      end

      assert_iterates_yielding [] of Int32, (1..).each, infinite: true
    end

    it "tuple" do
      assert_iterates_yielding [{1, 0}, {2, 1}, {3, 2}], (1..3).each_with_index, tuple: true
    end
  end

  describe ".assert_iterates_iterator" do
    it "basic" do
      assert_iterates_iterator [1, 2, 3], (1..3).each
    end

    it "more than expected elements" do
      expect_raises Spec::AssertionFailed, "Expected 4 (Int32) to be a Iterator::Stop" do
        assert_iterates_iterator [1, 2, 3], (1..4).each
      end
    end

    it "less than expected elements" do
      expect_raises Spec::AssertionFailed, /Expected: \[1, 2, 3\]\n\s+got: \[1, 2\]/ do
        assert_iterates_iterator [1, 2, 3], (1..2).each
      end
    end

    it "ensures type equality" do
      expect_raises Spec::AssertionFailed, "Mismatching type, expected: 1.0 (Float64), got: 1 (Int32) at 0" do
        assert_iterates_iterator [1.0, 2.0, 3.0] of Int32 | Float64, (1..3).each
      end
    end

    it "infinite" do
      assert_iterates_iterator [1, 2, 3], (1..).each, infinite: true

      expect_raises Spec::AssertionFailed, "Expected 4 (Int32) to be a Iterator::Stop" do
        assert_iterates_iterator [1, 2, 3], (1..).each, infinite: false
      end

      assert_iterates_iterator [] of Int32, (1..).each, infinite: true
    end

    it "tuple" do
      assert_iterates_iterator [{1, 0}, {2, 1}, {3, 2}], (1..3).each_with_index
    end
  end
end
