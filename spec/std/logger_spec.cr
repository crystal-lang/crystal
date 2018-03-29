require "spec"
require "logger"

describe "Logger" do
  it "logs messages" do
    IO.pipe do |r, w|
      logger = Logger.new(w)
      logger.debug "debug:skip"
      logger.info "info:show"

      logger.level = Logger::DEBUG
      logger.debug "debug:show"

      logger.level = Logger::WARN
      logger.debug "debug:skip:again"
      logger.info "info:skip"
      logger.error "error:show"

      r.gets.should match(/info:show/)
      r.gets.should match(/debug:show/)
      r.gets.should match(/error:show/)
    end
  end

  it "logs components selectively" do
    IO.pipe do |r, w|
      logger = Logger.new(w)
      logger.set_level Logger::ERROR
      logger.set_level Logger::WARN, "Foo::Bar"
      logger.warn "root:warn"
      logger.warn "foo:warn", "Foo"
      logger.warn "foobar:warn", "Foo::Bar"
      logger.warn "fooquux:warn", "Foo::Quux"
      logger.warn "foobarbaz:warn", "Foo::Bar::Baz"

      r.gets.should match(/foobar:warn/)
      r.gets.should match(/foobarbaz:warn/)

      logger.set_level Logger::DEBUG, "Foo"
      logger.debug "root:debug"
      logger.debug "foo:debug", "Foo"
      logger.debug "foobar:debug", "Foo::Bar"
      logger.debug "foobarbaz:debug", "Foo::Bar::Baz"
      logger.debug "fooquux:debug", "Foo::Quux"

      r.gets.should match(/foo:debug/)
      r.gets.should match(/fooquux:debug/)

      logger.unset_level "Foo::Bar"
      logger.debug "foobar:debug", "Foo::Bar"
      logger.debug "foobarbaz:debug", "Foo::Bar::Baz"

      r.gets.should match(/foobar:debug/)
      r.gets.should match(/foobarbaz:debug/)
    end
  end

  it "converts SILENT to UNKNOWN" do
    IO.pipe do |r, w|
      logger = Logger.new(w)
      logger.level = Logger::SILENT
      logger.log(Logger::SILENT, "skip", "")
      logger.level = Logger::UNKNOWN
      logger.log(Logger::SILENT, "show", "")

      r.gets.should match(/ANY.*show/)
    end
  end

  it "logs any object" do
    IO.pipe do |r, w|
      logger = Logger.new(w)
      logger.info 12345

      r.gets.should match(/12345/)
    end
  end

  it "uses adapters" do
    IO.pipe do |r1, w1|
      IO.pipe do |r2, w2|
        adapter1 = Logger::IOAdapter.new(w1)
        adapter2 = Logger::IOAdapter.new(w2)
        logger = Logger.new(adapter1)
        logger.info "one"
        logger.adapters << adapter2
        logger.info "two"
        logger.adapters.clear
        logger.info "three"
        logger.adapters << adapter1
        logger.info "four"

        r1.gets.should match(/one/)
        r1.gets.should match(/two/)
        r1.gets.should match(/four/)
        r2.gets.should match(/two/)
      end
    end
  end

  it "yields message" do
    IO.pipe do |r, w|
      logger = Logger.new(w)
      logger.error { "message" }
      logger.unknown(component: "comp") { "another message" }

      r.gets(chomp: false).should match(/ERROR: message\n/)
      r.gets(chomp: false).should match(/  ANY \/ comp: another message\n/)
    end
  end

  it "can create a logger with nil (#3065)" do
    logger = Logger.new(nil)
    logger.error("ouch")
  end

  it "doesn't yield to the block with nil" do
    a = 0
    logger = Logger.new(nil)
    logger.info { a = 1 }
    a.should eq(0)
  end
end
