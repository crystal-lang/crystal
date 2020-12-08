require "spec"
require "log/spec"
require "log"

describe "log/spec" do
  it "yield and returns the dsl" do
    helper = nil
    returned = Log.capture do |yielded|
      helper = yielded
    end

    helper.should eq(returned)
  end

  it "allows matching logs" do
    Log.capture {
      Log.error { "this is an error" }
      Log.fatal { "this is a fatal" }
    }.itself
      .check(:error, "this is an error")
      .check(:fatal, "this is a fatal")
      .empty
  end

  it "can get the entry matched by check" do
    Log.capture {
      Log.error { "this is an error" }
      Log.fatal { "this is a fatal" }
    }.itself
      .check(:error, "this is an error").tap { |d|
      d.entry.message.should eq("this is an error")
    }.check(:fatal, "this is a fatal").tap { |d|
      d.entry.message.should eq("this is a fatal")
    }.empty
  end

  it "allows matching non-consecutive logs" do
    Log.capture {
      Log.error { "ignored" }
      Log.error { "this is an error" }
      Log.fatal { "also ignored" }
      Log.fatal { "this is a fatal" }
    }.itself
      .check(:error, "this is an error")
      .check(:fatal, "this is a fatal")
      .empty
  end

  it "allows matching logs strictly" do
    Log.capture {
      Log.error { "this is an error" }
      Log.fatal { "this is a fatal" }
    }.itself
      .next(:error, "this is an error")
      .next(:fatal, "this is a fatal")
      .empty
  end

  it "can get the entry matched by next" do
    Log.capture {
      Log.error { "this is an error" }
      Log.fatal { "this is a fatal" }
    }.itself
      .next(:error, "this is an error").tap { |d|
      d.entry.message.should eq("this is an error")
    }.next(:fatal, "this is a fatal").tap { |d|
      d.entry.message.should eq("this is a fatal")
    }.empty
  end

  it "fails on non-consecutive logs" do
    expect_raises(Spec::AssertionFailed, /No matching entries found, expected Fatal with "this is a second fatal", but got Fatal with "this is a fatal"/) do
      Log.capture {
        Log.error { "this is an error" }
        Log.fatal { "this is a fatal" }
        Log.fatal { "this is a second fatal" }
      }.itself
        .next(:error, "this is an error")
        .next(:fatal, "this is a second fatal")
        .empty
    end
  end

  it "fails on non-empty logs" do
    expect_raises(Spec::AssertionFailed, /Expected no entries, but got Error with "this is an error" in a total of 1 entries/) do
      Log.capture {
        Log.error { "this is an error" }
      }.itself
        .empty
    end
  end

  it "entries can be cleared" do
    Log.capture do |l|
      Log.error { "this is an error" }
      l.clear
      l.empty
    end
  end

  it "allows matching with regex" do
    Log.capture do |l|
      Log.error { "this is an error" }
      Log.error { "this is a second error" }

      l.check(:error, /an error/)
      l.next(:error, /second error/)
    end
  end

  it "can capture in different checkers" do
    Log.capture("foo", :info) do |foo|
      Log.capture("bar", :info) do |bar|
        Log.error { "error in top" }
        Log.for("foo").error { "error in foo" }
        Log.for("bar").error { "error in bar" }
        Log.error { "second error in top" }

        foo.next(:error, "error in foo")
        foo.empty

        bar.next(:error, "error in bar")
        bar.empty
      end
    end
  end

  it "can capture with source pattern" do
    Log.capture("foo.*", :info) do |foo|
      Log.for("foo").error { "error in foo" }
      Log.for("bar").error { "error in bar" }
      Log.for("foo.nested").error { "error in foo.nested" }

      foo.next(:error, "error in foo")
      foo.next(:error, "error in foo.nested")
      foo.empty
    end
  end

  it "can capture from all sources" do
    Log.capture(:info) do |logs|
      Log.for("foo").error { "error in foo" }
      Log.for("bar").error { "error in bar" }
      Log.for("foo.nested").error { "error in foo.nested" }

      logs.next(:error, "error in foo")
      logs.next(:error, "error in bar")
      logs.next(:error, "error in foo.nested")
      logs.empty
    end
  end

  it "it does not capture below level" do
    Log.capture(:info) do |logs|
      Log.debug { "ignored" }
      Log.error { "first error" }
      Log.debug { "ignored" }
      Log.error { "second error" }
      Log.debug { "ignored" }

      logs.next(:error, "first error")
      logs.next(:error, "second error")
      logs.empty
    end
  end
end
