require "../../spec_helper"

describe "Code gen: case" do
  it "codegens case with one condition" do
    run("require \"prelude\"; case 1; when 1; 2; else; 3; end").to_i.should eq(2)
  end

  it "codegens case with two conditions" do
    run("require \"prelude\"; case 1; when 0, 1; 2; else; 3; end").to_i.should eq(2)
  end

  it "codegens case with else" do
    run("require \"prelude\"; case 1; when 0; 2; else; 3; end").to_i.should eq(3)
  end

  it "codegens case with binary operator on implicit call" do
    run(<<-CRYSTAL).to_i.should eq(2)
      require "prelude"
      case "abc"
      when .size > 5 then 1
      when .size > 2 then 2
      else                3
      end
      CRYSTAL
  end

  it "codegens case with chained calls on implicit obj" do
    run(<<-CRYSTAL).to_i.should eq(2)
      require "prelude"
      case "abc"
      when .upcase.empty?     then 1
      when .upcase.size.even? then 3
      when .upcase.size.odd?  then 2
      else                         4
      end
      CRYSTAL
  end

  it "evaluates case expression once with implicit call chain" do
    run(<<-CRYSTAL).to_i.should eq(1)
      require "prelude"
      count = 0
      case (count += 1; "abc")
      when .size > 5, .size > 4
      when .upcase.size > 3
      end
      count
      CRYSTAL
  end

  it "codegens case with implicit call chain with local var of the same name" do
    run(<<-CRYSTAL).to_i.should eq(4)
      require "prelude"
      size = 100
      case "abc"
      when .size + 1 > size then 3
      else                       4
      end
      CRYSTAL
  end

  it "preserves evaluation order of implicit call chain through a macro" do
    run(<<-CRYSTAL).to_i.should eq(1)
      require "prelude"
      macro identity(node)
        {{ node }}
      end

      identity(
        case 5
        when .itself.+(1) * 2 == 12 then 1
        else                             2
        end
      )
      CRYSTAL
  end

  it "codegens case without whens but else" do
    run("require \"prelude\"; case 1; else; 2; end").to_i.should eq(2)
  end

  it "codegens case that always returns" do
    run(<<-CRYSTAL).to_i.should eq(3)
      require "prelude"
      def foo
        if true
          case 0
          when 1; return 2
          else return 3
          end
        end
        4
      end

      foo
      CRYSTAL
  end

  it "codegens case when cond is a call" do
    run(<<-CRYSTAL).to_i.should eq(2)
      require "prelude"

      def foo
        1
      end

      case foo
      when 2
        1
      when 1
        2
      else
        3
      end
      CRYSTAL
  end

  it "codegens case with class" do
    run(<<-CRYSTAL).to_i.should eq(-1)
      struct Nil; def to_i!; 0; end; end

      struct Int32
        def foo
          self
        end
      end

      a = -1 || 'a'
      case a
      when Int32
        a.foo
      when Char
        a.ord
      end.to_i!
      CRYSTAL
  end

  it "codegens value-less case" do
    run(<<-CRYSTAL).to_i.should eq(2)
      case
      when 1 == 2
        1
      when 2 == 2
        2
      else
        3
      end
      CRYSTAL
  end

  it "codegens case when constant bug (#1028)" do
    run(<<-CRYSTAL).to_i.should eq(2)
      struct Nil
        def ===(other)
          self.is_a?(Reference) && other.is_a?(Reference)
        end
      end

      CONST = nil
      case nil
      when CONST
        1
      else
        2
      end
      CRYSTAL
  end

  it "does case when with metaclass" do
    run(<<-CRYSTAL).to_i.should eq(2)
      class Foo
        def self.foo
          1
        end
      end

      class Bar
        def self.bar
          2
        end
      end

      foobar = Bar || Foo
      case foobar
      when Foo.class
        foobar.foo
      when Bar.class
        foobar.bar
      else
        3
      end
      CRYSTAL
  end
end
