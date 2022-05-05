require "spec"
require "log"

private module Foo
  Log = ::Log.for("foo")

  module Bar
    Log         = Foo::Log.for("bar")
    LogFromType = ::Log.for(self)
  end

  class Generic(T)
    Log = ::Log.for(self)
  end

  module Same
    Log = Foo::Log.for("")
  end
end

describe Log do
  it "can build sources from nested" do
    Foo::Log.source.should eq("foo")
    Foo::Bar::Log.source.should eq("foo.bar")
    Foo::Same::Log.source.should eq("foo")
    Log.for("").for("").source.should eq("")
    Log.for("").for("foo").source.should eq("foo")
    Log.for("foo").for("").source.should eq("foo")
  end

  it "can build with level override" do
    top = Log.for("qux", :info)
    top.level.should eq(Log::Severity::Info)

    Log.for("qux", :warn)
    top.level.should eq(Log::Severity::Warn)
  end

  it "can build nested with level override" do
    foo_bar = Log.for("foo").for("bar", :info)
    foo_bar.level.should eq(Log::Severity::Info)

    Log.for("foo.bar", :warn)
    foo_bar.level.should eq(Log::Severity::Warn)
  end

  it "can build for module type" do
    Log.for(Foo::Bar).source.should eq("foo.bar")
  end

  it "can build for class" do
    Log.for(String::Builder).source.should eq("string.builder")
  end

  it "can build for generic class (ignores generic args)" do
    Log.for(Array(Int32)).source.should eq("array")
    Foo::Generic::Log.source.should eq("foo.generic")
  end

  it "can build for structs" do
    Log.for(Time).source.should eq("time")
  end

  it "building for type ignores parent source (types are absolute sources)" do
    Log.for("foo").for(String::Builder).source.should eq("string.builder")
  end

  it "can build with Log = ::Log.for(self)" do
    Foo::Bar::LogFromType.should eq(Foo::Bar::Log)
  end
end
