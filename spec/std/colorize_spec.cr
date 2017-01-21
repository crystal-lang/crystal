require "spec"
require "colorize"

private class FakeTTY < IO::Memory
  def tty?
    true
  end
end

private def colorize(obj, io = IO::Memory.new,  **args)
  if obj
    yield(obj.colorize(**args).when(:always).when(args[:when]?)).to_s io
  else
    yield(with_color(**args).when(:always).when(args[:when]?)).as(Colorize::Style).surround(io) { }
  end
  io.to_s
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
        colorize(obj, when: :auto, &.black).should eq("")
        colorize(obj, when: "auto", &.black).should eq("")
        colorize(obj, when: Colorize::When::Auto, &.black).should eq("")
        colorize(obj, &.black.auto).should eq("")
        colorize(obj, &.black.when(:auto)).should eq("")
        colorize(obj, &.black.when("auto")).should eq("")
        colorize(obj, &.black.when(Colorize::When::Auto)).should eq("")

        colorize(obj, io: FakeTTY.new, when: :auto, &.black).should eq("\e[30m\e[0m")
        colorize(obj, io: FakeTTY.new, when: "auto", &.black).should eq("\e[30m\e[0m")
        colorize(obj, io: FakeTTY.new, when: Colorize::When::Auto, &.black).should eq("\e[30m\e[0m")
        colorize(obj, io: FakeTTY.new, &.black.auto).should eq("\e[30m\e[0m")
        colorize(obj, io: FakeTTY.new, &.black.when(:auto)).should eq("\e[30m\e[0m")
        colorize(obj, io: FakeTTY.new, &.black.when("auto")).should eq("\e[30m\e[0m")
        colorize(obj, io: FakeTTY.new, &.black.when(Colorize::When::Auto)).should eq("\e[30m\e[0m")
      end

      it "colorizes always" do
        colorize(obj, when: :always, &.black).should eq("\e[30m\e[0m")
        colorize(obj, when: "always", &.black).should eq("\e[30m\e[0m")
        colorize(obj, when: Colorize::When::Always, &.black).should eq("\e[30m\e[0m")
        colorize(obj, &.black.always).should eq("\e[30m\e[0m")
        colorize(obj, &.black.when(:always)).should eq("\e[30m\e[0m")
        colorize(obj, &.black.when("always")).should eq("\e[30m\e[0m")
        colorize(obj, &.black.when(Colorize::When::Always)).should eq("\e[30m\e[0m")

        colorize(obj, io: FakeTTY.new, when: :always, &.black).should eq("\e[30m\e[0m")
        colorize(obj, io: FakeTTY.new, when: "always", &.black).should eq("\e[30m\e[0m")
        colorize(obj, io: FakeTTY.new, when: Colorize::When::Always, &.black).should eq("\e[30m\e[0m")
        colorize(obj, io: FakeTTY.new, &.black.always).should eq("\e[30m\e[0m")
        colorize(obj, io: FakeTTY.new, &.black.when(:always)).should eq("\e[30m\e[0m")
        colorize(obj, io: FakeTTY.new, &.black.when("always")).should eq("\e[30m\e[0m")
        colorize(obj, io: FakeTTY.new, &.black.when(Colorize::When::Always)).should eq("\e[30m\e[0m")
      end

      it "colorizes never" do
        colorize(obj, when: :never, &.black).should eq("")
        colorize(obj, when: "never", &.black).should eq("")
        colorize(obj, when: Colorize::When::Never, &.black).should eq("")
        colorize(obj, &.black.never).should eq("")
        colorize(obj, &.black.when(:never)).should eq("")
        colorize(obj, &.black.when("never")).should eq("")
        colorize(obj, &.black.when(Colorize::When::Never)).should eq("")

        colorize(obj, io: FakeTTY.new, when: :never, &.black).should eq("")
        colorize(obj, io: FakeTTY.new, when: "never", &.black).should eq("")
        colorize(obj, io: FakeTTY.new, when: Colorize::When::Never, &.black).should eq("")
        colorize(obj, io: FakeTTY.new, &.black.never).should eq("")
        colorize(obj, io: FakeTTY.new, &.black.when(:never)).should eq("")
        colorize(obj, io: FakeTTY.new, &.black.when("never")).should eq("")
        colorize(obj, io: FakeTTY.new, &.black.when(Colorize::When::Never)).should eq("")
      end

      it "is chainable but apply only last" do
        colorize(obj, &.blue.red).should eq("\e[31m\e[0m")
        colorize(obj, &.on_blue.on_red).should eq("\e[41m\e[0m")
        colorize(obj, &.always.never).should eq("")
      end

      it "toggles off" do
        colorize(obj, &.black.toggle(false)).should eq("")
        colorize(obj, &.toggle(false).black).should eq("")
      end

      it "toggles off and on" do
        colorize(obj, io: FakeTTY.new, &.toggle(false).black.toggle(true)).should eq("\e[30m\e[0m")
      end

      it "is chainable, `nil` has no effect" do
        colorize(obj, &.blue.fore(nil)).should eq("\e[34m\e[0m")
        colorize(obj, &.on_blue.back(nil)).should eq("\e[44m\e[0m")
        colorize(obj, &.bold.mode(nil)).should eq("\e[1m\e[0m")
        colorize(obj, io: FakeTTY.new, &.when(:never).when(nil)).should eq("")
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
    end
  end

  describe Colorize::Style do
    describe "#surround" do
      it "colorizes with surround stack" do
        FakeTTY.new.tap do |io|
          with_color.red.surround(io) do |io|
            io << "hello"
            with_color.green.bold.surround(io) do |io|
              io << "world"
            end
            io << "bye"
          end
        end.to_s.should eq("\e[31mhello\e[0;32;1mworld\e[0;31mbye\e[0m")
      end

      it "colorizes with surround stack having Object" do
        FakeTTY.new.tap do |io|
          with_color.red.surround(io) do |io|
            io << "hello"
            "world".colorize.green.bold.to_s io
            io << "bye"
          end
        end.to_s.should eq("\e[31mhello\e[0;32;1mworld\e[0;31mbye\e[0m")
      end

      it "colorizes with surround stack having same styles" do
        FakeTTY.new.tap do |io|
          with_color.red.surround(io) do |io|
            io << "hello"
            with_color.red.surround(io) do |io|
              io << "world"
            end
            io << "bye"
          end
        end.to_s.should eq("\e[31mhelloworldbye\e[0m")
      end

      it "colorizes with surround stack having default styles" do
        io = FakeTTY.new
        with_color.surround(io) do |io|
          io << "hello"
          with_color.surround(io) do |io|
            io << "foo"
            with_color.green.surround(io) do |io|
              io << "fizz"
              with_color.surround(io) do |io|
                io << "world"
              end
              io << "buzz"
            end
            io << "bar"
          end
          io << "bye"
        end
        io.to_s.should eq("hellofoo\e[32mfizz\e[0mworld\e[32mbuzz\e[0mbarbye")
      end
    end
  end
end

