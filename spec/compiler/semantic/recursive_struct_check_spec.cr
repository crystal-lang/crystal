require "../../spec_helper"

describe "Semantic: recursive struct check" do
  it "errors on recursive struct" do
    ex = assert_error <<-CRYSTAL, "recursive struct Test detected"
           struct Test
             def initialize(@test : Test?)
             end
           end

           Test.new(Test.new(nil))
           CRYSTAL

    ex.to_s.should contain "`@test : (Test | Nil)`"
  end

  it "errors on recursive struct inside module" do
    ex = assert_error <<-CRYSTAL, "recursive struct Foo::Test detected"
           struct Foo::Test
             def initialize(@test : Foo::Test?)
             end
           end

           Foo::Test.new(Foo::Test.new(nil))
           CRYSTAL

    ex.to_s.should contain "`@test : (Foo::Test | Nil)`"
  end

  it "errors on recursive generic struct inside module" do
    ex = assert_error <<-CRYSTAL, "recursive struct Foo::Test(T) detected"
           struct Foo::Test(T)
             def initialize(@test : Foo::Test(T)?)
             end
           end

           Foo::Test(Int32).new(Foo::Test(Int32).new(nil))
           CRYSTAL

    ex.to_s.should contain "`@test : (Foo::Test(T) | Nil)`"
  end

  it "errors on mutually recursive struct" do
    ex = assert_error <<-CRYSTAL, "recursive struct Foo detected"
           struct Foo
             def initialize(@bar : Bar?)
             end
           end

           struct Bar
             def initialize(@foo : Foo?)
             end
           end

           Foo.new(Bar.new(nil))
           Bar.new(Foo.new(nil))
           CRYSTAL

    ex.to_s.should contain "`@bar : (Bar | Nil)` -> `(Bar | Nil)` -> `Bar` -> `@foo : (Foo | Nil)`"
  end

  it "detects recursive struct through module" do
    ex = assert_error <<-CRYSTAL, "recursive struct Foo detected"
           module Moo
           end

           struct Foo
             include Moo

             def initialize(@moo : Moo)
             end
           end
           CRYSTAL

    ex.to_s.should contain "`@moo : Moo` -> `Moo` -> `Foo`"
  end

  pending "errors on recursive abstract struct through module (#11384)" do
    ex = assert_error <<-CRYSTAL, "recursive struct Foo detected"
           module Moo
           end

           abstract struct Foo
             include Moo

             def initialize(@moo : Moo)
             end
           end
           CRYSTAL

    ex.to_s.should contain "`@moo : Moo` -> `Moo` -> `Foo`"
  end

  it "detects recursive generic struct through module (#4720)" do
    ex = assert_error <<-CRYSTAL, "recursive struct Foo(T) detected"
           module Bar
           end

           struct Foo(T)
             include Bar
             def initialize(@base : Bar?)
             end
           end
           CRYSTAL

    ex.to_s.should contain "`@base : (Bar | Nil)` -> `(Bar | Nil)` -> `Bar` -> `Foo(T)`"
  end

  it "detects recursive generic struct through generic module (#4720)" do
    ex = assert_error <<-CRYSTAL, "recursive struct Foo(T) detected"
           module Bar(T)
           end

           struct Foo(T)
             include Bar(T)
             def initialize(@base : Bar(T)?)
             end
           end
           CRYSTAL

    ex.to_s.should contain "`@base : (Bar(T) | Nil)` -> `(Bar(T) | Nil)` -> `Bar(T)` -> `Foo(T)`"
  end

  it "detects recursive struct through inheritance (#3071)" do
    ex = assert_error <<-CRYSTAL, "recursive struct Bar detected"
           abstract struct Foo
           end

           struct Bar < Foo
             @value = uninitialized Foo
           end
           CRYSTAL

    ex.to_s.should contain "`@value : Foo` -> `Foo` -> `Bar`"
  end

  it "errors on recursive struct through tuple" do
    ex = assert_error <<-CRYSTAL, "recursive struct Foo detected"
           struct Foo
             @x : {Foo}

             def initialize(@x)
             end
           end
           CRYSTAL

    ex.to_s.should contain "`@x : Tuple(Foo)`"
  end

  it "errors on recursive struct through named tuple" do
    ex = assert_error <<-CRYSTAL, "recursive struct Foo detected"
           struct Foo
             @x : {x: Foo}

             def initialize(@x)
             end
           end
           CRYSTAL

    ex.to_s.should contain "`@x : NamedTuple(x: Foo)`"
  end

  it "errors on recursive struct through recursive alias (#4454) (#4455)" do
    ex = assert_error <<-CRYSTAL, "recursive struct Foo detected (recursive aliases are structs)"
           struct Bar(T)
             def initialize(@x : T)
             end
           end

           alias Foo = Int32 | Bar(Foo)
           CRYSTAL

    ex.to_s.should contain "`(Bar(Foo) | Int32)` -> `Bar(Foo)` -> `@x : Foo`"
  end

  it "errors on private recursive type" do
    assert_error <<-CRYSTAL, "recursive struct Test detected"
      private struct Test
        def initialize(@test : Test?)
        end
      end

      Test.new(Test.new(nil))
      CRYSTAL
  end
end
