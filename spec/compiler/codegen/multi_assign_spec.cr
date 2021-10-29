require "../../spec_helper"

describe "Code gen: multi assign" do
  it "supports n to n assignment" do
    run(<<-CR).to_i.should eq(123)
      a, b, c = 1, 2, 3
      a &* 100 &+ b &* 10 &+ c
      CR
  end

  it "supports 1 to n assignment" do
    run(<<-CR).to_i.should eq(123)
      class Foo
        def [](index)
          index &+ 1
        end
      end

      a, b, c = Foo.new
      a &* 100 &+ b &* 10 &+ c
      CR
  end

  it "supports m to n assignment, with splat on left-hand side (1)" do
    run(<<-CR).to_i.should eq(12345)
      #{tuple_new}

      a, *b, c = 1, 2, 3, 4, 5
      a &* 10000 &+ b[0] &* 1000 &+ b[1] &* 100 &+ b[2] &* 10 &+ c
      CR
  end

  it "supports m to n assignment, with splat on left-hand side (2)" do
    run(<<-CR).to_i.should eq(12345)
      #{tuple_new}

      *a, b, c = 1, 2, 3, 4, 5
      a[0] &* 10000 &+ a[1] &* 1000 &+ a[2] &* 100 &+ b &* 10 &+ c
      CR
  end

  it "supports m to n assignment, with splat on left-hand side (3)" do
    run(<<-CR).to_i.should eq(12345)
      #{tuple_new}

      a, b, *c = 1, 2, 3, 4, 5
      a &* 10000 &+ b &* 1000 &+ c[0] &* 100 &+ c[1] &* 10 &+ c[2]
      CR
  end

  it "supports 1 to n assignment, with splat on left-hand side (1)" do
    run(<<-CR).to_i.should eq(12345)
      require "prelude"

      a, *b, c = [1, 2, 3, 4, 5]
      a &* 10000 &+ b[0] &* 1000 &+ b[1] &* 100 &+ b[2] &* 10 &+ c
      CR
  end

  it "supports 1 to n assignment, with splat on left-hand side (2)" do
    run(<<-CR).to_i.should eq(12345)
      require "prelude"

      *a, b, c = [1, 2, 3, 4, 5]
      a[0] &* 10000 &+ a[1] &* 1000 &+ a[2] &* 100 &+ b &* 10 &+ c
      CR
  end

  it "supports 1 to n assignment, with splat on left-hand side (3)" do
    run(<<-CR).to_i.should eq(12345)
      require "prelude"

      a, b, *c = [1, 2, 3, 4, 5]
      a &* 10000 &+ b &* 1000 &+ c[0] &* 100 &+ c[1] &* 10 &+ c[2]
      CR
  end

  it "supports 1 to n assignment, raises if too short (1)" do
    run(<<-CR).to_b.should be_true
      require "prelude"

      begin
        a, *b, c = [1]
        false
      rescue ex : IndexError
        ex.message == "Multiple assignment count mismatch"
      end
      CR
  end

  it "supports 1 to n assignment, raises if too short (2)" do
    run(<<-CR).to_b.should be_true
      require "prelude"

      begin
        *a, b, c = [1]
        false
      rescue ex : IndexError
        ex.message == "Multiple assignment count mismatch"
      end
      CR
  end

  it "supports 1 to n assignment, raises if too short (3)" do
    run(<<-CR).to_b.should be_true
      require "prelude"

      begin
        a, b, *c = [1]
        false
      rescue ex : IndexError
        ex.message == "Multiple assignment count mismatch"
      end
      CR
  end
end

private def tuple_new
  <<-CR
    struct Tuple
      def self.new(*args)
        args
      end
    end
  CR
end
