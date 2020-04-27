require "../../spec_helper"

describe "Semantic: require" do
  it "raises crystal exception if can't find require (#7385)" do
    node = parse(%(require "file_that_doesnt_exist"))
    expect_raises ::Crystal::Exception do
      semantic(node)
    end
  end
end
