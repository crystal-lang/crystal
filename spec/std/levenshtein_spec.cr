require "spec"
require "levenshtein"

describe "levenshtein" do
  assert { levenshtein("algorithm", "altruistic").should eq(6) }
  assert { levenshtein("1638452297", "444488444").should eq(9) }
  assert { levenshtein("", "").should eq(0) }
  assert { levenshtein("", "a").should eq(1) }
  assert { levenshtein("aaapppp", "").should eq(7) }
  assert { levenshtein("frog", "fog").should eq(1) }
  assert { levenshtein("fly", "ant").should eq(3) }
  assert { levenshtein("elephant", "hippo").should eq(7) }
  assert { levenshtein("hippo", "elephant").should eq(7) }
  assert { levenshtein("hippo", "zzzzzzzz").should eq(8) }
  assert { levenshtein("hello", "hallo").should eq(1) }
end
