require "spec"
require "json"
require "big"
require "big/json"
require "uuid"
require "uuid/json"
require "yaml"

record JSONAttrPoint, x : Int32, y : Int32 do
  include JSON::Serializable
end

class JSONAttrEmptyClass
  include JSON::Serializable

  def initialize; end
end

class JSONAttrEmptyClassWithUnmapped
  include JSON::Serializable
  include JSON::Serializable::Unmapped

  def initialize; end
end

class JSONAttrPerson
  include JSON::Serializable

  property name : String
  property age : Int32?

  def_equals name, age

  def initialize(@name : String)
  end
end

struct JSONAttrPersonWithTwoFieldInInitialize
  include JSON::Serializable

  property name : String
  property age : Int32

  def initialize(@name, @age)
  end
end

class StrictJSONAttrPerson
  include JSON::Serializable
  include JSON::Serializable::Strict

  property name : String
  property age : Int32?
end

class JSONAttrPersonExtraFields
  include JSON::Serializable
  include JSON::Serializable::Unmapped

  property name : String
  property age : Int32?
end

class JSONAttrPersonEmittingNull
  include JSON::Serializable

  property name : String

  @[JSON::Field(emit_null: true)]
  property age : Int32?
end

@[JSON::Serializable::Options(emit_nulls: true)]
class JSONAttrPersonEmittingNullsByOptions
  include JSON::Serializable

  property name : String
  property age : Int32?
  property value1 : Int32?

  @[JSON::Field(emit_null: false)]
  property value2 : Int32?
end

class JSONAttrWithBool
  include JSON::Serializable

  property value : Bool
end

class JSONAttrWithUUID
  include JSON::Serializable

  property value : UUID
end

class JSONAttrWithBigDecimal
  include JSON::Serializable

  property value : BigDecimal
end

class JSONAttrWithTime
  include JSON::Serializable

  @[JSON::Field(converter: Time::Format.new("%F %T"))]
  property value : Time
end

class JSONAttrWithNilableTime
  include JSON::Serializable

  @[JSON::Field(converter: Time::Format.new("%F"))]
  property value : Time?

  def initialize
  end
end

class JSONAttrWithNilableTimeEmittingNull
  include JSON::Serializable

  @[JSON::Field(converter: Time::Format.new("%F"), emit_null: true)]
  property value : Time?

  def initialize
  end
end

class JSONAttrWithPropertiesKey
  include JSON::Serializable

  property properties : Hash(String, String)
end

class JSONAttrWithSimpleMapping
  include JSON::Serializable

  property name : String
  property age : Int32
end

class JSONAttrWithKeywordsMapping
  include JSON::Serializable

  property end : Int32
  property abstract : Int32
end

class JSONAttrWithAny
  include JSON::Serializable

  property name : String
  property any : JSON::Any
end

class JSONAttrWithProblematicKeys
  include JSON::Serializable

  property key : Int32
  property pull : Int32
end

class JSONAttrWithSet
  include JSON::Serializable

  property set : Set(String)
end

class JSONAttrWithDefaults
  include JSON::Serializable

  property a = 11
  property b = "Haha"
  property c = true
  property d = false
  property e : Bool? = false
  property f : Int32? = 1
  property g : Int32?
  property h = [1, 2, 3]
end

class JSONAttrWithSmallIntegers
  include JSON::Serializable

  property foo : Int16
  property bar : Int8
end

class JSONAttrWithTimeEpoch
  include JSON::Serializable

  @[JSON::Field(converter: Time::EpochConverter)]
  property value : Time
end

class JSONAttrWithTimeEpochMillis
  include JSON::Serializable

  @[JSON::Field(converter: Time::EpochMillisConverter)]
  property value : Time
end

class JSONAttrWithRaw
  include JSON::Serializable

  @[JSON::Field(converter: String::RawConverter)]
  property value : String
end

class JSONAttrWithRoot
  include JSON::Serializable

  @[JSON::Field(root: "heroes")]
  property result : Array(JSONAttrPerson)
end

class JSONAttrWithNilableRoot
  include JSON::Serializable

  @[JSON::Field(root: "heroes")]
  property result : Array(JSONAttrPerson)?
end

class JSONAttrWithNilableRootEmitNull
  include JSON::Serializable

  @[JSON::Field(root: "heroes", emit_null: true)]
  property result : Array(JSONAttrPerson)?
end

class JSONAttrWithNilableUnion
  include JSON::Serializable

  property value : Int32?
end

class JSONAttrWithNilableUnion2
  include JSON::Serializable

  property value : Int32 | Nil
end

class JSONAttrWithPresence
  include JSON::Serializable

  @[JSON::Field(presence: true)]
  property first_name : String?

  @[JSON::Field(presence: true)]
  property last_name : String?

  @[JSON::Field(ignore: true)]
  getter? first_name_present : Bool

  @[JSON::Field(ignore: true)]
  getter? last_name_present : Bool
end

class JSONAttrWithQueryAttributes
  include JSON::Serializable

  property? foo : Bool

  @[JSON::Field(key: "is_bar", presence: true)]
  property? bar : Bool = false

  @[JSON::Field(ignore: true)]
  getter? bar_present : Bool
end

module JSONAttrModule
  property moo : Int32 = 10
end

class JSONAttrModuleTest
  include JSONAttrModule
  include JSON::Serializable

  @[JSON::Field(key: "phoo")]
  property foo = 15

  def initialize; end

  def to_tuple
    {@moo, @foo}
  end
end

class JSONAttrModuleTest2 < JSONAttrModuleTest
  property bar : Int32

  def initialize(@bar : Int32); end

  def to_tuple
    {@moo, @foo, @bar}
  end
end

struct JSONAttrPersonWithYAML
  include JSON::Serializable
  include YAML::Serializable

  property name : String
  property age : Int32?

  def initialize(@name : String, @age : Int32? = nil)
  end
end

struct JSONAttrPersonWithYAMLInitializeHook
  include JSON::Serializable
  include YAML::Serializable

  property name : String
  property age : Int32?

  def initialize(@name : String, @age : Int32? = nil)
    after_initialize
  end

  @[JSON::Field(ignore: true)]
  @[YAML::Field(ignore: true)]
  property msg : String?

  def after_initialize
    @msg = "Hello " + name
  end
end

describe "JSON mapping" do
  it "works with record" do
    JSONAttrPoint.new(1, 2).to_json.should eq "{\"x\":1,\"y\":2}"
    JSONAttrPoint.from_json(%({"x": 1, "y": 2})).should eq JSONAttrPoint.new(1, 2)
  end

  it "empty class" do
    e = JSONAttrEmptyClass.new
    e.to_json.should eq "{}"
    JSONAttrEmptyClass.from_json("{}")
  end

  it "empty class with unmapped" do
    JSONAttrEmptyClassWithUnmapped.from_json(%({"name": "John", "age": 30})).json_unmapped.should eq({"name" => "John", "age" => 30})
  end

  it "parses person" do
    person = JSONAttrPerson.from_json(%({"name": "John", "age": 30}))
    person.should be_a(JSONAttrPerson)
    person.name.should eq("John")
    person.age.should eq(30)
  end

  it "parses person without age" do
    person = JSONAttrPerson.from_json(%({"name": "John"}))
    person.should be_a(JSONAttrPerson)
    person.name.should eq("John")
    person.name.size.should eq(4) # This verifies that name is not nilable
    person.age.should be_nil
  end

  it "parses array of people" do
    people = Array(JSONAttrPerson).from_json(%([{"name": "John"}, {"name": "Doe"}]))
    people.size.should eq(2)
  end

  it "works with class with two fields" do
    person1 = JSONAttrPersonWithTwoFieldInInitialize.from_json(%({"name": "John", "age": 30}))
    person2 = JSONAttrPersonWithTwoFieldInInitialize.new("John", 30)
    person1.should eq person2
  end

  it "does to_json" do
    person = JSONAttrPerson.from_json(%({"name": "John", "age": 30}))
    person2 = JSONAttrPerson.from_json(person.to_json)
    person2.should eq(person)
  end

  it "parses person with unknown attributes" do
    person = JSONAttrPerson.from_json(%({"name": "John", "age": 30, "foo": "bar"}))
    person.should be_a(JSONAttrPerson)
    person.name.should eq("John")
    person.age.should eq(30)
  end

  it "parses strict person with unknown attributes" do
    error_message = <<-'MSG'
      Unknown JSON attribute: foo
        parsing StrictJSONAttrPerson
      MSG
    ex = expect_raises JSON::MappingError, error_message do
      StrictJSONAttrPerson.from_json <<-JSON
        {
          "name": "John",
          "age": 30,
          "foo": "bar"
        }
        JSON
    end
    ex.location.should eq({4, 3})
  end

  it "should parse extra fields (JSONAttrPersonExtraFields with on_unknown_json_attribute)" do
    person = JSONAttrPersonExtraFields.from_json(%({"name": "John", "age": 30, "x": "1", "y": 2, "z": [1,2,3]}))
    person.name.should eq("John")
    person.age.should eq(30)
    person.json_unmapped.should eq({"x" => "1", "y" => 2_i64, "z" => [1, 2, 3]})
  end

  it "should to store extra fields (JSONAttrPersonExtraFields with on_to_json)" do
    person = JSONAttrPersonExtraFields.from_json(%({"name": "John", "age": 30, "x": "1", "y": 2, "z": [1,2,3]}))
    person.name = "John1"
    person.json_unmapped.delete("y")
    person.json_unmapped["q"] = JSON::Any.new("w")
    person.to_json.should eq "{\"name\":\"John1\",\"age\":30,\"x\":\"1\",\"z\":[1,2,3],\"q\":\"w\"}"
  end

  it "raises if non-nilable attribute is nil" do
    error_message = <<-'MSG'
      Missing JSON attribute: name
        parsing JSONAttrPerson at 1:1
      MSG
    ex = expect_raises JSON::MappingError, error_message do
      JSONAttrPerson.from_json(%({"age": 30}))
    end
    ex.location.should eq({1, 1})
  end

  it "raises if not an object" do
    error_message = <<-'MSG'
      Expected begin_object but was string at 1:1
        parsing StrictJSONAttrPerson at 0:0
      MSG
    ex = expect_raises JSON::MappingError, error_message do
      StrictJSONAttrPerson.from_json <<-JSON
        "foo"
        JSON
    end
    ex.location.should eq({1, 1})
  end

  it "raises if data type does not match" do
    error_message = <<-MSG
      Couldn't parse (Int32 | Nil) from "foo" at 3:10
      MSG
    ex = expect_raises JSON::MappingError, error_message do
      StrictJSONAttrPerson.from_json <<-JSON
        {
          "name": "John",
          "age": "foo",
          "foo": "bar"
        }
        JSON
    end
    ex.location.should eq({3, 10})
  end

  it "doesn't emit null by default when doing to_json" do
    person = JSONAttrPerson.from_json(%({"name": "John"}))
    (person.to_json =~ /age/).should be_falsey
  end

  it "emits null on request when doing to_json" do
    person = JSONAttrPersonEmittingNull.from_json(%({"name": "John"}))
    (person.to_json =~ /age/).should be_truthy
  end

  it "emit_nulls option" do
    person = JSONAttrPersonEmittingNullsByOptions.from_json(%({"name": "John"}))
    person.to_json.should eq "{\"name\":\"John\",\"age\":null,\"value1\":null}"
  end

  it "doesn't raises on false value when not-nil" do
    json = JSONAttrWithBool.from_json(%({"value": false}))
    json.value.should be_false
  end

  it "parses UUID" do
    uuid = JSONAttrWithUUID.from_json(%({"value": "ba714f86-cac6-42c7-8956-bcf5105e1b81"}))
    uuid.should be_a(JSONAttrWithUUID)
    uuid.value.should eq(UUID.new("ba714f86-cac6-42c7-8956-bcf5105e1b81"))
  end

  it "parses json with Time::Format converter" do
    json = JSONAttrWithTime.from_json(%({"value": "2014-10-31 23:37:16"}))
    json.value.should be_a(Time)
    json.value.to_s.should eq("2014-10-31 23:37:16 UTC")
    json.to_json.should eq(%({"value":"2014-10-31 23:37:16"}))
  end

  it "allows setting a nilable property to nil" do
    person = JSONAttrPerson.new("John")
    person.age = 1
    person.age = nil
  end

  it "parses simple mapping" do
    person = JSONAttrWithSimpleMapping.from_json(%({"name": "John", "age": 30}))
    person.should be_a(JSONAttrWithSimpleMapping)
    person.name.should eq("John")
    person.age.should eq(30)
  end

  it "outputs with converter when nilable" do
    json = JSONAttrWithNilableTime.new
    json.to_json.should eq("{}")
  end

  it "outputs with converter when nilable when emit_null is true" do
    json = JSONAttrWithNilableTimeEmittingNull.new
    json.to_json.should eq(%({"value":null}))
  end

  it "outputs JSON with properties key" do
    input = {
      properties: {"foo" => "bar"},
    }.to_json
    json = JSONAttrWithPropertiesKey.from_json(input)
    json.to_json.should eq(input)
  end

  it "parses json with keywords" do
    json = JSONAttrWithKeywordsMapping.from_json(%({"end": 1, "abstract": 2}))
    json.end.should eq(1)
    json.abstract.should eq(2)
  end

  it "parses json with any" do
    json = JSONAttrWithAny.from_json(%({"name": "Hi", "any": [{"x": 1}, 2, "hey", true, false, 1.5, null]}))
    json.name.should eq("Hi")
    json.any.raw.should eq([{"x" => 1}, 2, "hey", true, false, 1.5, nil])
    json.to_json.should eq(%({"name":"Hi","any":[{"x":1},2,"hey",true,false,1.5,null]}))
  end

  it "parses json with problematic keys" do
    json = JSONAttrWithProblematicKeys.from_json(%({"key": 1, "pull": 2}))
    json.key.should eq(1)
    json.pull.should eq(2)
  end

  it "parses json array as set" do
    json = JSONAttrWithSet.from_json(%({"set": ["a", "a", "b"]}))
    json.set.should eq(Set(String){"a", "b"})
  end

  it "allows small types of integer" do
    json = JSONAttrWithSmallIntegers.from_json(%({"foo": 23, "bar": 7}))

    json.foo.should eq(23)
    typeof(json.foo).should eq(Int16)

    json.bar.should eq(7)
    typeof(json.bar).should eq(Int8)
  end

  describe "parses json with defaults" do
    it "mixed" do
      json = JSONAttrWithDefaults.from_json(%({"a":1,"b":"bla"}))
      json.a.should eq 1
      json.b.should eq "bla"

      json = JSONAttrWithDefaults.from_json(%({"a":1}))
      json.a.should eq 1
      json.b.should eq "Haha"

      json = JSONAttrWithDefaults.from_json(%({"b":"bla"}))
      json.a.should eq 11
      json.b.should eq "bla"

      json = JSONAttrWithDefaults.from_json(%({}))
      json.a.should eq 11
      json.b.should eq "Haha"

      json = JSONAttrWithDefaults.from_json(%({"a":null,"b":null}))
      json.a.should eq 11
      json.b.should eq "Haha"
    end

    it "bool" do
      json = JSONAttrWithDefaults.from_json(%({}))
      json.c.should eq true
      typeof(json.c).should eq Bool
      json.d.should eq false
      typeof(json.d).should eq Bool

      json = JSONAttrWithDefaults.from_json(%({"c":false}))
      json.c.should eq false
      json = JSONAttrWithDefaults.from_json(%({"c":true}))
      json.c.should eq true

      json = JSONAttrWithDefaults.from_json(%({"d":false}))
      json.d.should eq false
      json = JSONAttrWithDefaults.from_json(%({"d":true}))
      json.d.should eq true
    end

    it "with nilable" do
      json = JSONAttrWithDefaults.from_json(%({}))

      json.e.should eq false
      typeof(json.e).should eq(Bool | Nil)

      json.f.should eq 1
      typeof(json.f).should eq(Int32 | Nil)

      json.g.should eq nil
      typeof(json.g).should eq(Int32 | Nil)

      json = JSONAttrWithDefaults.from_json(%({"e":false}))
      json.e.should eq false
      json = JSONAttrWithDefaults.from_json(%({"e":true}))
      json.e.should eq true
    end

    it "create new array every time" do
      json = JSONAttrWithDefaults.from_json(%({}))
      json.h.should eq [1, 2, 3]
      json.h << 4
      json.h.should eq [1, 2, 3, 4]

      json = JSONAttrWithDefaults.from_json(%({}))
      json.h.should eq [1, 2, 3]
    end
  end

  it "uses Time::EpochConverter" do
    string = %({"value":1459859781})
    json = JSONAttrWithTimeEpoch.from_json(string)
    json.value.should be_a(Time)
    json.value.should eq(Time.unix(1459859781))
    json.to_json.should eq(string)
  end

  it "uses Time::EpochMillisConverter" do
    string = %({"value":1459860483856})
    json = JSONAttrWithTimeEpochMillis.from_json(string)
    json.value.should be_a(Time)
    json.value.should eq(Time.unix_ms(1459860483856))
    json.to_json.should eq(string)
  end

  it "parses raw value from int" do
    string = %({"value":123456789123456789123456789123456789})
    json = JSONAttrWithRaw.from_json(string)
    json.value.should eq("123456789123456789123456789123456789")
    json.to_json.should eq(string)
  end

  it "parses raw value from float" do
    string = %({"value":123456789123456789.123456789123456789})
    json = JSONAttrWithRaw.from_json(string)
    json.value.should eq("123456789123456789.123456789123456789")
    json.to_json.should eq(string)
  end

  it "parses raw value from object" do
    string = %({"value":[null,true,false,{"x":[1,1.5]}]})
    json = JSONAttrWithRaw.from_json(string)
    json.value.should eq(%([null,true,false,{"x":[1,1.5]}]))
    json.to_json.should eq(string)
  end

  it "parses with root" do
    json = %({"result":{"heroes":[{"name":"Batman"}]}})
    result = JSONAttrWithRoot.from_json(json)
    result.result.should be_a(Array(JSONAttrPerson))
    result.result.first.name.should eq "Batman"
    result.to_json.should eq(json)
  end

  it "parses with nilable root" do
    json = %({"result":null})
    result = JSONAttrWithNilableRoot.from_json(json)
    result.result.should be_nil
    result.to_json.should eq("{}")
  end

  it "parses with nilable root and emit null" do
    json = %({"result":null})
    result = JSONAttrWithNilableRootEmitNull.from_json(json)
    result.result.should be_nil
    result.to_json.should eq(json)
  end

  it "parses nilable union" do
    obj = JSONAttrWithNilableUnion.from_json(%({"value": 1}))
    obj.value.should eq(1)
    obj.to_json.should eq(%({"value":1}))

    obj = JSONAttrWithNilableUnion.from_json(%({"value": null}))
    obj.value.should be_nil
    obj.to_json.should eq(%({}))

    obj = JSONAttrWithNilableUnion.from_json(%({}))
    obj.value.should be_nil
    obj.to_json.should eq(%({}))
  end

  it "parses nilable union2" do
    obj = JSONAttrWithNilableUnion2.from_json(%({"value": 1}))
    obj.value.should eq(1)
    obj.to_json.should eq(%({"value":1}))

    obj = JSONAttrWithNilableUnion2.from_json(%({"value": null}))
    obj.value.should be_nil
    obj.to_json.should eq(%({}))

    obj = JSONAttrWithNilableUnion2.from_json(%({}))
    obj.value.should be_nil
    obj.to_json.should eq(%({}))
  end

  describe "parses JSON with presence markers" do
    it "parses person with absent attributes" do
      json = JSONAttrWithPresence.from_json(%({"first_name": null}))
      json.first_name.should be_nil
      json.first_name_present?.should be_true
      json.last_name.should be_nil
      json.last_name_present?.should be_false
    end
  end

  describe "with query attributes" do
    it "defines query getter" do
      json = JSONAttrWithQueryAttributes.from_json(%({"foo": true}))
      json.foo?.should be_true
      json.bar?.should be_false
    end

    it "defines query getter with class restriction" do
      {% begin %}
        {% methods = JSONAttrWithQueryAttributes.methods %}
        {{ methods.find(&.name.==("foo?")).return_type }}.should eq(Bool)
        {{ methods.find(&.name.==("bar?")).return_type }}.should eq(Bool)
      {% end %}
    end

    it "defines non-query setter and presence methods" do
      json = JSONAttrWithQueryAttributes.from_json(%({"foo": false}))
      json.bar_present?.should be_false
      json.bar = true
      json.bar?.should be_true
    end

    it "maps non-query attributes" do
      json = JSONAttrWithQueryAttributes.from_json(%({"foo": false, "is_bar": false}))
      json.bar_present?.should be_true
      json.bar?.should be_false
      json.bar = true
      json.to_json.should eq(%({"foo":false,"is_bar":true}))
    end

    it "raises if non-nilable attribute is nil" do
      error_message = <<-'MSG'
        Missing JSON attribute: foo
          parsing JSONAttrWithQueryAttributes at 1:1
        MSG
      ex = expect_raises JSON::MappingError, error_message do
        JSONAttrWithQueryAttributes.from_json(%({"is_bar": true}))
      end
      ex.location.should eq({1, 1})
    end
  end

  describe "BigDecimal" do
    it "parses json string with BigDecimal" do
      json = JSONAttrWithBigDecimal.from_json(%({"value": "10.05"}))
      json.value.should eq(BigDecimal.new("10.05"))
    end

    it "parses large json ints with BigDecimal" do
      json = JSONAttrWithBigDecimal.from_json(%({"value": 9223372036854775808}))
      json.value.should eq(BigDecimal.new("9223372036854775808"))
    end

    it "parses json float with BigDecimal" do
      json = JSONAttrWithBigDecimal.from_json(%({"value": 10.05}))
      json.value.should eq(BigDecimal.new("10.05"))
    end

    it "parses large precision json floats with BigDecimal" do
      json = JSONAttrWithBigDecimal.from_json(%({"value": 0.00045808999999999997}))
      json.value.should eq(BigDecimal.new("0.00045808999999999997"))
    end
  end

  describe "work with module and inheritance" do
    it { JSONAttrModuleTest.from_json(%({"phoo": 20})).to_tuple.should eq({10, 20}) }
    it { JSONAttrModuleTest.from_json(%({"phoo": 20})).to_tuple.should eq({10, 20}) }
    it { JSONAttrModuleTest2.from_json(%({"phoo": 20, "bar": 30})).to_tuple.should eq({10, 20, 30}) }
    it { JSONAttrModuleTest2.from_json(%({"bar": 30, "moo": 40})).to_tuple.should eq({40, 15, 30}) }
  end

  it "works together with yaml" do
    person = JSONAttrPersonWithYAML.new("Vasya", 30)
    person.to_json.should eq "{\"name\":\"Vasya\",\"age\":30}"
    person.to_yaml.should eq "---\nname: Vasya\nage: 30\n"

    JSONAttrPersonWithYAML.from_json(person.to_json).should eq person
    JSONAttrPersonWithYAML.from_yaml(person.to_yaml).should eq person
  end

  it "yaml and json with after_initialize hook" do
    person = JSONAttrPersonWithYAMLInitializeHook.new("Vasya", 30)
    person.msg.should eq "Hello Vasya"

    person.to_json.should eq "{\"name\":\"Vasya\",\"age\":30}"
    person.to_yaml.should eq "---\nname: Vasya\nage: 30\n"

    JSONAttrPersonWithYAMLInitializeHook.from_json(person.to_json).msg.should eq "Hello Vasya"
    JSONAttrPersonWithYAMLInitializeHook.from_yaml(person.to_yaml).msg.should eq "Hello Vasya"
  end
end
