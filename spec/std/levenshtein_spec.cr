require "spec"
require "levenshtein"

describe "levenshtein" do
  assert { expect(levenshtein("algorithm", "altruistic")).to eq(6) }
  assert { expect(levenshtein("1638452297", "444488444")).to eq(9) }
  assert { expect(levenshtein("", "")).to eq(0) }
  assert { expect(levenshtein("", "a")).to eq(1) }
  assert { expect(levenshtein("aaapppp", "")).to eq(7) }
  assert { expect(levenshtein("frog", "fog")).to eq(1) }
  assert { expect(levenshtein("fly", "ant")).to eq(3) }
  assert { expect(levenshtein("elephant", "hippo")).to eq(7) }
  assert { expect(levenshtein("hippo", "elephant")).to eq(7) }
  assert { expect(levenshtein("hippo", "zzzzzzzz")).to eq(8) }
  assert { expect(levenshtein("hello", "hallo")).to eq(1) }
  assert { expect(levenshtein("こんにちは", "こんちは")).to eq(1) }
end
