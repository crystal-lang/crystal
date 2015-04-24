require "spec"
require "inifile"

describe "IniFile" do
  describe "parse from string" do
    it "parses key = value" do
      expect(IniFile.load("key = value")).to eq({"" => {"key" => "value"}})
    end

    it "ignores whitespaces" do
      expect(IniFile.load("   key   =   value  ")).to eq({"" => {"key" => "value"}})
    end

    it "parses sections" do
      expect(IniFile.load("[section]\na = 1")).to eq({"section" => {"a" => "1"}})
    end

    it "empty section" do
      expect(IniFile.load("[section]")).to eq({"section" => {} of String => String})
    end

    it "parse file" do
      expect(IniFile.load(File.read "#{__DIR__}/data/test_file.ini")).to eq({
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
