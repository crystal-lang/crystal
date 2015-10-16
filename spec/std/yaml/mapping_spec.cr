require "spec"
require "yaml"

class YAMLPerson
  yaml_mapping({
    name: String,
    age:  {type: Int32, nilable: true},
  })

  def_equals name, age

  def initialize(@name : String)
  end
end

class StrictYAMLPerson
  yaml_mapping({
    name: {type: String},
    age:  {type: Int32, nilable: true},
  }, true)
end

class YAMLWithBool
  yaml_mapping({
    value: {type: Bool},
  })
end

class YAMLWithTime
  yaml_mapping({
    value: {type: Time, converter: Time::Format.new("%F %T")},
  })
end

class YAMLWithKey
  yaml_mapping({
    key:   String,
    value: Int32,
    pull: Int32,
  })
end

describe "YAML mapping" do
  it "parses person" do
    person = YAMLPerson.from_yaml("---\nname: John\nage: 30\n")
    person.should be_a(YAMLPerson)
    person.name.should eq("John")
    person.age.should eq(30)
  end

  it "parses person without age" do
    person = YAMLPerson.from_yaml("---\nname: John\n")
    person.should be_a(YAMLPerson)
    person.name.should eq("John")
    person.name.size.should eq(4) # This verifies that name is not nilable
    person.age.should be_nil
  end

  it "parses person with blank age" do
    person = YAMLPerson.from_yaml("---\nname: John\nage:\n")
    person.should be_a(YAMLPerson)
    person.name.should eq("John")
    person.name.size.should eq(4) # This verifies that name is not nilable
    person.age.should be_nil
  end

  it "parses array of people" do
    people = Array(YAMLPerson).from_yaml("---\n- name: John\n- name: Doe\n")
    people.size.should eq(2)
    people[0].name.should eq("John")
    people[1].name.should eq("Doe")
  end

  it "parses person with unknown attributes" do
    person = YAMLPerson.from_yaml("---\nname: John\nunknown: [1, 2, 3]\nage: 30\n")
    person.should be_a(YAMLPerson)
    person.name.should eq("John")
    person.age.should eq(30)
  end

  it "parses strict person with unknown attributes" do
    expect_raises YAML::ParseException, "unknown yaml attribute: foo" do
      StrictYAMLPerson.from_yaml("---\nname: John\nfoo: [1, 2, 3]\nage: 30\n")
    end
  end

  it "raises if non-nilable attribute is nil" do
    expect_raises YAML::ParseException, "missing yaml attribute: name" do
      YAMLPerson.from_yaml("---\nage: 30\n")
    end
  end

  it "doesn't raises on false value when not-nil" do
    yaml = YAMLWithBool.from_yaml("---\nvalue: false\n")
    yaml.value.should be_false
  end

  it "parses yaml with Time::Format converter" do
    yaml = YAMLWithTime.from_yaml("---\nvalue: 2014-10-31 23:37:16\n")
    yaml.value.should eq(Time.new(2014, 10, 31, 23, 37, 16))
  end

  it "parses YAML with mapping key named 'key'" do
    yaml = YAMLWithKey.from_yaml("---\nkey: foo\nvalue: 1\npull: 2")
    yaml.key.should eq("foo")
    yaml.value.should eq(1)
    yaml.pull.should eq(2)
  end
end
