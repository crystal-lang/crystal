require "spec"
require "colorize"
require "../support/env"

private def colorize(obj, *args)
  obj.colorize(*args).toggle(true)
end

private def with_color_wrap(*args)
  Colorize.with(*args).toggle(true)
end

private class ColorizeToS
  def to_s(io)
    io << "hello"
    io << ::colorize("world").blue
    io << "bye"
  end
end

private class ColorizeTTY < IO
  def tty? : Bool
    true
  end

  def read(slice : Bytes)
    0
  end

  def write(slice : Bytes) : Nil
  end
end

describe "colorize" do
  it ".default_enabled?" do
    io = IO::Memory.new
    tty = ColorizeTTY.new

    with_env("TERM": nil, "NO_COLOR": nil) do
      Colorize.default_enabled?(io).should be_false
      Colorize.default_enabled?(tty).should be_true
      Colorize.default_enabled?(io, io).should be_false
      Colorize.default_enabled?(io, tty).should be_false
      Colorize.default_enabled?(tty, io).should be_false
      Colorize.default_enabled?(tty, tty).should be_true
    end

    with_env("TERM": nil, "NO_COLOR": "") do
      Colorize.default_enabled?(io).should be_false
      Colorize.default_enabled?(tty).should be_true
      Colorize.default_enabled?(io, io).should be_false
      Colorize.default_enabled?(io, tty).should be_false
      Colorize.default_enabled?(tty, io).should be_false
      Colorize.default_enabled?(tty, tty).should be_true
    end

    with_env("TERM": nil, "NO_COLOR": "1") do
      Colorize.default_enabled?(io).should be_false
      Colorize.default_enabled?(tty).should be_false
      Colorize.default_enabled?(io, io).should be_false
      Colorize.default_enabled?(io, tty).should be_false
      Colorize.default_enabled?(tty, io).should be_false
      Colorize.default_enabled?(tty, tty).should be_false
    end

    with_env("TERM": "xterm", "NO_COLOR": nil) do
      Colorize.default_enabled?(io).should be_false
      Colorize.default_enabled?(tty).should be_true
      Colorize.default_enabled?(io, io).should be_false
      Colorize.default_enabled?(io, tty).should be_false
      Colorize.default_enabled?(tty, io).should be_false
      Colorize.default_enabled?(tty, tty).should be_true
    end

    with_env("TERM": "dumb", "NO_COLOR": nil) do
      Colorize.default_enabled?(io).should be_false
      Colorize.default_enabled?(tty).should be_false
      Colorize.default_enabled?(io, io).should be_false
      Colorize.default_enabled?(io, tty).should be_false
      Colorize.default_enabled?(tty, io).should be_false
      Colorize.default_enabled?(tty, tty).should be_false
    end
  end

  it "colorizes without change" do
    colorize("hello").to_s.should eq("hello")
  end

  it "colorizes foreground" do
    colorize("hello").black.to_s.should eq("\e[30mhello\e[39m")
    colorize("hello").red.to_s.should eq("\e[31mhello\e[39m")
    colorize("hello").green.to_s.should eq("\e[32mhello\e[39m")
    colorize("hello").yellow.to_s.should eq("\e[33mhello\e[39m")
    colorize("hello").blue.to_s.should eq("\e[34mhello\e[39m")
    colorize("hello").magenta.to_s.should eq("\e[35mhello\e[39m")
    colorize("hello").cyan.to_s.should eq("\e[36mhello\e[39m")
    colorize("hello").light_gray.to_s.should eq("\e[37mhello\e[39m")
    colorize("hello").dark_gray.to_s.should eq("\e[90mhello\e[39m")
    colorize("hello").light_red.to_s.should eq("\e[91mhello\e[39m")
    colorize("hello").light_green.to_s.should eq("\e[92mhello\e[39m")
    colorize("hello").light_yellow.to_s.should eq("\e[93mhello\e[39m")
    colorize("hello").light_blue.to_s.should eq("\e[94mhello\e[39m")
    colorize("hello").light_magenta.to_s.should eq("\e[95mhello\e[39m")
    colorize("hello").light_cyan.to_s.should eq("\e[96mhello\e[39m")
    colorize("hello").white.to_s.should eq("\e[97mhello\e[39m")
  end

  it "colorizes foreground with 8-bit color" do
    colorize("hello").fore(Colorize::Color256.new(123u8)).to_s.should eq("\e[38;5;123mhello\e[39m")
    colorize("hello").fore(123u8).to_s.should eq("\e[38;5;123mhello\e[39m")
    colorize("hello", 123_u8).to_s.should eq("\e[38;5;123mhello\e[39m")
  end

  it "colorizes foreground with true color" do
    colorize("hello").fore(Colorize::ColorRGB.new(12u8, 34u8, 56u8)).to_s.should eq("\e[38;2;12;34;56mhello\e[39m")
    colorize("hello").fore(12u8, 34u8, 56u8).to_s.should eq("\e[38;2;12;34;56mhello\e[39m")
    colorize("hello", 12u8, 34u8, 56u8).to_s.should eq("\e[38;2;12;34;56mhello\e[39m")
  end

  it "colorizes background" do
    colorize("hello").on_black.to_s.should eq("\e[40mhello\e[49m")
    colorize("hello").on_red.to_s.should eq("\e[41mhello\e[49m")
    colorize("hello").on_green.to_s.should eq("\e[42mhello\e[49m")
    colorize("hello").on_yellow.to_s.should eq("\e[43mhello\e[49m")
    colorize("hello").on_blue.to_s.should eq("\e[44mhello\e[49m")
    colorize("hello").on_magenta.to_s.should eq("\e[45mhello\e[49m")
    colorize("hello").on_cyan.to_s.should eq("\e[46mhello\e[49m")
    colorize("hello").on_light_gray.to_s.should eq("\e[47mhello\e[49m")
    colorize("hello").on_dark_gray.to_s.should eq("\e[100mhello\e[49m")
    colorize("hello").on_light_red.to_s.should eq("\e[101mhello\e[49m")
    colorize("hello").on_light_green.to_s.should eq("\e[102mhello\e[49m")
    colorize("hello").on_light_yellow.to_s.should eq("\e[103mhello\e[49m")
    colorize("hello").on_light_blue.to_s.should eq("\e[104mhello\e[49m")
    colorize("hello").on_light_magenta.to_s.should eq("\e[105mhello\e[49m")
    colorize("hello").on_light_cyan.to_s.should eq("\e[106mhello\e[49m")
    colorize("hello").on_white.to_s.should eq("\e[107mhello\e[49m")
  end

  it "colorizes background with 8-bit color" do
    colorize("hello").back(Colorize::Color256.new(123u8)).to_s.should eq("\e[48;5;123mhello\e[49m")
    colorize("hello").back(123u8).to_s.should eq("\e[48;5;123mhello\e[49m")
  end

  it "colorizes background with true color" do
    colorize("hello").back(Colorize::ColorRGB.new(12u8, 34u8, 56u8)).to_s.should eq("\e[48;2;12;34;56mhello\e[49m")
    colorize("hello").back(12u8, 34u8, 56u8).to_s.should eq("\e[48;2;12;34;56mhello\e[49m")
  end

  it "colorizes mode" do
    colorize("hello").bold.to_s.should eq("\e[1mhello\e[22m")
    colorize("hello").bright.to_s.should eq("\e[1mhello\e[22m")
    colorize("hello").dim.to_s.should eq("\e[2mhello\e[22m")
    colorize("hello").italic.to_s.should eq("\e[3mhello\e[23m")
    colorize("hello").underline.to_s.should eq("\e[4mhello\e[24m")
    colorize("hello").blink.to_s.should eq("\e[5mhello\e[25m")
    colorize("hello").blink_fast.to_s.should eq("\e[6mhello\e[26m")
    colorize("hello").reverse.to_s.should eq("\e[7mhello\e[27m")
    colorize("hello").hidden.to_s.should eq("\e[8mhello\e[28m")
    colorize("hello").strikethrough.to_s.should eq("\e[9mhello\e[29m")
    colorize("hello").double_underline.to_s.should eq("\e[21mhello\e[24m")
    colorize("hello").overline.to_s.should eq("\e[53mhello\e[55m")
  end

  it "prints colorize ANSI escape codes" do
    Colorize.with.bold.ansi_escape.should eq("\e[1m")
    Colorize.with.bright.ansi_escape.should eq("\e[1m")
    Colorize.with.dim.ansi_escape.should eq("\e[2m")
    Colorize.with.italic.ansi_escape.should eq("\e[3m")
    Colorize.with.underline.ansi_escape.should eq("\e[4m")
    Colorize.with.blink.ansi_escape.should eq("\e[5m")
    Colorize.with.blink_fast.ansi_escape.should eq("\e[6m")
    Colorize.with.reverse.ansi_escape.should eq("\e[7m")
    Colorize.with.hidden.ansi_escape.should eq("\e[8m")
    Colorize.with.strikethrough.ansi_escape.should eq("\e[9m")
    Colorize.with.double_underline.ansi_escape.should eq("\e[21m")
    Colorize.with.overline.ansi_escape.should eq("\e[53m")
  end

  it "only prints colorize ANSI escape codes" do
    colorize("hello").red.bold.ansi_escape.should eq("\e[31;1m")
    colorize("hello").bold.dim.underline.blink.reverse.hidden.ansi_escape.should eq("\e[1;2;4;5;7;8m")
  end

  it "colorizes mode combination" do
    colorize("hello").bold.dim.underline.blink.reverse.hidden.to_s.should eq("\e[1;2;4;5;7;8mhello\e[22;22;24;25;27;28m")
  end

  it "colorizes foreground with background" do
    colorize("hello").blue.on_green.to_s.should eq("\e[34;42mhello\e[39;49m")
  end

  it "colorizes foreground with background with mode" do
    colorize("hello").blue.on_green.bold.to_s.should eq("\e[34;42;1mhello\e[39;49;22m")
  end

  it "colorizes foreground with symbol" do
    colorize("hello", :red).to_s.should eq("\e[31mhello\e[39m")
    colorize("hello").fore(:red).to_s.should eq("\e[31mhello\e[39m")
  end

  it "colorizes mode with symbol" do
    colorize("hello").mode(:bold).to_s.should eq("\e[1mhello\e[22m")
  end

  it "raises on unknown foreground color" do
    expect_raises ArgumentError, "Unknown color: brown" do
      colorize("hello", :brown)
    end
  end

  it "raises on unknown background color" do
    expect_raises ArgumentError, "Unknown color: brown" do
      colorize("hello").back(:brown)
    end
  end

  it "inspects" do
    colorize("hello", :red).inspect.should eq("\e[31m\"hello\"\e[39m")
  end

  it "colorizes with surround" do
    io = IO::Memory.new
    with_color_wrap.red.surround(io) do
      io << "hello"
      with_color_wrap.green.surround(io) do
        io << "world"
      end
      io << "bye"
    end
    io.to_s.should eq("\e[31mhello\e[39;32mworld\e[39;31mbye\e[39m")
  end

  it "colorizes with surround and reset" do
    io = IO::Memory.new
    with_color_wrap.red.surround(io) do
      io << "hello"
      with_color_wrap.green.bold.surround(io) do
        io << "world"
      end
      io << "bye"
    end
    io.to_s.should eq("\e[31mhello\e[39;32;1mworld\e[39;22;31mbye\e[39m")
  end

  it "colorizes with surround and no reset" do
    io = IO::Memory.new
    with_color_wrap.red.surround(io) do
      io << "hello"
      with_color_wrap.red.surround(io) do
        io << "world"
      end
      io << "bye"
    end
    io.to_s.should eq("\e[31mhelloworldbye\e[39m")
  end

  it "colorizes with surround and default" do
    io = IO::Memory.new
    with_color_wrap.red.surround(io) do
      io << "hello"
      with_color_wrap.surround(io) do
        io << "world"
      end
      io << "bye"
    end
    io.to_s.should eq("\e[31mhello\e[39mworld\e[31mbye\e[39m")
  end

  it "colorizes with to_s" do
    colorize(ColorizeToS.new).red.to_s.should eq("\e[31mhello\e[39;34mworld\e[39;31mbye\e[39m")
  end

  it "toggles off" do
    colorize("hello").black.toggle(false).to_s.should eq("hello")
    colorize("hello").toggle(false).black.to_s.should eq("hello")
  end

  it "toggles off and on" do
    colorize("hello").toggle(false).black.toggle(true).to_s.should eq("\e[30mhello\e[39m")
  end

  it "colorizes nested strings" do
    colorize("hello #{colorize("foo").red} bar").underline.to_s.should eq("\e[4mhello \e[31mfoo\e[39m bar\e[24m")

    # TODO: Ideally this should work
    # colorize("hello #{colorize("foo").red} bar").green.to_s.should eq "\e[32mhello \e[39m\e[31mfoo\e[39m\e[32m bar\e[39m"
  end
end
