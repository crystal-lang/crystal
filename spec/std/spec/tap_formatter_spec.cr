require "spec"

private def build_report(&)
  String.build do |io|
    formatter = Spec::TAPFormatter.new(io)
    yield formatter
    formatter.finish(Time::Span.zero, false)
  end
end

private def exception_with_backtrace(msg)
  raise Exception.new(msg)
rescue e
  e
end

describe Spec::TAPFormatter do
  it "reports successful results" do
    output = build_report do |f|
      f.report Spec::Result.new(:success, "should do something", "spec/some_spec.cr", 33, nil, nil)
      f.report Spec::Result.new(:success, "should do something else", "spec/some_spec.cr", 50, nil, nil)
    end

    output.chomp.should eq <<-TAP
      ok 1 - should do something
      ok 2 - should do something else
      1..2
      TAP
  end

  it "reports failures" do
    output = build_report do |f|
      f.report Spec::Result.new(:fail, "should do something", "spec/some_spec.cr", 33, nil, nil)
    end

    output.chomp.should eq <<-TAP
      not ok 1 - should do something
      1..1
      TAP
  end

  it "reports errors" do
    output = build_report do |f|
      f.report Spec::Result.new(:error, "should do something", "spec/some_spec.cr", 33, nil, nil)
    end

    output.chomp.should eq <<-TAP
      not ok 1 - should do something
      1..1
      TAP
  end

  it "reports pending" do
    output = build_report do |f|
      f.report Spec::Result.new(:pending, "should do something", "spec/some_spec.cr", 33, nil, nil)
    end

    output.chomp.should eq <<-TAP
      ok 1 - # SKIP should do something
      1..1
      TAP
  end

  it "reports mixed results" do
    output = build_report do |f|
      f.report Spec::Result.new(:success, "should do something1", "spec/some_spec.cr", 33, 2.seconds, nil)
      f.report Spec::Result.new(:fail, "should do something2", "spec/some_spec.cr", 50, 0.5.seconds, nil)
      f.report Spec::Result.new(:error, "should do something3", "spec/some_spec.cr", 65, nil, nil)
      f.report Spec::Result.new(:error, "should do something4", "spec/some_spec.cr", 80, nil, nil)
      f.report Spec::Result.new(:pending, "should do something5", "spec/some_spec.cr", 33, nil, nil)
    end

    output.chomp.should eq <<-TAP
      ok 1 - should do something1
      not ok 2 - should do something2
      not ok 3 - should do something3
      not ok 4 - should do something4
      ok 5 - # SKIP should do something5
      1..5
      TAP
  end
end
