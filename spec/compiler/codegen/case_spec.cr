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

  it "codegens case that always returns" do
    run("
      require \"prelude\"
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
    ").to_i.should eq(3)
  end

  it "codegens case when cond is a call" do
    run("
      require \"prelude\"

      $a = 0

      def foo
        $a += 1
      end

      case foo
      when 2
        1
      when 1
        2
      else
        3
      end
    ").to_i.should eq(2)
  end

  it "codegens case with class" do
    run("
      struct Nil; def to_i; 0; end; end

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
      end.to_i
      ").to_i.should eq(-1)
  end

  it "codegens value-less case" do
    run("
      case
      when 1 == 2
        1
      when 2 == 2
        2
      else
        3
      end
      ").to_i.should eq(2)
  end

  it "codegens case when constant bug (#1028)" do
    run(%(
      struct Nil
        def ===(other)
          self.is_a?(Reference) && other.is_a?(Reference)
        end
      end

      A = nil
      case nil
      when A
        1
      else
        2
      end
      )).to_i.should eq(2)
  end

  it "does case when with metaclass" do
    run(%(
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
      )).to_i.should eq(2)
  end
end
