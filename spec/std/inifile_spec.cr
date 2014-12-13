require "spec"
require "inifile"

describe "IniFile" do
  describe "parse from string" do
    it "parses key = value" do
      IniFile.load("key = value").should eq({"" => {"key" => "value"}})
    end

    it "ignores whitespaces" do
      IniFile.load("   key   =   value  ").should eq({"" => {"key" => "value"}})
    end

    it "parses sections" do
      IniFile.load("[section]\na = 1").should eq({"section" => {"a" => "1"}})
    end

    it "empty section" do
      IniFile.load("[section]").should eq({"section" => {} of String => String})
    end

    it "parse file" do
      IniFile.load(File.read "#{__DIR__}/data/test_file.ini").should eq({
        "general" => {
          "log_level" => "DEBUG"
        },
        "section1" => {
          "foo" => "1"
          "bar" => "2"
        },
        "section2" => {
          "x.y.z" => "coco lala"
        }
      })
    end
  end
end
