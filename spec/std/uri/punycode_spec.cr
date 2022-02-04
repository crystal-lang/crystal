require "spec"
require "uri/punycode"

describe URI::Punycode do
  [
    {"3年B組金八先生", "3B-ww4c5e180e575a65lsy2b"},
    {"安室奈美恵-with-SUPER-MONKEYS", "-with-SUPER-MONKEYS-pc58ag80a8qai00g7n9n"},
    {"Hello-Another-Way-それぞれの場所", "Hello-Another-Way--fc4qua05auwb3674vfr0b"},
    {"ひとつ屋根の下2", "2-u9tlzr9756bt3uc0v"},
    {"MajiでKoiする5秒前", "MajiKoi5-783gue6qz075azm5e"},
    {"パフィーdeルンバ", "de-jg4avhby1noc0d"},
    {"そのスピードで", "d9juau41awczczp"},
    {"Hello-Another-Way-それぞれ", "Hello-Another-Way--fc4qua97gba"},
  ].each do |example|
    dec, enc = example

    it "encodes #{dec} to #{enc}" do
      URI::Punycode.encode(dec).should eq enc
    end

    it "decodes #{enc} to #{dec}" do
      URI::Punycode.decode(enc).should eq dec
    end
  end

  it "translate to ascii only host name" do
    URI::Punycode.to_ascii("test.テスト.テスト").should eq "test.xn--zckzah.xn--zckzah"
  end
end
