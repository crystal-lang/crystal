require "spec"
require "colorize"

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

describe "colorize" do
  it "colorizes without change" do
    colorize("hello").to_s.should eq("hello")
  end

  it "colorizes foreground" do
    colorize("hello").black.to_s.should eq("\e[30mhello\e[0m")
    colorize("hello").red.to_s.should eq("\e[31mhello\e[0m")
    colorize("hello").green.to_s.should eq("\e[32mhello\e[0m")
    colorize("hello").yellow.to_s.should eq("\e[33mhello\e[0m")
    colorize("hello").blue.to_s.should eq("\e[34mhello\e[0m")
    colorize("hello").magenta.to_s.should eq("\e[35mhello\e[0m")
    colorize("hello").cyan.to_s.should eq("\e[36mhello\e[0m")
    colorize("hello").light_gray.to_s.should eq("\e[37mhello\e[0m")
    colorize("hello").dark_gray.to_s.should eq("\e[90mhello\e[0m")
    colorize("hello").light_red.to_s.should eq("\e[91mhello\e[0m")
    colorize("hello").light_green.to_s.should eq("\e[92mhello\e[0m")
    colorize("hello").light_yellow.to_s.should eq("\e[93mhello\e[0m")
    colorize("hello").light_blue.to_s.should eq("\e[94mhello\e[0m")
    colorize("hello").light_magenta.to_s.should eq("\e[95mhello\e[0m")
    colorize("hello").light_cyan.to_s.should eq("\e[96mhello\e[0m")
    colorize("hello").white.to_s.should eq("\e[97mhello\e[0m")
  end

  it "colorizes foreground with 8-bit color" do
    colorize("hello").fore(Colorize::Color256.new(123u8)).to_s.should eq("\e[38;5;123mhello\e[0m")
    colorize("hello").fore(123u8).to_s.should eq("\e[38;5;123mhello\e[0m")
    colorize("hello", 123_u8).to_s.should eq("\e[38;5;123mhello\e[0m")
  end

  it "colorizes foreground with true color" do
    colorize("hello").fore(Colorize::ColorRGB.new(12u8, 34u8, 56u8)).to_s.should eq("\e[38;2;12;34;56mhello\e[0m")
    colorize("hello").fore(12u8, 34u8, 56u8).to_s.should eq("\e[38;2;12;34;56mhello\e[0m")
    colorize("hello", 12u8, 34u8, 56u8).to_s.should eq("\e[38;2;12;34;56mhello\e[0m")
  end

  it "colorizes background" do
    colorize("hello").on_black.to_s.should eq("\e[40mhello\e[0m")
    colorize("hello").on_red.to_s.should eq("\e[41mhello\e[0m")
    colorize("hello").on_green.to_s.should eq("\e[42mhello\e[0m")
    colorize("hello").on_yellow.to_s.should eq("\e[43mhello\e[0m")
    colorize("hello").on_blue.to_s.should eq("\e[44mhello\e[0m")
    colorize("hello").on_magenta.to_s.should eq("\e[45mhello\e[0m")
    colorize("hello").on_cyan.to_s.should eq("\e[46mhello\e[0m")
    colorize("hello").on_light_gray.to_s.should eq("\e[47mhello\e[0m")
    colorize("hello").on_dark_gray.to_s.should eq("\e[100mhello\e[0m")
    colorize("hello").on_light_red.to_s.should eq("\e[101mhello\e[0m")
    colorize("hello").on_light_green.to_s.should eq("\e[102mhello\e[0m")
    colorize("hello").on_light_yellow.to_s.should eq("\e[103mhello\e[0m")
    colorize("hello").on_light_blue.to_s.should eq("\e[104mhello\e[0m")
    colorize("hello").on_light_magenta.to_s.should eq("\e[105mhello\e[0m")
    colorize("hello").on_light_cyan.to_s.should eq("\e[106mhello\e[0m")
    colorize("hello").on_white.to_s.should eq("\e[107mhello\e[0m")
  end

  it "colorizes background with 8-bit color" do
    colorize("hello").back(Colorize::Color256.new(123u8)).to_s.should eq("\e[48;5;123mhello\e[0m")
    colorize("hello").back(123u8).to_s.should eq("\e[48;5;123mhello\e[0m")
  end

  it "colorizes background with true color" do
    colorize("hello").back(Colorize::ColorRGB.new(12u8, 34u8, 56u8)).to_s.should eq("\e[48;2;12;34;56mhello\e[0m")
    colorize("hello").back(12u8, 34u8, 56u8).to_s.should eq("\e[48;2;12;34;56mhello\e[0m")
  end

  it "colorizes mode" do
    colorize("hello").bold.to_s.should eq("\e[1mhello\e[0m")
    colorize("hello").bright.to_s.should eq("\e[1mhello\e[0m")
    colorize("hello").dim.to_s.should eq("\e[2mhello\e[0m")
    colorize("hello").italic.to_s.should eq("\e[3mhello\e[0m")
    colorize("hello").underline.to_s.should eq("\e[4mhello\e[0m")
    colorize("hello").blink.to_s.should eq("\e[5mhello\e[0m")
    colorize("hello").blink_fast.to_s.should eq("\e[6mhello\e[0m")
    colorize("hello").reverse.to_s.should eq("\e[7mhello\e[0m")
    colorize("hello").hidden.to_s.should eq("\e[8mhello\e[0m")
    colorize("hello").strikethrough.to_s.should eq("\e[9mhello\e[0m")
    colorize("hello").double_underline.to_s.should eq("\e[21mhello\e[0m")
    colorize("hello").overline.to_s.should eq("\e[53mhello\e[0m")
  end

  it "colorizes mode combination" do
    colorize("hello").bold.dim.underline.blink.reverse.hidden.to_s.should eq("\e[1;2;4;5;7;8mhello\e[0m")
  end

  it "colorizes foreground with background" do
    colorize("hello").blue.on_green.to_s.should eq("\e[34;42mhello\e[0m")
  end

  it "colorizes foreground with background with mode" do
    colorize("hello").blue.on_green.bold.to_s.should eq("\e[34;42;1mhello\e[0m")
  end

  it "colorizes foreground with symbol" do
    colorize("hello", :red).to_s.should eq("\e[31mhello\e[0m")
    colorize("hello").fore(:red).to_s.should eq("\e[31mhello\e[0m")
  end

  it "colorizes mode with symbol" do
    colorize("hello").mode(:bold).to_s.should eq("\e[1mhello\e[0m")
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
    colorize("hello", :red).inspect.should eq("\e[31m\"hello\"\e[0m")
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
    io.to_s.should eq("\e[31mhello\e[0;32mworld\e[0;31mbye\e[0m")
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
    io.to_s.should eq("\e[31mhello\e[0;32;1mworld\e[0;31mbye\e[0m")
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
    io.to_s.should eq("\e[31mhelloworldbye\e[0m")
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
    io.to_s.should eq("\e[31mhello\e[0mworld\e[31mbye\e[0m")
  end

  it "colorizes with to_s" do
    colorize(ColorizeToS.new).red.to_s.should eq("\e[31mhello\e[0;34mworld\e[0;31mbye\e[0m")
  end

  it "toggles off" do
    colorize("hello").black.toggle(false).to_s.should eq("hello")
    colorize("hello").toggle(false).black.to_s.should eq("hello")
  end

  it "toggles off and on" do
    colorize("hello").toggle(false).black.toggle(true).to_s.should eq("\e[30mhello\e[0m")
  end
end
