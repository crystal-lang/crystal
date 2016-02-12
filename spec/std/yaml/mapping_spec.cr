require "spec"
require "yaml"

class YAMLPerson
  YAML.mapping({
    name: String,
    age:  {type: Int32, nilable: true},
  })

  def_equals name, age

  def initialize(@name : String)
  end
end

class StrictYAMLPerson
  YAML.mapping({
    name: {type: String},
    age:  {type: Int32, nilable: true},
  }, true)
end

class YAMLWithBool
  YAML.mapping({
    value: {type: Bool},
  })
end

class YAMLWithTime
  YAML.mapping({
    value: {type: Time, converter: Time::Format.new("%F %T")},
  })
end

class YAMLWithKey
  YAML.mapping({
    key:   String,
    value: Int32,
    pull:  Int32,
  })
end

class YAMLWithDefaults
  YAML.mapping({
    a: {type: Int32, default: 11},
    b: {type: String, default: "Haha"},
    c: {type: Bool, default: true},
    d: {type: Bool, default: false},
    e: {type: Bool, nilable: true, default: false},
    f: {type: Int32, nilable: true, default: 1},
    g: {type: Int32, nilable: true, default: nil},
    h: {type: Array(Int32), default: [1, 2, 3]},
  })
end

class YAMLWithAny
  YAML.mapping({
    obj: YAML::Any,
  })

  def initialize(@obj)
  end
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

  describe "parses YAML with defaults" do
    it "mixed" do
      json = YAMLWithDefaults.from_yaml(%({"a":1,"b":"bla"}))
      json.a.should eq 1
      json.b.should eq "bla"

      json = YAMLWithDefaults.from_yaml(%({"a":1}))
      json.a.should eq 1
      json.b.should eq "Haha"

      json = YAMLWithDefaults.from_yaml(%({"b":"bla"}))
      json.a.should eq 11
      json.b.should eq "bla"

      json = YAMLWithDefaults.from_yaml(%({}))
      json.a.should eq 11
      json.b.should eq "Haha"

      # There's no "null" in YAML? Maybe we should support this eventually
      # json = YAMLWithDefaults.from_yaml(%({"a":null,"b":null}))
      # json.a.should eq 11
      # json.b.should eq "Haha"
    end

    it "bool" do
      json = YAMLWithDefaults.from_yaml(%({}))
      json.c.should eq true
      typeof(json.c).should eq Bool
      json.d.should eq false
      typeof(json.d).should eq Bool

      json = YAMLWithDefaults.from_yaml(%({"c":false}))
      json.c.should eq false
      json = YAMLWithDefaults.from_yaml(%({"c":true}))
      json.c.should eq true

      json = YAMLWithDefaults.from_yaml(%({"d":false}))
      json.d.should eq false
      json = YAMLWithDefaults.from_yaml(%({"d":true}))
      json.d.should eq true
    end

    it "with nilable" do
      json = YAMLWithDefaults.from_yaml(%({}))

      json.e.should eq false
      typeof(json.e).should eq(Bool | Nil)

      json.f.should eq 1
      typeof(json.f).should eq(Int32 | Nil)

      json.g.should eq nil
      typeof(json.g).should eq(Int32 | Nil)

      json = YAMLWithDefaults.from_yaml(%({"e":false}))
      json.e.should eq false
      json = YAMLWithDefaults.from_yaml(%({"e":true}))
      json.e.should eq true
    end

    it "create new array every time" do
      json = YAMLWithDefaults.from_yaml(%({}))
      json.h.should eq [1, 2, 3]
      json.h << 4
      json.h.should eq [1, 2, 3, 4]

      json = YAMLWithDefaults.from_yaml(%({}))
      json.h.should eq [1, 2, 3]
    end
  end

  it "parses YAML with any" do
    yaml = YAMLWithAny.from_yaml("obj: hello")
    yaml.obj.as_s.should eq("hello")

    yaml = YAMLWithAny.from_yaml({obj: %w(foo bar)}.to_yaml)
    yaml.obj[1].as_s.should eq("bar")

    yaml = YAMLWithAny.from_yaml({obj: {foo: :bar}}.to_yaml)
    yaml.obj["foo"].as_s.should eq("bar")
  end
end
