require "spec"
require "colorize"

describe "colorize" do
  it "colorizes without change" do
    "hello".colorize.to_s.should eq("hello")
  end

  it "colorizes foreground" do
    "hello".colorize.black.to_s.should eq("\e[30mhello\e[0m")
    "hello".colorize.red.to_s.should eq("\e[31mhello\e[0m")
    "hello".colorize.green.to_s.should eq("\e[32mhello\e[0m")
    "hello".colorize.yellow.to_s.should eq("\e[33mhello\e[0m")
    "hello".colorize.blue.to_s.should eq("\e[34mhello\e[0m")
    "hello".colorize.magenta.to_s.should eq("\e[35mhello\e[0m")
    "hello".colorize.cyan.to_s.should eq("\e[36mhello\e[0m")
    "hello".colorize.light_gray.to_s.should eq("\e[37mhello\e[0m")
    "hello".colorize.dark_gray.to_s.should eq("\e[90mhello\e[0m")
    "hello".colorize.light_red.to_s.should eq("\e[91mhello\e[0m")
    "hello".colorize.light_green.to_s.should eq("\e[92mhello\e[0m")
    "hello".colorize.light_yellow.to_s.should eq("\e[93mhello\e[0m")
    "hello".colorize.light_blue.to_s.should eq("\e[94mhello\e[0m")
    "hello".colorize.light_magenta.to_s.should eq("\e[95mhello\e[0m")
    "hello".colorize.light_cyan.to_s.should eq("\e[96mhello\e[0m")
    "hello".colorize.white.to_s.should eq("\e[97mhello\e[0m")
  end

  it "colorizes background" do
    "hello".colorize.on_black.to_s.should eq("\e[40mhello\e[0m")
    "hello".colorize.on_red.to_s.should eq("\e[41mhello\e[0m")
    "hello".colorize.on_green.to_s.should eq("\e[42mhello\e[0m")
    "hello".colorize.on_yellow.to_s.should eq("\e[43mhello\e[0m")
    "hello".colorize.on_blue.to_s.should eq("\e[44mhello\e[0m")
    "hello".colorize.on_magenta.to_s.should eq("\e[45mhello\e[0m")
    "hello".colorize.on_cyan.to_s.should eq("\e[46mhello\e[0m")
    "hello".colorize.on_light_gray.to_s.should eq("\e[47mhello\e[0m")
    "hello".colorize.on_dark_gray.to_s.should eq("\e[100mhello\e[0m")
    "hello".colorize.on_light_red.to_s.should eq("\e[101mhello\e[0m")
    "hello".colorize.on_light_green.to_s.should eq("\e[102mhello\e[0m")
    "hello".colorize.on_light_yellow.to_s.should eq("\e[103mhello\e[0m")
    "hello".colorize.on_light_blue.to_s.should eq("\e[104mhello\e[0m")
    "hello".colorize.on_light_magenta.to_s.should eq("\e[105mhello\e[0m")
    "hello".colorize.on_light_cyan.to_s.should eq("\e[106mhello\e[0m")
    "hello".colorize.on_white.to_s.should eq("\e[107mhello\e[0m")
  end

  it "colorizes mode" do
    "hello".colorize.bold.to_s.should eq("\e[1mhello\e[0m")
    "hello".colorize.bright.to_s.should eq("\e[1mhello\e[0m")
    "hello".colorize.dim.to_s.should eq("\e[2mhello\e[0m")
    "hello".colorize.underline.to_s.should eq("\e[4mhello\e[0m")
    "hello".colorize.blink.to_s.should eq("\e[5mhello\e[0m")
    "hello".colorize.reverse.to_s.should eq("\e[7mhello\e[0m")
    "hello".colorize.hidden.to_s.should eq("\e[8mhello\e[0m")
  end

  it "colorizes mode combination" do
    "hello".colorize.bold.dim.underline.blink.reverse.hidden.to_s.should eq("\e[1;2;4;5;7;8mhello\e[0m")
  end

  it "colorizes foreground with background" do
    "hello".colorize.blue.on_green.to_s.should eq("\e[34;42mhello\e[0m")
  end

  it "colorizes foreground with background with mode" do
    "hello".colorize.blue.on_green.bold.to_s.should eq("\e[34;42;1mhello\e[0m")
  end

  it "colorizes foreground with symbol" do
    "hello".colorize(:red).to_s.should eq("\e[31mhello\e[0m")
    "hello".colorize.fore(:red).to_s.should eq("\e[31mhello\e[0m")
  end

  it "colorizes mode with symbol" do
    "hello".colorize.mode(:bold).to_s.should eq("\e[1mhello\e[0m")
  end

  it "raises on unknown foreground color" do
    expect_raises ArgumentError, "unknown color: brown" do
      "hello".colorize(:brown)
    end
  end

  it "raises on unknown background color" do
    expect_raises ArgumentError, "unknown color: brown" do
      "hello".colorize.back(:brown)
    end
  end

  it "raises on unknown mode" do
    expect_raises ArgumentError, "unknown mode: bad" do
      "hello".colorize.mode(:bad)
    end
  end

  it "inspects" do
    "hello".colorize(:red).inspect.should eq("\e[31m\"hello\"\e[0m")
  end

  it "colorizes io with method" do
    io = StringIO.new
    with_color.red.surround(io) do
      io << "hello"
    end
    io.to_s.should eq("\e[31mhello\e[0m")
  end

  it "colorizes io with symbol" do
    io = StringIO.new
    with_color(:red).surround(io) do
      io << "hello"
    end
    io.to_s.should eq("\e[31mhello\e[0m")
  end

  it "colorizes with push and pop" do
    io = StringIO.new
    with_color.red.push(io) do
      io << "hello"
      with_color.green.push(io) do
        io << "world"
      end
      io << "bye"
    end
    io.to_s.should eq("\e[31mhello\e[0;32mworld\e[0;31mbye\e[0m")
  end

  it "colorizes with push and pop resets" do
    io = StringIO.new
    with_color.red.push(io) do
      io << "hello"
      with_color.green.bold.push(io) do
        io << "world"
      end
      io << "bye"
    end
    io.to_s.should eq("\e[31mhello\e[0;32;1mworld\e[0;31mbye\e[0m")
  end
end
