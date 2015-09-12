require "spec"
require "levenshtein"

describe "levenshtein" do
  assert { Levenshtein.distance("algorithm", "altruistic").should eq(6) }
  assert { Levenshtein.distance("1638452297", "444488444").should eq(9) }
  assert { Levenshtein.distance("", "").should eq(0) }
  assert { Levenshtein.distance("", "a").should eq(1) }
  assert { Levenshtein.distance("aaapppp", "").should eq(7) }
  assert { Levenshtein.distance("frog", "fog").should eq(1) }
  assert { Levenshtein.distance("fly", "ant").should eq(3) }
  assert { Levenshtein.distance("elephant", "hippo").should eq(7) }
  assert { Levenshtein.distance("hippo", "elephant").should eq(7) }
  assert { Levenshtein.distance("hippo", "zzzzzzzz").should eq(8) }
  assert { Levenshtein.distance("hello", "hallo").should eq(1) }
  assert { Levenshtein.distance("こんにちは", "こんちは").should eq(1) }

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
