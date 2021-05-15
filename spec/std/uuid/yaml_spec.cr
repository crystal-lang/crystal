require "spec"
require "uuid/yaml"

struct TestUuidYaml
  include YAML::Serializable
  getter uuid : UUID

  def initialize(@uuid); end
end

describe "UUID" do
  describe "serializes" do
    it "#to_yaml" do
      obj = TestUuidYaml.new(UUID.new("50a11da6-377b-4bdf-b9f0-076f9db61c93"))
      obj.to_yaml.should match /uuid: 50a11da6-377b-4bdf-b9f0-076f9db61c93/
    end

    it "#from_yaml" do
      obj = TestUuidYaml.from_yaml("uuid: 50a11da6-377b-4bdf-b9f0-076f9db61c93")
      obj.uuid.should eq UUID.new("50a11da6-377b-4bdf-b9f0-076f9db61c93")
    end
  end
end
