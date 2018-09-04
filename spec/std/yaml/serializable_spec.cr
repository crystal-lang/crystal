require "spec"
require "yaml"
require "../../support/finalize"

record YAMLAttrPoint, x : Int32, y : Int32 do
  include YAML::Serializable
end

class YAMLAttrEmptyClass
  include YAML::Serializable

  def initialize; end
end

class YAMLAttrEmptyClassWithUnmapped
  include YAML::Serializable
  include YAML::Serializable::Unmapped

  def initialize; end
end

class YAMLAttrPerson
  include YAML::Serializable

  property name : String
  property age : Int32?

  def_equals name, age

  def initialize(@name : String)
  end
end

struct YAMLAttrPersonWithThreeFieldInInitialize
  include YAML::Serializable

  property name : String
  property bla : Int32
  property age : Int32

  def initialize(@name, @bla, @age)
  end
end

class StrictYAMLAttrPerson
  include YAML::Serializable
  include YAML::Serializable::Strict

  property name : String
  property age : Int32?
end

class YAMLAttrPersonExtraFields
  include YAML::Serializable
  include YAML::Serializable::Unmapped

  property name : String
  property age : Int32?
end

class YAMLAttrPersonEmittingNull
  include YAML::Serializable

  property name : String

  @[YAML::Field(emit_null: true)]
  property age : Int32?
end

@[YAML::Serializable::Options(emit_nulls: true)]
class YAMLAttrPersonEmittingNullsByOptions
  include YAML::Serializable

  property name : String
  property age : Int32?
  property value1 : Int32?

  @[YAML::Field(emit_null: false)]
  property value2 : Int32?
end

class YAMLAttrWithBool
  include YAML::Serializable

  property value : Bool
end

class YAMLAttrWithTime
  include YAML::Serializable

  @[YAML::Field(converter: Time::Format.new("%F %T"))]
  property value : Time
end

class YAMLAttrWithNilableTime
  include YAML::Serializable

  @[YAML::Field(converter: Time::Format.new("%F"))]
  property value : Time?

  def initialize
  end
end

class YAMLAttrWithNilableTimeEmittingNull
  include YAML::Serializable

  @[YAML::Field(converter: Time::Format.new("%F"), emit_null: true)]
  property value : Time?

  def initialize
  end
end

class YAMLAttrWithPropertiesKey
  include YAML::Serializable

  property properties : Hash(String, String)
end

class YAMLAttrWithSimpleMapping
  include YAML::Serializable

  property name : String
  property age : Int32
end

class YAMLAttrWithKeywordsMapping
  include YAML::Serializable

  property end : Int32
  property abstract : Int32
end

class YAMLAttrWithAny
  include YAML::Serializable
  property obj : YAML::Any
end

class YAMLAttrWithProblematicKeys
  include YAML::Serializable

  property key : Int32
  property pull : Int32
end

class YAMLAttrRecursive
  include YAML::Serializable

  property name : String
  property other : YAMLAttrRecursive
end

class YAMLAttrRecursiveNilable
  include YAML::Serializable
  property name : String
  property other : YAMLAttrRecursiveNilable?
end

class YAMLAttrRecursiveArray
  include YAML::Serializable
  property name : String
  property other : Array(YAMLAttrRecursiveArray)
end

class YAMLAttrRecursiveHash
  include YAML::Serializable
  property name : String
  property other : Hash(String, YAMLAttrRecursiveHash)
end

class YAMLAttrWithDefaults
  include YAML::Serializable

  property a = 11
  property b = "Haha"
  property c = true
  property d = false
  property e : Bool? = false
  property f : Int32? = 1
  property g : Int32?
  property h = [1, 2, 3]
end

class YAMLAttrWithSmallIntegers
  include YAML::Serializable

  property foo : Int16
  property bar : Int8
end

class YAMLAttrWithTimeEpoch
  include YAML::Serializable

  @[YAML::Field(converter: Time::EpochConverter)]
  property value : Time
end

class YAMLAttrWithTimeEpochMillis
  include YAML::Serializable

  @[YAML::Field(converter: Time::EpochMillisConverter)]
  property value : Time
end

class YAMLAttrWithNilableUnion
  include YAML::Serializable

  property value : Int32?
end

class YAMLAttrWithNilableUnion2
  include YAML::Serializable

  property value : Int32 | Nil
end

class YAMLAttrWithPresence
  include YAML::Serializable

  @[YAML::Field(presence: true)]
  property first_name : String?

  @[YAML::Field(presence: true)]
  property last_name : String?

  @[YAML::Field(ignore: true)]
  getter? first_name_present : Bool

  @[YAML::Field(ignore: true)]
  getter? last_name_present : Bool
end

class YAMLAttrWithQueryAttributes
  include YAML::Serializable

  property? foo : Bool

  @[YAML::Field(key: "is_bar", presence: true)]
  property? bar : Bool = false

  @[YAML::Field(ignore: true)]
  getter? bar_present : Bool
end

private class YAMLAttrWithFinalize
  include YAML::Serializable
  property value : YAML::Any

  @[YAML::Field(ignore: true)]
  property key : Symbol?

  def finalize
    if key = self.key
      State.inc(key)
    end
  end
end

module YAMLAttrModule
  property moo : Int32 = 10
end

class YAMLAttrModuleTest
  include YAMLAttrModule
  include YAML::Serializable

  @[YAML::Field(key: "phoo")]
  property foo = 15

  def initialize; end

  def to_tuple
    {@moo, @foo}
  end
end

class YAMLAttrModuleTest2 < YAMLAttrModuleTest
  property bar : Int32

  def initialize(@bar : Int32); end

  def to_tuple
    {@moo, @foo, @bar}
  end
end

describe "YAML::Serializable" do
  it "works with record" do
    YAMLAttrPoint.new(1, 2).to_yaml.should eq "---\nx: 1\ny: 2\n"
    YAMLAttrPoint.from_yaml("---\nx: 1\ny: 2\n").should eq YAMLAttrPoint.new(1, 2)
  end

  it "empty class" do
    e = YAMLAttrEmptyClass.new
    e.to_yaml.should eq "--- {}\n"
    YAMLAttrEmptyClass.from_yaml("---\n")
  end

  it "empty class with unmapped" do
    YAMLAttrEmptyClassWithUnmapped.from_yaml("---\nname: John\nage: 30\n").yaml_unmapped.should eq({"name" => "John", "age" => 30})
  end

  it "parses person" do
    person = YAMLAttrPerson.from_yaml("---\nname: John\nage: 30\n")
    person.should be_a(YAMLAttrPerson)
    person.name.should eq("John")
    person.age.should eq(30)
  end

  it "parses person without age" do
    person = YAMLAttrPerson.from_yaml("---\nname: John\n")
    person.should be_a(YAMLAttrPerson)
    person.name.should eq("John")
    person.name.size.should eq(4) # This verifies that name is not nilable
    person.age.should be_nil
  end

  it "parses person with blank age" do
    person = YAMLAttrPerson.from_yaml("---\nname: John\nage:\n")
    person.should be_a(YAMLAttrPerson)
    person.name.should eq("John")
    person.name.size.should eq(4) # This verifies that name is not nilable
    person.age.should be_nil
  end

  it "parses array of people" do
    people = Array(YAMLAttrPerson).from_yaml("---\n- name: John\n- name: Doe\n")
    people.size.should eq(2)
    people[0].name.should eq("John")
    people[1].name.should eq("Doe")
  end

  it "parses array of people with merge" do
    yaml = <<-YAML
      - &1
        name: foo
        age: 1
      -
        <<: *1
        age: 2
      YAML

    people = Array(YAMLAttrPerson).from_yaml(yaml)
    people[1].name.should eq("foo")
    people[1].age.should eq(2)
  end

  it "parses array of people with merge, doesn't hang on infinite recursion" do
    yaml = <<-YAML
      - &1
        name: foo
        <<: *1
        <<: [ *1, *1 ]
        age: 1
      YAML

    people = Array(YAMLAttrPerson).from_yaml(yaml)
    people[0].name.should eq("foo")
    people[0].age.should eq(1)
  end

  it "works with class with three fields" do
    person1 = YAMLAttrPersonWithThreeFieldInInitialize.from_yaml("---\nname: John\nbla: 1\nage: 30\n")
    person2 = YAMLAttrPersonWithThreeFieldInInitialize.new("John", 1, 30)
    person1.should eq person2
  end

  it "parses person with unknown attributes" do
    person = YAMLAttrPerson.from_yaml("---\nname: John\nunknown: [1, 2, 3]\nage: 30\n")
    person.should be_a(YAMLAttrPerson)
    person.name.should eq("John")
    person.age.should eq(30)
  end

  it "parses strict person with unknown attributes" do
    ex = expect_raises YAML::ParseException, "Unknown yaml attribute: foo" do
      StrictYAMLAttrPerson.from_yaml <<-YAML
        ---
        name: John
        foo: [1, 2, 3]
        age: 30
        YAML
    end
    ex.location.should eq({3, 1})
  end

  it "does to_yaml" do
    person = YAMLAttrPerson.from_yaml("---\nname: John\nage: 30\n")
    person2 = YAMLAttrPerson.from_yaml(person.to_yaml)
    person2.should eq(person)
  end

  it "doesn't emit null when doing to_yaml" do
    person = YAMLAttrPerson.from_yaml("---\nname: John\n")
    (person.to_yaml =~ /age/).should be_falsey
  end

  it "raises if non-nilable attribute is nil" do
    error_message = "Missing YAML attribute: name at line 2, column 1"
    ex = expect_raises YAML::ParseException, error_message do
      YAMLAttrPerson.from_yaml <<-YAML
        ---
        age: 30
        YAML
    end
    ex.location.should eq({2, 1})
  end

  it "doesn't raises on false value when not-nil" do
    yaml = YAMLAttrWithBool.from_yaml("---\nvalue: false\n")
    yaml.value.should be_false
  end

  it "should parse extra fields (YAMLAttrPersonExtraFields with on_unknown_yaml_attribute)" do
    person = YAMLAttrPersonExtraFields.from_yaml(<<-YAML)
        ---
        name: John
        x: 1
        y: "1-2"
        age: 30
        z:
          - 1
          - 2
          - 3
        YAML
    person.name.should eq("John")
    person.age.should eq(30)
    person.yaml_unmapped.should eq({"x" => 1_i64, "y" => "1-2", "z" => [1_i64, 2_i64, 3_i64]})
  end

  it "should to store extra fields (YAMLAttrPersonExtraFields with on_to_yaml)" do
    person = YAMLAttrPersonExtraFields.from_yaml(<<-YAML)
        ---
        name: John
        x: 1
        y: "1-2"
        age: 30
        z:
          - 1
          - 2
          - 3
        YAML
    person.name = "John1"
    person.yaml_unmapped.delete("y")
    person.yaml_unmapped["q"] = YAML::Any.new("w")
    person.to_yaml.should eq "---\nname: John1\nage: 30\nx: 1\nz:\n- 1\n- 2\n- 3\nq: w\n"
  end

  it "raises if not an object" do
    error_message = "Expected mapping, not YAML::Nodes::Scalar at line 1, column 1"
    ex = expect_raises YAML::ParseException, error_message do
      StrictYAMLAttrPerson.from_yaml <<-YAML
        "foo"
        YAML
    end
    ex.location.should eq({1, 1})
  end

  it "raises if data type does not match" do
    error_message = "Couldn't parse (Int32 | Nil) at line 3, column 10"
    ex = expect_raises YAML::ParseException, error_message do
      StrictYAMLAttrPerson.from_yaml <<-YAML
        {
          "name": "John",
          "age": "foo",
          "foo": "bar"
        }
        YAML
    end
    ex.location.should eq({3, 10})
  end

  it "emits null on request when doing to_yaml" do
    person = YAMLAttrPersonEmittingNull.from_yaml("---\nname: John\n")
    (person.to_yaml =~ /age/).should be_truthy
  end

  it "emit_nulls option" do
    person = YAMLAttrPersonEmittingNullsByOptions.from_yaml("---\nname: John\n")
    person.to_yaml.should eq "---\nname: John\nage: \nvalue1: \n"
  end

  it "parses yaml with Time::Format converter" do
    yaml = YAMLAttrWithTime.from_yaml("---\nvalue: 2014-10-31 23:37:16\n")
    yaml.value.should be_a(Time)
    yaml.value.to_s.should eq("2014-10-31 23:37:16 UTC")
    yaml.value.should eq(Time.utc(2014, 10, 31, 23, 37, 16))
    yaml.to_yaml.should eq("---\nvalue: 2014-10-31 23:37:16\n")
  end

  it "allows setting a nilable property to nil" do
    person = YAMLAttrPerson.new("John")
    person.age = 1
    person.age = nil
  end

  it "parses simple mapping" do
    person = YAMLAttrWithSimpleMapping.from_yaml("---\nname: John\nage: 30\n")
    person.should be_a(YAMLAttrWithSimpleMapping)
    person.name.should eq("John")
    person.age.should eq(30)
  end

  it "outputs with converter when nilable" do
    yaml = YAMLAttrWithNilableTime.new
    yaml.to_yaml.should eq("--- {}\n")
  end

  it "outputs with converter when nilable when emit_null is true" do
    yaml = YAMLAttrWithNilableTimeEmittingNull.new
    yaml.to_yaml.should eq("---\nvalue: \n")
  end

  it "outputs YAML with properties key" do
    input = {
      properties: {"foo" => "bar"},
    }.to_yaml
    yaml = YAMLAttrWithPropertiesKey.from_yaml(input)
    yaml.to_yaml.should eq(input)
  end

  it "parses yaml with keywords" do
    yaml = YAMLAttrWithKeywordsMapping.from_yaml(%({"end": 1, "abstract": 2}))
    yaml.end.should eq(1)
    yaml.abstract.should eq(2)
  end

  it "parses yaml with any" do
    yaml = YAMLAttrWithAny.from_yaml("obj: hello")
    yaml.obj.as_s.should eq("hello")

    yaml = YAMLAttrWithAny.from_yaml({:obj => ["foo", "bar"]}.to_yaml)
    yaml.obj[1].as_s.should eq("bar")

    yaml = YAMLAttrWithAny.from_yaml({:obj => {:foo => :bar}}.to_yaml)
    yaml.obj["foo"].as_s.should eq("bar")
  end

  it "parses yaml with problematic keys" do
    yaml = YAMLAttrWithProblematicKeys.from_yaml(%({"key": 1, "pull": 2}))
    yaml.key.should eq(1)
    yaml.pull.should eq(2)
  end

  it "allows small types of integer" do
    yaml = YAMLAttrWithSmallIntegers.from_yaml(%({"foo": 21, "bar": 7}))

    yaml.foo.should eq(21)
    typeof(yaml.foo).should eq(Int16)

    yaml.bar.should eq(7)
    typeof(yaml.bar).should eq(Int8)
  end

  it "parses recursive" do
    yaml = <<-YAML
      --- &1
      name: foo
      other: *1
      YAML

    rec = YAMLAttrRecursive.from_yaml(yaml)
    rec.name.should eq("foo")
    rec.other.should be(rec)
  end

  it "parses recursive nilable (1)" do
    yaml = <<-YAML
      --- &1
      name: foo
      other: *1
      YAML

    rec = YAMLAttrRecursiveNilable.from_yaml(yaml)
    rec.name.should eq("foo")
    rec.other.should be(rec)
  end

  it "parses recursive nilable (2)" do
    yaml = <<-YAML
      --- &1
      name: foo
      YAML

    rec = YAMLAttrRecursiveNilable.from_yaml(yaml)
    rec.name.should eq("foo")
    rec.other.should be_nil
  end

  it "parses recursive array" do
    yaml = <<-YAML
      ---
      name: foo
      other: &1
        - name: bar
          other: *1
      YAML

    rec = YAMLAttrRecursiveArray.from_yaml(yaml)
    rec.other[0].other.should be(rec.other)
  end

  it "parses recursive hash" do
    yaml = <<-YAML
      ---
      name: foo
      other: &1
        foo:
          name: bar
          other: *1
      YAML

    rec = YAMLAttrRecursiveHash.from_yaml(yaml)
    rec.other["foo"].other.should be(rec.other)
  end

  describe "parses yaml with defaults" do
    it "mixed" do
      yaml = YAMLAttrWithDefaults.from_yaml(%({"a":1,"b":"bla"}))
      yaml.a.should eq 1
      yaml.b.should eq "bla"

      yaml = YAMLAttrWithDefaults.from_yaml(%({"a":1}))
      yaml.a.should eq 1
      yaml.b.should eq "Haha"

      yaml = YAMLAttrWithDefaults.from_yaml(%({"b":"bla"}))
      yaml.a.should eq 11
      yaml.b.should eq "bla"

      yaml = YAMLAttrWithDefaults.from_yaml(%({}))
      yaml.a.should eq 11
      yaml.b.should eq "Haha"

      yaml = YAMLAttrWithDefaults.from_yaml(%({"a":null,"b":null}))
      yaml.a.should eq 11
      yaml.b.should eq "Haha"
    end

    it "bool" do
      yaml = YAMLAttrWithDefaults.from_yaml(%({}))
      yaml.c.should eq true
      typeof(yaml.c).should eq Bool
      yaml.d.should eq false
      typeof(yaml.d).should eq Bool

      yaml = YAMLAttrWithDefaults.from_yaml(%({"c":false}))
      yaml.c.should eq false
      yaml = YAMLAttrWithDefaults.from_yaml(%({"c":true}))
      yaml.c.should eq true

      yaml = YAMLAttrWithDefaults.from_yaml(%({"d":false}))
      yaml.d.should eq false
      yaml = YAMLAttrWithDefaults.from_yaml(%({"d":true}))
      yaml.d.should eq true
    end

    it "with nilable" do
      yaml = YAMLAttrWithDefaults.from_yaml(%({}))

      yaml.e.should eq false
      typeof(yaml.e).should eq(Bool | Nil)

      yaml.f.should eq 1
      typeof(yaml.f).should eq(Int32 | Nil)

      yaml.g.should eq nil
      typeof(yaml.g).should eq(Int32 | Nil)

      yaml = YAMLAttrWithDefaults.from_yaml(%({"e":false}))
      yaml.e.should eq false
      yaml = YAMLAttrWithDefaults.from_yaml(%({"e":true}))
      yaml.e.should eq true
    end

    it "create new array every time" do
      yaml = YAMLAttrWithDefaults.from_yaml(%({}))
      yaml.h.should eq [1, 2, 3]
      yaml.h << 4
      yaml.h.should eq [1, 2, 3, 4]

      yaml = YAMLAttrWithDefaults.from_yaml(%({}))
      yaml.h.should eq [1, 2, 3]
    end
  end

  it "uses Time::EpochConverter" do
    string = %({"value":1459859781})
    yaml = YAMLAttrWithTimeEpoch.from_yaml(string)
    yaml.value.should be_a(Time)
    yaml.value.should eq(Time.unix(1459859781))
    yaml.to_yaml.should eq("---\nvalue: 1459859781\n")
  end

  it "uses Time::EpochMillisConverter" do
    string = %({"value":1459860483856})
    yaml = YAMLAttrWithTimeEpochMillis.from_yaml(string)
    yaml.value.should be_a(Time)
    yaml.value.should eq(Time.unix_ms(1459860483856))
    yaml.to_yaml.should eq("---\nvalue: 1459860483856\n")
  end

  it "parses nilable union" do
    obj = YAMLAttrWithNilableUnion.from_yaml(%({"value": 1}))
    obj.value.should eq(1)
    obj.to_yaml.should eq("---\nvalue: 1\n")

    obj = YAMLAttrWithNilableUnion.from_yaml(%({"value": null}))
    obj.value.should be_nil
    obj.to_yaml.should eq("--- {}\n")

    obj = YAMLAttrWithNilableUnion.from_yaml(%({}))
    obj.value.should be_nil
    obj.to_yaml.should eq("--- {}\n")
  end

  it "parses nilable union2" do
    obj = YAMLAttrWithNilableUnion2.from_yaml(%({"value": 1}))
    obj.value.should eq(1)
    obj.to_yaml.should eq("---\nvalue: 1\n")

    obj = YAMLAttrWithNilableUnion2.from_yaml(%({"value": null}))
    obj.value.should be_nil
    obj.to_yaml.should eq("--- {}\n")

    obj = YAMLAttrWithNilableUnion2.from_yaml(%({}))
    obj.value.should be_nil
    obj.to_yaml.should eq("--- {}\n")
  end

  describe "parses YAML with presence markers" do
    it "parses person with absent attributes" do
      yaml = YAMLAttrWithPresence.from_yaml("---\nfirst_name:\n")
      yaml.first_name.should be_nil
      yaml.first_name_present?.should be_true
      yaml.last_name.should be_nil
      yaml.last_name_present?.should be_false
    end
  end

  describe "with query attributes" do
    it "defines query getter" do
      yaml = YAMLAttrWithQueryAttributes.from_yaml(%({"foo": true}))
      yaml.foo?.should be_true
      yaml.bar?.should be_false
    end

    it "defines query getter with class restriction" do
      {% begin %}
        {% methods = YAMLAttrWithQueryAttributes.methods %}
        {{ methods.find(&.name.==("foo?")).return_type }}.should eq(Bool)
        {{ methods.find(&.name.==("bar?")).return_type }}.should eq(Bool)
      {% end %}
    end

    it "defines non-query setter and presence methods" do
      yaml = YAMLAttrWithQueryAttributes.from_yaml(%({"foo": false}))
      yaml.bar_present?.should be_false
      yaml.bar = true
      yaml.bar?.should be_true
    end

    it "maps non-query attributes" do
      yaml = YAMLAttrWithQueryAttributes.from_yaml(%({"foo": false, "is_bar": false}))
      yaml.bar_present?.should be_true
      yaml.bar?.should be_false
      yaml.bar = true
      yaml.to_yaml.should eq("---\nfoo: false\nis_bar: true\n")
    end

    it "raises if non-nilable attribute is nil" do
      error_message = "Missing YAML attribute: foo at line 1, column 1"
      ex = expect_raises YAML::ParseException, error_message do
        YAMLAttrWithQueryAttributes.from_yaml(%({"is_bar": true}))
      end
      ex.location.should eq({1, 1})
    end
  end

  it "calls #finalize" do
    assert_finalizes(:yaml) { YAMLAttrWithFinalize.from_yaml("---\nvalue: 1\n") }
  end

  describe "work with module and inheritance" do
    it { YAMLAttrModuleTest.from_yaml(%({"phoo": 20})).to_tuple.should eq({10, 20}) }
    it { YAMLAttrModuleTest.from_yaml(%({"phoo": 20})).to_tuple.should eq({10, 20}) }
    it { YAMLAttrModuleTest2.from_yaml(%({"phoo": 20, "bar": 30})).to_tuple.should eq({10, 20, 30}) }
    it { YAMLAttrModuleTest2.from_yaml(%({"bar": 30, "moo": 40})).to_tuple.should eq({40, 15, 30}) }
  end
end
