require "spec"
require "logger"

class TestAdapter
  include Logger::Adapter
  getter messages = [] of String

  def write(severity, message, time, component)
    @messages << "#{severity} #{component} #{message}"
  end
end

describe Logger::Handler do
  it "logs messages" do
    adapter = TestAdapter.new
    handler = Logger::Handler.new(adapter)
    handler.log Logger::DEBUG, "debug:skip"
    handler.log Logger::INFO, "info:show"

    handler.set_level Logger::DEBUG
    handler.log Logger::DEBUG, "debug:show"

    handler.set_level Logger::WARN
    handler.log Logger::DEBUG, "debug:skip:again"
    handler.log Logger::INFO, "info:skip"
    handler.log Logger::ERROR, "error:show"

    adapter.messages.shift.should match(/info:show/)
    adapter.messages.shift.should match(/debug:show/)
    adapter.messages.shift.should match(/error:show/)
    adapter.messages.size.should eq 0
  end

  it "logs components selectively" do
    adapter = TestAdapter.new
    handler = Logger::Handler.new(adapter)
    handler.set_level Logger::ERROR
    handler.set_level "Foo::Bar", Logger::WARN
    handler.log Logger::WARN, "root:warn"
    handler.log Logger::WARN, "foo:warn", "Foo"
    handler.log Logger::WARN, "foobar:warn", "Foo::Bar"
    handler.log Logger::WARN, "fooquux:warn", "Foo::Quux"
    handler.log Logger::WARN, "foobarbaz:warn", "Foo::Bar::Baz"

    adapter.messages.shift.should match(/foobar:warn/)
    adapter.messages.shift.should match(/foobarbaz:warn/)
    adapter.messages.size.should eq 0

    handler.set_level "Foo", Logger::DEBUG
    handler.log Logger::DEBUG, "root:debug"
    handler.log Logger::DEBUG, "foo:debug", "Foo"
    handler.log Logger::DEBUG, "foobar:debug", "Foo::Bar"
    handler.log Logger::DEBUG, "foobarbaz:debug", "Foo::Bar::Baz"
    handler.log Logger::DEBUG, "fooquux:debug", "Foo::Quux"

    adapter.messages.shift.should match(/foo:debug/)
    adapter.messages.shift.should match(/fooquux:debug/)
    adapter.messages.size.should eq 0

    handler.unset_level "Foo::Bar"
    handler.log Logger::DEBUG, "foobar:debug", "Foo::Bar"
    handler.log Logger::DEBUG, "foobarbaz:debug", "Foo::Bar::Baz"

    adapter.messages.shift.should match(/foobar:debug/)
    adapter.messages.shift.should match(/foobarbaz:debug/)
    adapter.messages.size.should eq 0
  end

  it "finds real and effective levels" do
    handler = Logger::Handler.new([] of Logger::Adapter)

    handler.set_level "one::two", Logger::WARN
    handler.set_level "one::two::three", Logger::ERROR

    handler.level?("one").should be_nil
    handler.level!("one").should eq Logger::INFO
    handler.level?("one::two").should eq Logger::WARN
    handler.level!("one::two").should eq Logger::WARN
    handler.level?("one::two::three").should eq Logger::ERROR
    handler.level!("one::two::three").should eq Logger::ERROR
    handler.level?("one::two::three::four").should be_nil
    handler.level!("one::two::three::four").should eq Logger::ERROR
    handler.level?("one::two::five").should be_nil
    handler.level!("one::two::five").should eq Logger::WARN

    handler.unset_level "one::two::three"
    handler.level?("one::two::three").should be_nil
    handler.level!("one::two::three").should eq Logger::WARN
    handler.level?("one::two::three::four").should be_nil
    handler.level!("one::two::three::four").should eq Logger::WARN
  end

  it "logs any object" do
    adapter = TestAdapter.new
    handler = Logger::Handler.new(adapter)
    handler.log Logger::INFO, 12345

    adapter.messages.shift.should match(/12345/)
    adapter.messages.size.should eq 0
  end

  it "uses adapters" do
    adapter1 = TestAdapter.new
    adapter2 = TestAdapter.new
    handler = Logger::Handler.new([adapter1, adapter2] of Logger::Adapter)
    handler.log Logger::INFO, "one"
    handler.adapters.pop
    handler.log Logger::INFO, "two"
    handler.adapters.clear
    handler.log Logger::INFO, "three"
    handler.adapters << adapter2
    handler.log Logger::INFO, "four"

    adapter1.messages.shift.should match(/one/)
    adapter2.messages.shift.should match(/one/)
    adapter1.messages.shift.should match(/two/)
    adapter2.messages.shift.should match(/four/)
    adapter1.messages.size.should eq 0
    adapter2.messages.size.should eq 0
  end

  it "yields message" do
    adapter = TestAdapter.new
    handler = Logger::Handler.new(adapter)
    handler.log(Logger::ERROR) { "message" }
    handler.log(Logger::UNKNOWN, component: "comp") { "another message" }

    adapter.messages.shift.should eq("ERROR  message")
    adapter.messages.shift.should eq("UNKNOWN comp another message")
    adapter.messages.size.should eq 0
  end
end
