require "spec"

describe "JUnit Formatter" do
  it "reports successful results" do
    output = build_report do |f|
      f.report Spec::Result.new(:success, "should do something", "spec/some_spec.cr", 33, nil, nil)
      f.report Spec::Result.new(:success, "should do something else", "spec/some_spec.cr", 50, nil, nil)
    end

    expected = <<-XML
                 <?xml version="1.0"?>
                 <testsuite tests="2" errors="0" failed="0">
                   <testcase file=\"spec/some_spec.cr\" classname=\"spec.some_spec\" name="should do something"/>
                   <testcase file=\"spec/some_spec.cr\" classname=\"spec.some_spec\" name="should do something else"/>
                 </testsuite>
                 XML

    output.chomp.should eq(expected)
  end

  it "reports failures" do
    output = build_report do |f|
      f.report Spec::Result.new(:fail, "should do something", "spec/some_spec.cr", 33, nil, nil)
    end

    expected = <<-XML
                 <?xml version="1.0"?>
                 <testsuite tests="1" errors="0" failed="1">
                   <testcase file=\"spec/some_spec.cr\" classname=\"spec.some_spec\" name="should do something">
                     <failure/>
                   </testcase>
                 </testsuite>
                 XML

    output.chomp.should eq(expected)
  end

  it "reports errors" do
    output = build_report do |f|
      f.report Spec::Result.new(:error, "should do something", "spec/some_spec.cr", 33, nil, nil)
    end

    expected = <<-XML
                 <?xml version="1.0"?>
                 <testsuite tests="1" errors="1" failed="0">
                   <testcase file=\"spec/some_spec.cr\" classname=\"spec.some_spec\" name="should do something">
                     <error/>
                   </testcase>
                 </testsuite>
                 XML

    output.chomp.should eq(expected)
  end

  it "reports mixed results" do
    output = build_report do |f|
      f.report Spec::Result.new(:success, "should do something1", "spec/some_spec.cr", 33, 2.seconds, nil)
      f.report Spec::Result.new(:fail, "should do something2", "spec/some_spec.cr", 50, 0.5.seconds, nil)
      f.report Spec::Result.new(:error, "should do something3", "spec/some_spec.cr", 65, nil, nil)
      f.report Spec::Result.new(:error, "should do something4", "spec/some_spec.cr", 80, nil, nil)
    end

    expected = <<-XML
                 <?xml version="1.0"?>
                 <testsuite tests="4" errors="2" failed="1">
                   <testcase file=\"spec/some_spec.cr\" classname=\"spec.some_spec\" name="should do something1"/>
                   <testcase file=\"spec/some_spec.cr\" classname=\"spec.some_spec\" name="should do something2">
                     <failure/>
                   </testcase>
                   <testcase file=\"spec/some_spec.cr\" classname=\"spec.some_spec\" name="should do something3">
                     <error/>
                   </testcase>
                   <testcase file=\"spec/some_spec.cr\" classname=\"spec.some_spec\" name="should do something4">
                     <error/>
                   </testcase>
                 </testsuite>
                 XML

    output.chomp.should eq(expected)
  end

  it "escapes spec names" do
    output = build_report do |f|
      f.report Spec::Result.new(:success, "complicated \" <n>'&ame", __FILE__, __LINE__, nil, nil)
    end

    name = XML.parse(output).xpath_string("string(//testsuite/testcase[1]/@name)")
    name.should eq("complicated \" <n>'&ame")
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
    backtrace.should eq(cause.backtrace.join("\n"))
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
    backtrace.should eq(cause.backtrace.join("\n"))
  end
end

private def build_report
  output = String::Builder.new
  formatter = Spec::JUnitFormatter.new(output)
  yield formatter
  formatter.finish
  output.to_s
end

private def exception_with_backtrace(msg)
  begin
    raise Exception.new(msg)
  rescue e
    e
  end
end
