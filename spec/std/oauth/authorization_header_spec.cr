require "spec"
require "oauth"

describe OAuth::AuthorizationHeader do
  it "builds" do
    params = OAuth::AuthorizationHeader.new
    params.add "foo", "value1"
    params.add "bar", "a+b"
    params.add "baz", "=/="
    params.to_s.should eq(%(OAuth foo="value1", bar="a%2Bb", baz="%3D%2F%3D"))
  end
end
