require "../../spec_helper"

describe "Type inference: nil" do
  it "types empty" do
    assert_type("") { |mod| mod.nil }
  end

  it "types nil" do
    assert_type("nil") { |mod| mod.nil }
  end

  it "can call a fun with nil for pointer" do
    assert_type("lib A; fun a(c : Char*) : Int32; end; A.a(nil)") { int32 }
  end

  it "can call a fun with nil for typedef pointer" do
    assert_type("lib A; type Foo = Char*; fun a(c : Foo) : Int32; end; A.a(nil)") { int32 }
  end

  it "marks instance variables as nil but doesn't explode on macros" do
    assert_type("
      require \"prelude\"

      class Foo
        getter :var

        def initialize
          @var = [1]
          @var.last
        end
      end

      f = Foo.new
      f.var.last
    ") { int32 }
  end

  it "marks instance variables as nil when not in initialize" do
    assert_type("
      class Foo
        def initialize
          @foo = 1
        end

        def bar=(bar)
          @bar = bar
        end

        def bar
          @bar
        end
      end

      f = Foo.new
      f.bar = 1
      f.bar
      ") { |mod| union_of(mod.nil, int32) }
  end

  it "marks instance variables as nil when not in initialize 2" do
    assert_type("
      class Foo
        def initialize
          @foo = 1
        end

        def bar=(bar)
          @bar = bar
        end

        def bar
          @bar
        end

        def foo
          @foo
        end
      end

      f = Foo.new
      f.bar = 1
      f.foo
      ") { int32 }
  end

  it "restricts type of 'if foo'" do
    assert_type("
      class Foo
        def bar
          1
        end
      end

      f = nil || Foo.new
      f ? f.bar : 10
      ") { int32 }
  end

  it "restricts type of 'if foo' on assign" do
    assert_type("
      class Foo
        def bar
          1
        end
      end

      if foo = (Foo.new || nil)
        foo.bar
      else
        10
      end
      ") { int32 }
  end


  it "restricts type of 'while foo'" do
    assert_type("
      class Foo
        def bar
          1
        end
      end

      foo = Foo.new || nil
      while foo
        foo.bar
      end
      1
      ") { int32 }
  end

  it "restricts type of 'while foo' on assign" do
    assert_type("
      class Foo
        def bar
          1
        end
      end

      while (foo = Foo.new || nil)
        foo.bar
      end
      1
      ") { int32 }
  end
end
