require "../../spec_helper"

describe "after type inference transformer" do
  it "keeps else of if with nil type" do
    assert_after_type_inference "a = nil; if a; 1; else; 2; end",
      "a = nil\na\n2"
  end

  it "keeps then of if with true literal" do
    assert_after_type_inference "if true; 1; else; 2; end",
      "1"
  end

  it "keeps else of if with false literal" do
    assert_after_type_inference "if false; 1; else; 2; end",
      "2"
  end

  it "keeps then of if with true assignment" do
    assert_after_type_inference "if a = true; 1; else; 2; end",
      "a = true\n1"
  end

  it "keeps else of if with false assignment" do
    assert_after_type_inference "if a = false; 1; else; 2; end",
      "a = false\n2"
  end

  it "keeps else of if with is_a? that can never hold" do
    assert_after_type_inference "a = 1; if a.is_a?(Bool); 2; else 3; end",
      "a = 1\n3"
  end

  it "keeps else of if with responds_to? that can never hold" do
    assert_after_type_inference "a = 1; if a.responds_to?(:foo); 2; else 3; end",
      "a = 1\n3"
  end

  it "keeps then of if with is_a? that is always true" do
    assert_after_type_inference "a = 1; if a.is_a?(Int32); 2; end",
      "a = 1\n2"
  end

  it "keeps then of if with is_a? that is always true" do
    assert_after_type_inference "a = 1 || 1.5; if a.is_a?(Number); 2; end",
      "a = if __temp_1 = 1\n  __temp_1\nelse\n  1.5\nend\n2"
  end

  it "keeps then of if with responds_to? that is always true" do
    assert_after_type_inference "a = 1; if a.responds_to?(:\"+\"); 2; end",
      "a = 1\n2"
  end

  it "errors if assigning var to itself" do
    assert_error "a = 1; a = a", "expression has no effect"
  end

  it "errors if assigning instance var to itself" do
    assert_error %(
      class Foo
        def initialize
          @a = 1; @a = @a
        end
      end
      Foo.new
      ), "expression has no effect"
  end

  # it "errors comparison of unsigned integer with zero or negative literal" do
  #   error = "comparison of unsigned integer with zero or negative literal will always be false"
  #   assert_error "1_u32 < 0", error
  #   assert_error "1_u32 <= -1", error
  #   assert_error "0 > 1_u32", error
  #   assert_error "-1 >= 1_u32", error
  # end
end
