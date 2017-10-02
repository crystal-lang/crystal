require "spec"
require "yaml"

describe "String.to_yaml" do
  values = {
    "", "NULL", "Null", "null", "~",
    "true", "True", "TRUE", "on", "On", "ON", "y", "Y", "yes", "Yes", "YES",
    "false", "False", "FALSE", "off", "Off", "OFF", "n", "N", "no", "No", "NO",
    ".inf", ".Inf", ".INF",
    "-.inf", "-.Inf", "-.INF",
    ".nan", ".NaN", ".NAN",
    "1", "1.0", "-1", "0",
  }

  it "should quote non-string scalars" do
    values.each do |value|
      [value].to_yaml.should eq "---\n- \"#{value}\"\n"
    end
  end
end

{% for type in %w(Float32 Float64) %}
  describe "{{type.id}}.to_yaml" do
    it "should convert a {{type.id}}::INFINITY to the correct value" do
      [{{type.id}}::INFINITY].to_yaml.should eq "---\n- .inf\n"
    end

    it "should convert a negative {{type.id}}::INFINITY to the correct value" do
      ([-{{type.id}}::INFINITY]).to_yaml.should eq "---\n- -.inf\n"
    end

    it "should convert a {{type.id}}::NAN to the correct value" do
      [{{type.id}}::NAN].to_yaml.should eq "---\n- .nan\n"
    end
  end
{% end %}
