require "spec"
require "colorize"

private class FakeTTY < IO::Memory
  include Colorize::ColorizableIO

  @colorize_when = Colorize::When::Always

  property? tty = false

  INSTANCE = new
end

private def colorize(obj, tty = true, colorize_when = Colorize::When::Always, **args)
  io = FakeTTY::INSTANCE

  begin
    io.colorize_when = colorize_when
    io.tty = tty
    if obj
      io << yield obj.colorize **args
    else
      io.surround(yield with_color **args) { }
    end
  ensure
    io.colorize_when = Colorize::When::Always
    io.tty = false
  end

  io.to_s.tap { io.clear }
end

private def colorize(obj, **args)
  colorize obj, **args, &.itself
end

describe Colorize do
  [
    {Colorize::Object, ""},
    {Colorize::Style, nil},
  ].each do |cls, obj|
    describe cls do
      it "colorizes without change" do
        colorize(obj).should eq("")
      end

      {% for ground in %w(fore back) %}
        {% prefix = "fore" == ground ? "".id : "on_".id %}
        {% carry = "fore" == ground ? 0 : 10 %}

        it "colorize #{{{ground}}}ground with default color" do
          colorize(obj, &.{{prefix}}default).should eq("")

          colorize(obj, &.{{ground.id}}(:default)).should eq("")
          colorize(obj, &.{{ground.id}}("default")).should eq("")
          colorize(obj, &.{{ground.id}}(Colorize::ColorANSI::Default)).should eq("")

          {% if "back" == ground %}
            colorize(obj, &.on(:default)).should eq("")
            colorize(obj, &.on("default")).should eq("")
            colorize(obj, &.on(Colorize::ColorANSI::Default)).should eq("")
          {% end %}

          colorize(obj, {{ground.id}}: :default).should eq("")
          colorize(obj, {{ground.id}}: "default").should eq("")
          colorize(obj, {{ground.id}}: Colorize::ColorANSI::Default).should eq("")
        end

        it "colorizes #{{{ground}}}ground with ANSI color" do
          {% for color in Colorize::ColorANSI.constants.reject { |name| name == "Default" } %}
            ans = "\e[#{{{carry + Colorize::ColorANSI.constant color}}}m\e[0m"

            colorize(obj, &.{{prefix}}{{color.underscore}}).should eq(ans)

            colorize(obj, &.{{ground.id}}({{color.underscore.symbolize}})).should eq(ans)
            colorize(obj, &.{{ground.id}}({{color.underscore.stringify}})).should eq(ans)
            colorize(obj, &.{{ground.id}}(Colorize::ColorANSI::{{color}})).should eq(ans)

            {% if "back" == ground %}
              colorize(obj, &.on({{color.underscore.symbolize}})).should eq(ans)
              colorize(obj, &.on({{color.underscore.stringify}})).should eq(ans)
              colorize(obj, &.on(Colorize::ColorANSI::{{color}})).should eq(ans)
            {% end %}

            colorize(obj, {{ground.id}}: {{color.underscore.symbolize}}).should eq(ans)
            colorize(obj, {{ground.id}}: {{color.underscore.stringify}}).should eq(ans)
            colorize(obj, {{ground.id}}: Colorize::ColorANSI::{{color}}).should eq(ans)
          {% end %}
        end

        it "colorizes #{{{ground}}}ground with 256 color" do
          256.times do |i|
            ans = "\e[#{{{carry + 38}}};5;#{i}m\e[0m"

            colorize(obj, &.{{ground.id}}(i)).should eq(ans)
            colorize(obj, &.{{ground.id}}(i.to_s)).should eq(ans)
            colorize(obj, &.{{ground.id}}(Colorize::Color256.new i)).should eq(ans)

            {% if "back" == ground %}
              colorize(obj, &.on(i)).should eq(ans)
              colorize(obj, &.on(i.to_s)).should eq(ans)
              colorize(obj, &.on(Colorize::Color256.new i)).should eq(ans)
            {% end %}

            colorize(obj, {{ground.id}}: i).should eq(ans)
            colorize(obj, {{ground.id}}: i.to_s).should eq(ans)
            colorize(obj, {{ground.id}}: Colorize::Color256.new i).should eq(ans)
          end
        end

        it "colorizes #{{{ground}}}ground with 32bit true color" do
          [
            {"#000", {0x00, 0x00, 0x00}},
            {"#123", {0x11, 0x22, 0x33}},
            {"#FFF", {0xFF, 0xFF, 0xFF}},
            {"#012345", {0x01, 0x23, 0x45}},
          ].each do |(name, code)|
            ans = "\e[#{{{carry + 38}}};2;#{code.join ";"}m\e[0m"

            colorize(obj, &.{{ground.id}}(name)).should eq(ans)
            colorize(obj, &.{{ground.id}}(Colorize::ColorRGB.new *code)).should eq(ans)

            {% if "back" == ground %}
              colorize(obj, &.on(name)).should eq(ans)
              colorize(obj, &.on(Colorize::ColorRGB.new *code)).should eq(ans)
            {% end %}

            colorize(obj, {{ground.id}}: name).should eq(ans)
            colorize(obj, {{ground.id}}: Colorize::ColorRGB.new *code).should eq(ans)
          end
        end
      {% end %}

      it "colorizes foreground with background" do
        colorize(obj, &.blue.on_green).should eq("\e[34;42m\e[0m")
        colorize(obj, fore: :blue, back: :green).should eq("\e[34;42m\e[0m")
      end

      it "colorizes mode" do
        {% for mode, code in {bold: 1, bright: 1, dim: 2, underline: 4, blink: 5, reverse: 7, hidden: 8} %}
          ans = "\e[#{{{code}}}m\e[0m"

          colorize(obj, &.{{mode}}).should eq(ans)

          colorize(obj, &.mode({{mode.symbolize}})).should eq(ans)
          colorize(obj, &.mode({{mode.stringify}})).should eq(ans)
          colorize(obj, &.mode(Colorize::Mode::{{mode.capitalize}})).should eq(ans)

          colorize(obj, mode: {{mode.symbolize}}).should eq(ans)
          colorize(obj, mode: {{mode.stringify}}).should eq(ans)
          colorize(obj, mode: Colorize::Mode::{{mode.capitalize}}).should eq(ans)
        {% end %}
      end

      it "colorizes mode combination" do
        colorize(obj, &.bold.dim.underline.blink.reverse.hidden).should eq("\e[1;2;4;5;7;8m\e[0m")
        colorize(obj, &.bold.bright.dim.underline.blink.reverse.hidden).should eq("\e[1;2;4;5;7;8m\e[0m")

        colorize(obj, &.mode(Colorize::Mode::All)).should eq("\e[1;2;4;5;7;8m\e[0m")
        colorize(obj, mode: Colorize::Mode::All).should eq("\e[1;2;4;5;7;8m\e[0m")
      end

      it "colorizes foreground with background with mode" do
        colorize(obj, &.blue.on_green.bold).should eq("\e[34;42;1m\e[0m")
        colorize(obj, fore: :blue, back: :green, mode: :bold).should eq("\e[34;42;1m\e[0m")
      end

      it "colorizes when given io is TTY on 'auto' policy" do
        colorize(obj, tty: false, colorize_when: :auto, &.black).should eq("")
        colorize(obj, tty: false, colorize_when: "auto", &.black).should eq("")
        colorize(obj, tty: false, colorize_when: Colorize::When::Auto, &.black).should eq("")

        colorize(obj, tty: true, colorize_when: :auto, &.black).should eq("\e[30m\e[0m")
        colorize(obj, tty: true, colorize_when: "auto", &.black).should eq("\e[30m\e[0m")
        colorize(obj, tty: true, colorize_when: Colorize::When::Auto, &.black).should eq("\e[30m\e[0m")
      end

      it "colorizes always" do
        colorize(obj, tty: false, colorize_when: :always, &.black).should eq("\e[30m\e[0m")
        colorize(obj, tty: false, colorize_when: "always", &.black).should eq("\e[30m\e[0m")
        colorize(obj, tty: false, colorize_when: Colorize::When::Always, &.black).should eq("\e[30m\e[0m")

        colorize(obj, tty: true, colorize_when: :always, &.black).should eq("\e[30m\e[0m")
        colorize(obj, tty: true, colorize_when: "always", &.black).should eq("\e[30m\e[0m")
        colorize(obj, tty: true, colorize_when: Colorize::When::Always, &.black).should eq("\e[30m\e[0m")
      end

      it "colorizes never" do
        colorize(obj, tty: false, colorize_when: :never, &.black).should eq("")
        colorize(obj, tty: false, colorize_when: "never", &.black).should eq("")
        colorize(obj, tty: false, colorize_when: Colorize::When::Never, &.black).should eq("")

        colorize(obj, tty: true, colorize_when: :never, &.black).should eq("")
        colorize(obj, tty: true, colorize_when: "never", &.black).should eq("")
        colorize(obj, tty: true, colorize_when: Colorize::When::Never, &.black).should eq("")
      end

      it "is chainable but apply only last" do
        colorize(obj, &.blue.red).should eq("\e[31m\e[0m")
        colorize(obj, &.on_blue.on_red).should eq("\e[41m\e[0m")
      end

      it "is chainable, nil has no effect" do
        colorize(obj, &.blue.fore(nil)).should eq("\e[34m\e[0m")
        colorize(obj, &.on_blue.back(nil)).should eq("\e[44m\e[0m")
        colorize(obj, &.bold.mode(nil)).should eq("\e[1m\e[0m")
      end

      it "raises on unknown foreground color" do
        expect_raises ArgumentError, "unknown color: brown" do
          colorize(obj, fore: :brown)
        end
      end

      it "raises on unknown background color" do
        expect_raises ArgumentError, "unknown color: brown" do
          colorize(obj, back: :brown)
        end
      end

      it "raises on unknown mode" do
        expect_raises ArgumentError, "unknown mode: bad" do
          colorize(obj, mode: :bad)
        end
      end

      it "toggles to disable" do
        colorize(obj, fore: :red, &.toggle(false)).should eq("")
      end

      it "toggles to disable, then enable" do
        colorize(obj, fore: :red, &.toggle(false).toggle(true)).should eq("\e[31m\e[0m")
      end
    end
  end

  describe Colorize::IOExtension do
    describe "colorizable" do
      it "creates a new Colorize::ColorizableIO instance" do
        original = IO::Memory.new
        colorizable = original.to_colorizable
        colorizable.should be_a(Colorize::ColorizableIO)
        colorizable.should_not be(original)
        colorizable.should be_a(Colorize::IO)
        colorizable.as(Colorize::IO).io.should be(original)
      end

      it "s default policy is always" do
        IO::Memory.new.to_colorizable.colorize_when.should eq(Colorize::When::Always)
      end

      it "creates a new Colorize::ColorizableIO instance with specified policy" do
        original = IO::Memory.new
        colorizable = original.to_colorizable(:never)
        colorizable.should_not be(original)
        colorizable.colorize_when.should eq(Colorize::When::Never)
      end

      it "returns itself if it is a Colorize::ColorizableIO" do
        original = FakeTTY.new
        colorizable = original.to_colorizable
        colorizable.should be_a(Colorize::ColorizableIO)
        colorizable.should be(original)
      end

      it "returns itself if it is a Colorize::ColorizableIO with original policy" do
        original = FakeTTY.new
        colorizable = original.to_colorizable(:never)
        colorizable.should be_a(Colorize::ColorizableIO)
        colorizable.should be(original)
        colorizable.colorize_when.should eq(Colorize::When::Always)
      end
    end
  end

  describe Colorize::ColorizableIO do
    it "IO::FileDescriptor is a Colorize::ColorizableIO" do
      File.open(__FILE__) do |f|
        f.should be_a(Colorize::ColorizableIO)
      end
    end

    describe "#colorize_when" do
      it "default value on IO::FileDescriptor is Colorize::When::Auto" do
        File.open(__FILE__) do |f|
          f.colorize_when.should eq(Colorize::When::Auto)
        end
      end

      it "invoke block with specified policy" do
        tty = FakeTTY.new
        tty.colorize_when(Colorize::When::Never) do |io|
          io.colorize_when.should eq(Colorize::When::Never)
        end
        tty.colorize_when.should eq(Colorize::When::Always)
      end
    end

    describe "#colorize_when=" do
      it "sets policies" do
        tty = FakeTTY.new
        {% for policy in Colorize::When.constants %}
          tty.colorize_when = Colorize::When::{{policy}}
          tty.colorize_when.should eq(Colorize::When::{{policy}})
          tty.colorize_when = {{policy.underscore.stringify}}
          tty.colorize_when.should eq(Colorize::When::{{policy}})
          tty.colorize_when = {{policy.underscore.symbolize}}
          tty.colorize_when.should eq(Colorize::When::{{policy}})
        {% end %}
      end

      it "raises on unknown policy symbol" do
        expect_raises ArgumentError, "unknown policy: bad" do
          FakeTTY.new.colorize_when = :bad
        end
      end

      it "raises on unknown policy string" do
        expect_raises ArgumentError, "unknown policy: bad" do
          FakeTTY.new.colorize_when = "bad"
        end
      end
    end

    describe "#surround" do
      it "colorizes with surround stack" do
        FakeTTY.new.tap do |io|
          io.surround(with_color.red) do |io|
            io << "hello"
            io.surround(with_color.green.bold) do |io|
              io << "world"
            end
            io << "bye"
          end
        end.to_s.should eq("\e[31mhello\e[0;32;1mworld\e[0;31mbye\e[0m")
      end

      it "colorizes with surround stack having Object" do
        FakeTTY.new.tap do |io|
          io.surround(with_color.red) do |io|
            io << "hello"
            io << "world".colorize.green.bold
            io << "bye"
          end
        end.to_s.should eq("\e[31mhello\e[0;32;1mworld\e[0;31mbye\e[0m")
      end

      it "colorizes with surround stack having same styles" do
        FakeTTY.new.tap do |io|
          io.surround(with_color.red) do |io|
            io << "hello"
            io.surround(with_color.red) do |io|
              io << "world"
            end
            io << "bye"
          end
        end.to_s.should eq("\e[31mhelloworldbye\e[0m")
      end

      it "colorizes with surround stack having default styles" do
        FakeTTY.new.tap do |io|
          io.surround(with_color) do |io|
            io << "hello"
            io.surround(with_color) do |io|
              io << "foo"
              io.surround(with_color.green) do |io|
                io << "fizz"
                io.surround(with_color) do |io|
                  io << "world"
                end
                io << "buzz"
              end
              io << "bar"
            end
            io << "bye"
          end
        end.to_s.should eq("hellofoo\e[32mfizz\e[0mworld\e[32mbuzz\e[0mbarbye")
      end
    end
  end

  describe Colorize::Builder do
    describe "#<<" do
      it "accepts some objects" do
        io = Colorize::Builder.new
        (io << "foo" << :foo << 1).should be(io)

        io.@contents.size.should eq(1)
        io.@contents[0].to_s.should eq("foofoo1")
      end

      it "accepts Colorize::Object" do
        io = Colorize::Builder.new
        (io << "foo".colorize.red << "bar".colorize.blue).should be(io)

        io.@contents.size.should eq(2)
        io.@contents[0].should eq("foo".colorize.red)
        io.@contents[1].should eq("bar".colorize.blue)
      end

      it "accepts mixed objects" do
        io = Colorize::Builder.new
        (io << 1.1 << "foo".colorize.red << :bar << 42).should be(io)

        io.@contents.size.should eq(3)
        io.@contents[0].to_s.should eq("1.1")
        io.@contents[1].should eq("foo".colorize.red)
        io.@contents[2].to_s.should eq("bar42")
      end
    end

    describe "#surround" do
      it "creates a new builder" do
        io = Colorize::Builder.new
        io.surround(with_color.red) do |io2|
          io.should_not be(io2)
        end
      end

      it "surrounds objects" do
        io = Colorize::Builder.new
        io.surround(with_color.red) do |io2|
          io2 << "foo".colorize.bold
        end

        io.@contents.size.should eq(1)
        io.@contents[0].should be_a(Colorize::Object(Colorize::Builder))

        io2 = io.@contents[0].as(Colorize::Object(Colorize::Builder)).object
        io2.@contents.size.should eq(1)
        io2.@contents[0].should eq("foo".colorize.bold)
      end
    end

    describe "#to_s" do
      it "outputs objects" do
        io = Colorize::Builder.new
        io << "foo" << :foo << 1
        io.to_s.should eq("foofoo1")
      end

      it "outputs Colorize::Object" do
        io = Colorize::Builder.new
        io << "foo".colorize.red << :bar.colorize.blue
        io.to_s.should eq("\e[31mfoo\e[0m\e[34mbar\e[0m")
      end

      it "outputs mixed objects" do
        io = Colorize::Builder.new
        io << "foo".colorize.red << :bar << 42
        io.to_s.should eq("\e[31mfoo\e[0mbar42")
      end

      it "outputs mixed objects, but colorizes dependeing on io" do
        io = Colorize::Builder.new
        io << "foo".colorize.red << :bar << 42
        String.build do |str|
          io.to_s str.to_colorizable(:never)
        end.should eq("foobar42")
      end
    end

    describe "#to_s_without_colorize" do
      it "does not colorize" do
        io = Colorize::Builder.new
        io << "foo".colorize.red << :bar << 42
        io.to_s_without_colorize.should eq("foobar42")
      end

      it "does not change colorize_when" do
        io = Colorize::Builder.new
        io << "foo".colorize.red << :bar << 42
        mem = IO::Memory.new.to_colorizable(:auto)
        mem.colorize_when.should eq(Colorize::When::Auto)
        io.to_s_without_colorize mem
        mem.io.to_s.should eq("foobar42")
        mem.colorize_when.should eq(Colorize::When::Auto)
      end
    end
  end
end
