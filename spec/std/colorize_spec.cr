require "spec"
require "colorize"

describe "colorize" do
  it "colorizes without change" do
    expect("hello".colorize.to_s).to eq("hello")
  end

  it "colorizes foreground" do
    expect("hello".colorize.black.to_s).to eq("\e[30mhello\e[0m")
    expect("hello".colorize.red.to_s).to eq("\e[31mhello\e[0m")
    expect("hello".colorize.green.to_s).to eq("\e[32mhello\e[0m")
    expect("hello".colorize.yellow.to_s).to eq("\e[33mhello\e[0m")
    expect("hello".colorize.blue.to_s).to eq("\e[34mhello\e[0m")
    expect("hello".colorize.magenta.to_s).to eq("\e[35mhello\e[0m")
    expect("hello".colorize.cyan.to_s).to eq("\e[36mhello\e[0m")
    expect("hello".colorize.light_gray.to_s).to eq("\e[37mhello\e[0m")
    expect("hello".colorize.dark_gray.to_s).to eq("\e[90mhello\e[0m")
    expect("hello".colorize.light_red.to_s).to eq("\e[91mhello\e[0m")
    expect("hello".colorize.light_green.to_s).to eq("\e[92mhello\e[0m")
    expect("hello".colorize.light_yellow.to_s).to eq("\e[93mhello\e[0m")
    expect("hello".colorize.light_blue.to_s).to eq("\e[94mhello\e[0m")
    expect("hello".colorize.light_magenta.to_s).to eq("\e[95mhello\e[0m")
    expect("hello".colorize.light_cyan.to_s).to eq("\e[96mhello\e[0m")
    expect("hello".colorize.white.to_s).to eq("\e[97mhello\e[0m")
  end

  it "colorizes background" do
    expect("hello".colorize.on_black.to_s).to eq("\e[40mhello\e[0m")
    expect("hello".colorize.on_red.to_s).to eq("\e[41mhello\e[0m")
    expect("hello".colorize.on_green.to_s).to eq("\e[42mhello\e[0m")
    expect("hello".colorize.on_yellow.to_s).to eq("\e[43mhello\e[0m")
    expect("hello".colorize.on_blue.to_s).to eq("\e[44mhello\e[0m")
    expect("hello".colorize.on_magenta.to_s).to eq("\e[45mhello\e[0m")
    expect("hello".colorize.on_cyan.to_s).to eq("\e[46mhello\e[0m")
    expect("hello".colorize.on_light_gray.to_s).to eq("\e[47mhello\e[0m")
    expect("hello".colorize.on_dark_gray.to_s).to eq("\e[100mhello\e[0m")
    expect("hello".colorize.on_light_red.to_s).to eq("\e[101mhello\e[0m")
    expect("hello".colorize.on_light_green.to_s).to eq("\e[102mhello\e[0m")
    expect("hello".colorize.on_light_yellow.to_s).to eq("\e[103mhello\e[0m")
    expect("hello".colorize.on_light_blue.to_s).to eq("\e[104mhello\e[0m")
    expect("hello".colorize.on_light_magenta.to_s).to eq("\e[105mhello\e[0m")
    expect("hello".colorize.on_light_cyan.to_s).to eq("\e[106mhello\e[0m")
    expect("hello".colorize.on_white.to_s).to eq("\e[107mhello\e[0m")
  end

  it "colorizes mode" do
    expect("hello".colorize.bold.to_s).to eq("\e[1mhello\e[0m")
    expect("hello".colorize.bright.to_s).to eq("\e[1mhello\e[0m")
    expect("hello".colorize.dim.to_s).to eq("\e[2mhello\e[0m")
    expect("hello".colorize.underline.to_s).to eq("\e[4mhello\e[0m")
    expect("hello".colorize.blink.to_s).to eq("\e[5mhello\e[0m")
    expect("hello".colorize.reverse.to_s).to eq("\e[7mhello\e[0m")
    expect("hello".colorize.hidden.to_s).to eq("\e[8mhello\e[0m")
  end

  it "colorizes mode combination" do
    expect("hello".colorize.bold.dim.underline.blink.reverse.hidden.to_s).to eq("\e[1;2;4;5;7;8mhello\e[0m")
  end

  it "colorizes foreground with background" do
    expect("hello".colorize.blue.on_green.to_s).to eq("\e[34;42mhello\e[0m")
  end

  it "colorizes foreground with background with mode" do
    expect("hello".colorize.blue.on_green.bold.to_s).to eq("\e[34;42;1mhello\e[0m")
  end

  it "colorizes foreground with symbol" do
    expect("hello".colorize(:red).to_s).to eq("\e[31mhello\e[0m")
    expect("hello".colorize.fore(:red).to_s).to eq("\e[31mhello\e[0m")
  end

  it "colorizes mode with symbol" do
    expect("hello".colorize.mode(:bold).to_s).to eq("\e[1mhello\e[0m")
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
    expect("hello".colorize(:red).inspect).to eq("\e[31m\"hello\"\e[0m")
  end

  it "colorizes io with method" do
    io = StringIO.new
    with_color.red.surround(io) do
      io << "hello"
    end
    expect(io.to_s).to eq("\e[31mhello\e[0m")
  end

  it "colorizes io with symbol" do
    io = StringIO.new
    with_color(:red).surround(io) do
      io << "hello"
    end
    expect(io.to_s).to eq("\e[31mhello\e[0m")
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
    expect(io.to_s).to eq("\e[31mhello\e[0;32mworld\e[0;31mbye\e[0m")
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
    expect(io.to_s).to eq("\e[31mhello\e[0;32;1mworld\e[0;31mbye\e[0m")
  end

  it "toggles off" do
    expect("hello".colorize.black.toggle(false).to_s).to eq("hello")
    expect("hello".colorize.toggle(false).black.to_s).to eq("hello")
  end

  it "toggles off and on" do
    expect("hello".colorize.toggle(false).black.toggle(true).to_s).to eq("\e[30mhello\e[0m")
  end
end
