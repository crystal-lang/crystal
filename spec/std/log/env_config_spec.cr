require "spec"
require "log"

private def s(value : Log::Severity)
  value
end

describe "Log.setup_from_env" do
  it "uses stdio" do
    builder = Log::Builder.new
    Log.setup_from_env(builder: builder, level: "info", sources: "")

    builder.for("").backend.should be_a(Log::IOBackend)
  end

  it "raises on invalid level" do
    builder = Log::Builder.new

    expect_raises(ArgumentError) do
      Log.setup_from_env(builder: builder, level: "invalid", sources: "")
    end
  end

  it "splits sources by comma" do
    builder = Log::Builder.new
    Log.setup_from_env(builder: builder, level: "info", sources: "db, , foo.*  ")

    builder.for("db").backend.should_not be_nil
    builder.for("").backend.should_not be_nil
    builder.for("foo").backend.should_not be_nil
    builder.for("foo.bar.baz").backend.should_not be_nil
    builder.for("other").backend.should be_nil
  end
end
