require "http/params"
require "spec"

describe "HTTP::Params" do
  it "is alias for URI::Params" do
    HTTP::Params.should eq URI::Params
  end
end
