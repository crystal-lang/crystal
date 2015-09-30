require "spec"

describe Class do
  it "does ===" do
    (Int32 === 1).should be_true
    (Int32 === 1.5).should be_false
    (Array === [1]).should be_true
    (Array(Int32) === [1]).should be_true
    (Array(Int32) === ['a']).should be_false
  end
end
