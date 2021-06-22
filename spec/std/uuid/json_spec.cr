require "spec"
require "uuid/json"

describe "UUID" do
  describe "serializes" do
    it "#to_json" do
      UUID.new("50a11da6-377b-4bdf-b9f0-076f9db61c93").to_json.should eq "\"50a11da6-377b-4bdf-b9f0-076f9db61c93\""
    end

    it "from_json_object_key?" do
      UUID.from_json_object_key?("50a11da6-377b-4bdf-b9f0-076f9db61c93").should eq UUID.new("50a11da6-377b-4bdf-b9f0-076f9db61c93")
    end
  end
end
