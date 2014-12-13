require "../../spec_helper"

describe "Type inference: if" do
  it "types an if without else" do
    assert_type("if 1 == 1; 1; end") { |mod| union_of(int32, mod.nil) }
  end

  it "types an if with else of same type" do
    assert_type("if 1 == 1; 1; else; 2; end") { int32 }
  end

  it "types an if with else of different type" do
    assert_type("if 1 == 1; 1; else; 'a'; end") { union_of(int32, char) }
  end

  it "types and if with and and assignment" do
    assert_type("
      struct Number
        def abs
          self
        end
      end

      class Foo
        def coco
          @a = 1 || nil
          if (b = @a) && 1 == 1
            b.abs
          end
        end
      end

      Foo.new.coco
      ") { |mod| union_of(int32, mod.nil) }
  end

  it "can invoke method on var that is declared on the right hand side of an and" do
    assert_type("
      if 1 == 2 && (b = 1)
        b + 1
      end
      ") { |mod| union_of(int32, mod.nil) }
  end
end
