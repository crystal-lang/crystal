require "spec"
require "yaml"

private class YAMLPerson
  YAML.mapping({
    name: String,
    age:  {type: Int32, nilable: true},
  })

  def_equals name, age

  def initialize(@name : String)
  end
end

private class StrictYAMLPerson
  YAML.mapping({
    name: {type: String},
    age:  {type: Int32, nilable: true},
  }, true)
end

private class YAMLWithBool
  YAML.mapping value: Bool
end

private class YAMLWithTime
  YAML.mapping({
    value: {type: Time, converter: Time::Format.new("%F %T")},
  })
end

private class YAMLWithKey
  YAML.mapping({
    key:   String,
    value: Int32,
    pull:  Int32,
  })
end

private class YAMLWithDefaults
  YAML.mapping({
    a: {type: Int32, default: 11},
    b: {type: String, default: "Haha"},
    c: {type: Bool, default: true},
    d: {type: Bool, default: false},
    e: {type: Bool, nilable: true, default: false},
    f: {type: Int32, nilable: true, default: 1},
    g: {type: Int32, nilable: true, default: nil},
    h: {type: Array(Int32), default: [1, 2, 3]},
    i: String?,
  })
end

private class YAMLWithAny
  YAML.mapping({
    obj: YAML::Any,
  })

  def initialize(@obj)
  end
end

private class YAMLWithSmallIntegers
  YAML.mapping({
    foo: Int16,
    bar: Int8,
  })
end

private class YAMLWithNilableTime
  YAML.mapping({
    value: {type: Time, nilable: true, converter: Time::Format.new("%F")},
  })

  def initialize
  end
end

private class YAMLWithTimeEpoch
  YAML.mapping({
    value: {type: Time, converter: Time::EpochConverter},
  })
end

private class YAMLWithTimeEpochMillis
  YAML.mapping({
    value: {type: Time, converter: Time::EpochMillisConverter},
  })
end

private class YAMLWithPresence
  YAML.mapping({
    first_name: {type: String?, presence: true, nilable: true},
    last_name:  {type: String?, presence: true, nilable: true},
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
    ex = expect_raises YAML::ParseException, "Unknown yaml attribute: foo" do
      StrictYAMLPerson.from_yaml <<-YAML
        ---
        name: John
        foo: [1, 2, 3]
        age: 30
        YAML
    end
    ex.location.should eq({3, 1})
  end

  it "does to_yaml" do
    person = YAMLPerson.from_yaml("---\nname: John\nage: 30\n")
    person2 = YAMLPerson.from_yaml(person.to_yaml)
    person2.should eq(person)
  end

  it "doesn't emit null when doing to_yaml" do
    person = YAMLPerson.from_yaml("---\nname: John\n")
    (person.to_yaml =~ /age/).should be_falsey
  end

  it "raises if non-nilable attribute is nil" do
    ex = expect_raises YAML::ParseException, "Missing yaml attribute: name" do
      YAMLPerson.from_yaml <<-YAML
        ---
        age: 30
        YAML
    end
    ex.location.should eq({2, 1})
  end

  it "doesn't raises on false value when not-nil" do
    yaml = YAMLWithBool.from_yaml("---\nvalue: false\n")
    yaml.value.should be_false
  end

  it "parses yaml with Time::Format converter" do
    yaml = YAMLWithTime.from_yaml("---\nvalue: 2014-10-31 23:37:16\n")
    yaml.value.should be_a(Time)
    yaml.value.to_s.should eq("2014-10-31 23:37:16")
    yaml.value.should eq(Time.new(2014, 10, 31, 23, 37, 16))
    yaml.to_yaml.should eq("---\nvalue: 2014-10-31 23:37:16\n")
  end

  it "parses YAML with mapping key named 'key'" do
    yaml = YAMLWithKey.from_yaml("---\nkey: foo\nvalue: 1\npull: 2")
    yaml.key.should eq("foo")
    yaml.value.should eq(1)
    yaml.pull.should eq(2)
  end

  it "allows small types of integer" do
    yaml = YAMLWithSmallIntegers.from_yaml(%({"foo": 21, "bar": 7}))

    yaml.foo.should eq(21)
    typeof(yaml.foo).should eq(Int16)

    yaml.bar.should eq(7)
    typeof(yaml.bar).should eq(Int8)
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

      json = YAMLWithDefaults.from_yaml(%({}))
      json.i.should be_nil

      json = YAMLWithDefaults.from_yaml(%({"i":"bla"}))
      json.i.should eq("bla")
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

    yaml = YAMLWithAny.from_yaml({:obj => %w(foo bar)}.to_yaml)
    yaml.obj[1].as_s.should eq("bar")

    yaml = YAMLWithAny.from_yaml({:obj => {:foo => :bar}}.to_yaml)
    yaml.obj["foo"].as_s.should eq("bar")
  end

  it "outputs with converter when nilable" do
    yaml = YAMLWithNilableTime.new
    yaml.to_yaml.should eq("--- {}\n")
  end

  it "uses Time::EpochConverter" do
    string = %({"value":1459859781})
    yaml = YAMLWithTimeEpoch.from_yaml(string)
    yaml.value.should be_a(Time)
    yaml.value.should eq(Time.epoch(1459859781))
    yaml.to_yaml.should eq("---\nvalue: 1459859781\n")
  end

  it "uses Time::EpochMillisConverter" do
    string = %({"value":1459860483856})
    yaml = YAMLWithTimeEpochMillis.from_yaml(string)
    yaml.value.should be_a(Time)
    yaml.value.should eq(Time.epoch_ms(1459860483856))
    yaml.to_yaml.should eq("---\nvalue: 1459860483856\n")
  end

  describe "parses YAML with presence markers" do
    it "parses person with absent attributes" do
      yaml = YAMLWithPresence.from_yaml("---\nfirst_name:\n")
      yaml.first_name.should be_nil
      yaml.first_name_present?.should be_true
      yaml.last_name.should be_nil
      yaml.last_name_present?.should be_false
    end
  end
end
