require "../spec_helper"
require "xml"

class Spec::JUnitFormatter
  property started_at
end

private class MyException < Exception
end

describe "JUnit Formatter" do
  it "reports successful results" do
    output = build_report_with_no_timestamp do |f|
      f.report Spec::Result.new(:success, "should do something", "spec/some_spec.cr", 33, nil, nil)
      f.report Spec::Result.new(:success, "should do something else", "spec/some_spec.cr", 50, nil, nil)
    end

    expected = <<-XML
                 <?xml version="1.0"?>
                 <testsuite tests="2" skipped="0" errors="0" failures="0" time="0.0" hostname="#{System.hostname}">
                   <testcase file="spec/some_spec.cr" classname="spec.some_spec" name="should do something" line="33"/>
                   <testcase file="spec/some_spec.cr" classname="spec.some_spec" name="should do something else" line="50"/>
                 </testsuite>
                 XML

    output.should eq(expected)
  end

  it "reports skipped" do
    output = build_report_with_no_timestamp do |f|
      f.report Spec::Result.new(:pending, "should do something", "spec/some_spec.cr", 33, nil, nil)
    end

    expected = <<-XML
                 <?xml version="1.0"?>
                 <testsuite tests="1" skipped="1" errors="0" failures="0" time="0.0" hostname="#{System.hostname}">
                   <testcase file="spec/some_spec.cr" classname="spec.some_spec" name="should do something" line="33">
                     <skipped/>
                   </testcase>
                 </testsuite>
                 XML

    output.should eq(expected)
  end

  it "reports failures" do
    output = build_report_with_no_timestamp do |f|
      f.report Spec::Result.new(:fail, "should do something", "spec/some_spec.cr", 33, nil, nil)
    end

    expected = <<-XML
                 <?xml version="1.0"?>
                 <testsuite tests="1" skipped="0" errors="0" failures="1" time="0.0" hostname="#{System.hostname}">
                   <testcase file="spec/some_spec.cr" classname="spec.some_spec" name="should do something" line="33">
                     <failure/>
                   </testcase>
                 </testsuite>
                 XML

    output.should eq(expected)
  end

  it "reports errors" do
    output = build_report_with_no_timestamp do |f|
      f.report Spec::Result.new(:error, "should do something", "spec/some_spec.cr", 33, nil, MyException.new("foo"))
    end

    expected = <<-XML
                 <?xml version="1.0"?>
                 <testsuite tests="1" skipped="0" errors="1" failures="0" time="0.0" hostname="#{System.hostname}">
                   <testcase file="spec/some_spec.cr" classname="spec.some_spec" name="should do something" line="33">
                     <error message="foo" type="MyException"></error>
                   </testcase>
                 </testsuite>
                 XML

    output.should eq(expected)
  end

  it "reports mixed results" do
    output = build_report_with_no_timestamp do |f|
      f.report Spec::Result.new(:success, "should do something1", "spec/some_spec.cr", 33, 2.seconds, nil)
      f.report Spec::Result.new(:fail, "should do something2", "spec/some_spec.cr", 50, 0.5.seconds, nil)
      f.report Spec::Result.new(:error, "should do something3", "spec/some_spec.cr", 65, nil, nil)
      f.report Spec::Result.new(:pending, "should do something4", "spec/some_spec.cr", 80, nil, nil)
    end

    expected = <<-XML
                 <?xml version="1.0"?>
                 <testsuite tests="4" skipped="1" errors="1" failures="1" time="0.0" hostname="#{System.hostname}">
                   <testcase file="spec/some_spec.cr" classname="spec.some_spec" name="should do something1" line="33" time="2.0"/>
                   <testcase file="spec/some_spec.cr" classname="spec.some_spec" name="should do something2" line="50" time="0.5">
                     <failure/>
                   </testcase>
                   <testcase file="spec/some_spec.cr" classname="spec.some_spec" name="should do something3" line="65">
                     <error/>
                   </testcase>
                   <testcase file="spec/some_spec.cr" classname="spec.some_spec" name="should do something4" line="80">
                     <skipped/>
                   </testcase>
                 </testsuite>
                 XML

    output.should eq(expected)
  end

  it "encodes class names from the relative file path" do
    output = build_report do |f|
      f.report Spec::Result.new(:success, "foo", __FILE__, __LINE__, nil, nil)
    end

    classname = XML.parse(output).xpath_string("string(//testsuite/testcase[1]/@classname)")
    classname.should eq("spec.std.spec.junit_formatter_spec")
  end

  it "outputs timestamp according to RFC 3339" do
    now = Time.utc

    output = build_report(timestamp: now) do |f|
      f.report Spec::Result.new(:success, "foo", __FILE__, __LINE__, nil, nil)
    end

    classname = XML.parse(output).xpath_string("string(//testsuite[1]/@timestamp)")
    classname.should eq(now.to_rfc3339)
  end

  it "escapes spec names" do
    output = build_report do |f|
      f.report Spec::Result.new(:success, %(complicated " <n>'&ame), __FILE__, __LINE__, nil, nil)
      f.report Spec::Result.new(:success, %(ctrl characters follow - \r\n), __FILE__, __LINE__, nil, nil)
    end

    name = XML.parse(output).xpath_string("string(//testsuite/testcase[1]/@name)")
    name.should eq(%(complicated " <n>'&ame))

    name = XML.parse(output).xpath_string("string(//testsuite/testcase[2]/@name)")
    name.should eq(%(ctrl characters follow - \\r\\n))
  end

  it "report failure stacktrace if present" do
    cause = exception_with_backtrace("Something happened")

    output = build_report do |f|
      f.report Spec::Result.new(:fail, "foo", __FILE__, __LINE__, nil, cause)
    end

    xml = XML.parse(output)
    name = xml.xpath_string("string(//testsuite/testcase[1]/failure/@message)")
    name.should eq("Something happened")

    backtrace = xml.xpath_string("string(//testsuite/testcase[1]/failure/text())")
    backtrace.should eq(cause.backtrace.join('\n'))
  end

  it "report error stacktrace if present" do
    cause = exception_with_backtrace("Something happened")

    output = build_report do |f|
      f.report Spec::Result.new(:error, "foo", __FILE__, __LINE__, nil, cause)
    end

    xml = XML.parse(output)
    name = xml.xpath_string("string(//testsuite/testcase[1]/error/@message)")
    name.should eq("Something happened")

    backtrace = xml.xpath_string("string(//testsuite/testcase[1]/error/text())")
    backtrace.should eq(cause.backtrace.join('\n'))
  end
end

private def build_report(timestamp = nil, &)
  output = String::Builder.new
  formatter = Spec::JUnitFormatter.new(output)
  formatter.started_at = timestamp if timestamp
  yield formatter
  formatter.finish(Time::Span.zero, false)
  output.to_s.chomp
end

private def build_report_with_no_timestamp(&)
  output = build_report do |formatter|
    yield formatter
  end
  output.gsub(/\s*timestamp="(.+?)"/, "")
end

private def exception_with_backtrace(msg)
  raise Exception.new(msg)
rescue e
  e
end
