require "../../spec_helper"

describe "Code gen: union type" do
  it "codegens union type when obj is union and no args" do
    run("a = 1; a = 2.5_f32; a.to_f").to_f64.should eq(2.5)
  end

  it "codegens union type when obj is union and arg is union" do
    run("a = 1; a = 1.5_f32; (a + a).to_f").to_f64.should eq(3)
  end

  it "codegens union type when obj is not union but arg is" do
    run("a = 1; b = 2; b = 1.5_f32; (a + b).to_f").to_f64.should eq(2.5)
  end

  it "codegens union type when obj union but arg is not" do
    run("a = 1; b = 2; b = 1.5_f32; (b + a).to_f").to_f64.should eq(2.5)
  end

  it "codegens union type when no obj" do
    run("def foo(x); x; end; a = 1; a = 2.5_f32; foo(a).to_f").to_f64.should eq(2.5)
  end

  it "codegens union type when no obj and restrictions" do
    run("def foo(x : Int); 1.5; end; def foo(x : Float); 2.5; end; a = 1; a = 3.5_f32; foo(a).to_f").to_f64.should eq(2.5)
  end

  it "codegens union type as return value" do
    run("def foo; a = 1; a = 2.5_f32; a; end; foo.to_f").to_f64.should eq(2.5)
  end

  it "codegens union type for instance var" do
    run("
      struct Float
        def &+(other)
          self + other
        end
      end

      struct Int32
        def &+(other : Float)
          self + other
        end
      end

      class Foo
        @value : Int32 | Float32

        def initialize(value)
          @value = value
        end
        def value=(@value); end
        def value; @value; end
      end

      f = Foo.new(1)
      f.value = 1.5_f32
      (f.value &+ f.value).to_f
    ").to_f64.should eq(3)
  end

  it "codegens if with same nested union" do
    run("
      if true
        if true
          1
        else
          2.5_f32
        end
      else
        if true
          1
        else
          2.5_f32
        end
      end.to_i!
    ").to_i.should eq(1)
  end

  it "assigns union to union" do
    run("
      require \"prelude\"

      struct Nil; def to_i; 0; end; end

      struct Char
        def to_i
          ord
        end
      end

      class Foo
        @x : Int32 | Char | Nil

        def foo(x)
          @x = x
          @x = @x || 1
        end

        def x
          @x
        end
      end

      f = Foo.new
      f.foo 1
      f.foo 'a'
      f.x.to_i
      ").to_i.should eq(97)
  end

  it "assigns union to larger union" do
    run("
      require \"prelude\"
      a = 1
      a = 1.1_f32
      b = \"c\"
      b = 'd'
      a = b
      a.to_s
    ").to_string.should eq("d")
  end

  it "assigns union to larger union when source is nilable 1" do
    value = run("
      require \"prelude\"
      a = 1
      b = nil
      b = Reference.new
      a = b
      a.to_s
    ").to_string
    value.should contain("Reference")
  end

  it "assigns union to larger union when source is nilable 2" do
    run("
      require \"prelude\"
      a = 1
      b = Reference.new
      b = nil
      a = b
      a.to_s
    ").to_string.should eq("")
  end

  it "dispatch call to object method on nilable" do
    run("
      require \"prelude\"
      class Foo
      end

      a = nil
      a = Foo.new
      a.nil?
    ")
  end

  it "sorts restrictions when there are unions" do
    run("
      class Middle
      end

      class Top < Middle
      end

      class Another1
      end

      class Another2
      end

      def type_id(type : Another2)
        1
      end

      def type_id(y : Top)
        2
      end

      def type_id(y : Middle | Another1)
        3
      end

      def type_id(y)
        4
      end

      t = Top.new || Another1.new
      type_id t
      ").to_i.should eq(2)
  end

  it "codegens union to_s" do
    str = run(%(
      require "prelude"

      def foo(x : T) forall T
        T.to_s
      end

      a = 1 || 1.5
      foo(a)
      )).to_string
    str.in?("(Int32 | Float64)", "(Float64 | Int32)").should be_true
  end

  it "provides T as a tuple literal" do
    run(%(
      struct Union
        def self.foo
          {{ T.class_name }}
        end
      end
      Union(Nil, Int32).foo
      )).to_string.should eq("TupleLiteral")
  end
end
