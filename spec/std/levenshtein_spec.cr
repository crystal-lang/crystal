require "spec"
require "levenshtein"

describe "levenshtein" do
  it { Levenshtein.distance("algorithm", "altruistic").should eq(6) }
  it { Levenshtein.distance("1638452297", "444488444").should eq(9) }
  it { Levenshtein.distance("", "").should eq(0) }
  it { Levenshtein.distance("", "a").should eq(1) }
  it { Levenshtein.distance("aaapppp", "").should eq(7) }
  it { Levenshtein.distance("frog", "fog").should eq(1) }
  it { Levenshtein.distance("fly", "ant").should eq(3) }
  it { Levenshtein.distance("elephant", "hippo").should eq(7) }
  it { Levenshtein.distance("hippo", "elephant").should eq(7) }
  it { Levenshtein.distance("hippo", "zzzzzzzz").should eq(8) }
  it { Levenshtein.distance("hello", "hallo").should eq(1) }
  it { Levenshtein.distance("こんにちは", "こんちは").should eq(1) }
  it { Levenshtein.distance("한자", "漢字").should eq(2) }
  it { Levenshtein.distance("abc", "cba").should eq(2) }
  it { Levenshtein.distance("かんじ", "じんか").should eq(2) }
  it { Levenshtein.distance("", "かんじ").should eq(3) }

  it "finds with finder" do
    finder = Levenshtein::Finder.new "hallo"
    finder.test "hay"
    finder.test "hall"
    finder.test "hallo world"
    finder.best_match.should eq("hall")
  end

  it "finds with finder and other values" do
    finder = Levenshtein::Finder.new "hallo"
    finder.test "hay", "HAY"
    finder.test "hall", "HALL"
    finder.test "hallo world", "HALLO WORLD"
    finder.best_match.should eq("HALL")
  end
end
