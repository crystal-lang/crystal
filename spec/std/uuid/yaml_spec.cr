require "spec"
require "uuid/yaml"

struct TestUuidYaml
  include YAML::Serializable
  getter uuid : UUID
end

describe "UUID" do
  describe "serializes" do
    it "#to_yaml" do
      UUID.new("50a11da6-377b-4bdf-b9f0-076f9db61c93").to_yaml.should eq "--- 50a11da6-377b-4bdf-b9f0-076f9db61c93\n"
    end

    it "#from_yaml" do
      obj = TestUuidYaml.from_yaml("uuid: 50a11da6-377b-4bdf-b9f0-076f9db61c93")
      obj.uuid.should eq UUID.new("50a11da6-377b-4bdf-b9f0-076f9db61c93")
    end

    # it "from_json_object_key?" do
    #   UUID.from_json_object_key?("50a11da6-377b-4bdf-b9f0-076f9db61c93").should eq UUID.new("50a11da6-377b-4bdf-b9f0-076f9db61c93")
    # end
  end
end
