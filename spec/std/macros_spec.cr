require "spec"

describe "undent" do
  it "removes extra indent from multi-line string" do
    s = undent <<-USAGE
      Usage:
        blah [options...] {file}
      Options:
        -h --help     Show this screen.
        --version     Show version.
        --foo={value} Description of foo.
    USAGE

    s.should eq <<-EXPECTED
Usage:
  blah [options...] {file}
Options:
  -h --help     Show this screen.
  --version     Show version.
  --foo={value} Description of foo.
    EXPECTED

    s = undent <<-HERE
      This line is indented deeper
    This line has shallow indent
        This line deepest indent
    HERE

    s.should eq <<-EXPECTED
  This line is indented deeper
This line has shallow indent
    This line deepest indent
    EXPECTED
  end

  it "ignores empty lines and white space only lines" do
    s = undent <<-EMPTY_LINES

      Usage:
        blah [options...] {file}
          
      Options:
            
        -h --help     Show this screen.

        --version     Show version.

        --foo={value} Description of foo.

    EMPTY_LINES

    s.should eq <<-EXPECTED

Usage:
  blah [options...] {file}
    
Options:
      
  -h --help     Show this screen.

  --version     Show version.

  --foo={value} Description of foo.

    EXPECTED
  end

  it "removes extra indent from multi-line string interpolation" do
    section1 = "Usage"
    name = "blah"
    section2 = "Options"

    s = undent <<-USAGE
      #{section1}:
        #{name} [options...] {file}
      #{section2}:
        -h --help     Show this screen.
        --version     Show version.
        --foo={value} Description of foo.
    USAGE

    s.should eq <<-EXPECTED
Usage:
  blah [options...] {file}
Options:
  -h --help     Show this screen.
  --version     Show version.
  --foo={value} Description of foo.
    EXPECTED

    s = undent <<-HERE
      Line #{1} is indented deeper
    Line #{2} has shallow indent
        Line #{3} deepest indent
    HERE

    s.should eq <<-EXPECTED
  Line 1 is indented deeper
Line 2 has shallow indent
    Line 3 deepest indent
    EXPECTED
  end

  it "ignores empty lines and white space only lines in string interpolation" do
    section1 = "Usage"
    name = "blah"
    section2 = "Options"

    s = undent <<-EMPTY_LINES

      #{section1}:
        #{name} [options...] {file}
          
      #{section2}:
            
        -h --help     Show this screen.

        --version     Show version.

        --foo={value} Description of foo.

    EMPTY_LINES

    s.should eq <<-EXPECTED

Usage:
  blah [options...] {file}
    
Options:
      
  -h --help     Show this screen.

  --version     Show version.

  --foo={value} Description of foo.

    EXPECTED
  end

  it "does nothing on string which has no extra indent" do
    s = undent <<-USAGE
Usage:
  blah [options...] {file}
Options:
  -h --help     Show this screen.
  --version     Show version.
  --foo={value} Description of foo.
    USAGE

    s.should eq <<-EXPECTED
Usage:
  blah [options...] {file}
Options:
  -h --help     Show this screen.
  --version     Show version.
  --foo={value} Description of foo.
    EXPECTED

    section1 = "Usage"
    name = "blah"
    section2 = "Options"

    s = undent <<-USAGE
#{section1}:
  #{name} [options...] {file}
#{section2}:
  -h --help     Show this screen.
  --version     Show version.
  --foo={value} Description of foo.
    USAGE

    s.should eq <<-EXPECTED
Usage:
  blah [options...] {file}
Options:
  -h --help     Show this screen.
  --version     Show version.
  --foo={value} Description of foo.
    EXPECTED
  end

  # TODO:
  # Some tests should be added
  #   - Expand with only empty lines
  #   - Expand with neither StringLiteral nor StringInterpolation
end
