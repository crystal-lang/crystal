require "spec"
require "log"

private def c(value)
  Log::Context.new(value)
end

describe Log::Context do
  before_each do
    Log.context.clear
  end

  after_each do
    Log.context.clear
  end

  it "initialize" do
    c({a: 1}).should eq(c({"a" => c(1)}))
    c({a: 1, b: ["str", true], num: 1i64}).should eq(c({"a" => c(1), "b" => c([c("str"), c(true)]), "num" => c(1i64)}))
    c({a: 1f32, b: 1f64}).should eq(c({"a" => c(1f32), "b" => c(1f64)}))
    t = Time.local
    c({time: t}).should eq(c({"time" => c(t)}))
    Log::Context.new.should eq(c(NamedTuple.new))
  end

  it "immutability" do
    context = c({a: 1})
    other = context.as_h
    other["a"] = c(2)

    other.should eq({"a" => c(2)})
    context.should eq(c({a: 1}))
  end

  it "merge" do
    c({a: 1}).merge(c({b: 2})).should eq(c({a: 1, b: 2}))
    c({a: 1, b: 3}).merge(c({b: 2})).should eq(c({a: 1, b: 2}))
  end

  describe "implicit context" do
    it "can be set and cleared" do
      Log.context.should eq(Log::Context.new)

      Log.context.set a: 1
      Log.context.should eq(c({a: 1}))

      Log.context.clear
      Log.context.should eq(Log::Context.new)
    end

    it "is extended by set" do
      Log.context.set a: 1
      Log.context.set b: 2
      Log.context.should eq(c({a: 1, b: 2}))
    end

    it "existing keys are overwritten by set" do
      Log.context.set a: 1, b: 1
      Log.context.set b: 2, c: 3
      Log.context.should eq(c({a: 1, b: 2, c: 3}))
    end

    it "is restored with using" do
      Log.context.set a: 1

      Log.with_context do
        Log.context.set b: 2
        Log.context.should eq(c({a: 1, b: 2}))
      end

      Log.context.should eq(c({a: 1}))
    end

    it "is per fiber" do
      Log.context.set a: 1
      done = Channel(Nil).new

      f = spawn do
        Log.context.should eq(Log::Context.new)
        Log.context.set b: 2
        Log.context.should eq(c({b: 2}))

        done.receive
        done.receive
      end

      done.send nil
      Log.context.should eq(c({a: 1}))
      done.send nil
    end

    it "is assignable from a hash with symbol keys" do
      Log.context.set a: 1
      extra = {:b => 2}
      Log.context.set extra
      Log.context.should eq(c({a: 1, b: 2}))
    end

    it "is assignable from a hash with string keys" do
      Log.context.set a: 1
      extra = {"b" => 2}
      Log.context.set extra
      Log.context.should eq(c({a: 1, b: 2}))
    end

    it "is assignable from a named tuple" do
      Log.context.set a: 1
      extra = {b: 2}
      Log.context.set extra
      Log.context.should eq(c({a: 1, b: 2}))
    end
  end
end
