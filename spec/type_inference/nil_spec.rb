require 'spec_helper'

describe 'Type inference: nil' do
  it "types nil" do
    assert_type('nil') { self.nil }
  end

  it "can call a fun with nil for pointer" do
    assert_type(%q(lib A; fun a(c : Char*) : Int; end; A.a(nil))) { int }
  end

  it "can call a fun with nil for typedef pointer" do
    assert_type(%q(lib A; type Foo : Char*; fun a(c : Foo) : Int; end; A.a(nil))) { int }
  end

  it "marks instance variables as nil but doesn't explode on macros" do
    assert_type(%q(
      require "prelude"

      class Foo
        def initialize
          @var = [1]
          @var.last
        end

        attr_reader :var
      end

      f = Foo.new
      f.var.last
    )) { int }
  end

  it "marks instance variables as nil when not in initialize" do
    assert_type(%q(
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
      )) { union_of(self.nil, int) }
  end

  it "marks instance variables as nil when not in initialize 2" do
    assert_type(%q(
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
      )) { int }
  end

  it "restricts type of 'if foo'" do
    assert_type(%q(
      class Foo
        def bar
          1
        end
      end

      f = nil || Foo.new
      f ? f.bar : 10
      )) { int }
  end

  it "restricts type of 'if foo' on assign" do
    assert_type(%q(
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
      )) { int }
  end

  it "restricts type of 'if @foo'" do
    assert_type(%q(
      class Foo
        def initialize
          @foo = Foo.new || nil
        end
        def foo
          if @foo
            @foo.bar
          else
            10
          end
        end
        def bar
          1
        end
      end

      Foo.new.foo
      )) { int }
  end

  it "restricts type of 'if @foo' on assign" do
    assert_type(%q(
      class Foo
        def foo
          if @foo = (Foo.new || nil)
            @foo.bar
          else
            10
          end
        end
        def bar
          1
        end
      end

      Foo.new.foo
      )) { int }
  end

  it "restricts type of 'while foo'" do
    assert_type(%q(
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
      )) { int }
  end
end
