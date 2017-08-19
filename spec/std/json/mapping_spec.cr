require "spec"
require "json"

private class JSONPerson
  JSON.mapping({
    name: {type: String},
    age:  {type: Int32, nilable: true},
  })

  def_equals name, age

  def initialize(@name : String)
  end
end

private class StrictJSONPerson
  JSON.mapping({
    name: {type: String},
    age:  {type: Int32, nilable: true},
  }, true)
end

private class JSONPersonEmittingNull
  JSON.mapping({
    name: {type: String},
    age:  {type: Int32, nilable: true, emit_null: true},
  })
end

private class JSONWithBool
  JSON.mapping value: Bool
end

private class JSONWithTime
  JSON.mapping({
    value: {type: Time, converter: Time::Format.new("%F %T")},
  })
end

private class JSONWithNilableTime
  JSON.mapping({
    value: {type: Time, nilable: true, converter: Time::Format.new("%F")},
  })

  def initialize
  end
end

private class JSONWithNilableTimeEmittingNull
  JSON.mapping({
    value: {type: Time, nilable: true, converter: Time::Format.new("%F"), emit_null: true},
  })

  def initialize
  end
end

private class JSONWithSimpleMapping
  JSON.mapping({name: String, age: Int32})
end

private class JSONWithKeywordsMapping
  JSON.mapping({end: Int32, abstract: Int32})
end

private class JSONWithAny
  JSON.mapping({name: String, any: JSON::Any})
end

private class JsonWithProblematicKeys
  JSON.mapping({
    key:  Int32,
    pull: Int32,
  })
end

private class JsonWithSet
  JSON.mapping({set: Set(String)})
end

private class JsonWithDefaults
  JSON.mapping({
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

private class JSONWithSmallIntegers
  JSON.mapping({
    foo: Int16,
    bar: Int8,
  })
end

private class JSONWithTimeEpoch
  JSON.mapping({
    value: {type: Time, converter: Time::EpochConverter},
  })
end

private class JSONWithTimeEpochMillis
  JSON.mapping({
    value: {type: Time, converter: Time::EpochMillisConverter},
  })
end

private class JSONWithRaw
  JSON.mapping({
    value: {type: String, converter: String::RawConverter},
  })
end

private class JSONWithRoot
  JSON.mapping({
    result: {type: Array(JSONPerson), root: "heroes"},
  })
end

private class JSONWithNilableRoot
  JSON.mapping({
    result: {type: Array(JSONPerson), root: "heroes", nilable: true},
  })
end

private class JSONWithNilableRootEmitNull
  JSON.mapping({
    result: {type: Array(JSONPerson), root: "heroes", nilable: true, emit_null: true},
  })
end

private class JSONWithNilableUnion
  JSON.mapping({
    value: Int32 | Nil,
  })
end

private class JSONWithNilableUnion2
  JSON.mapping({
    value: Int32?,
  })
end

private class JSONWithPresence
  JSON.mapping({
    first_name: {type: String?, presence: true, nilable: true},
    last_name:  {type: String?, presence: true, nilable: true},
  })
end

describe "JSON mapping" do
  it "parses person" do
    person = JSONPerson.from_json(%({"name": "John", "age": 30}))
    person.should be_a(JSONPerson)
    person.name.should eq("John")
    person.age.should eq(30)
  end

  it "parses person without age" do
    person = JSONPerson.from_json(%({"name": "John"}))
    person.should be_a(JSONPerson)
    person.name.should eq("John")
    person.name.size.should eq(4) # This verifies that name is not nilable
    person.age.should be_nil
  end

  it "parses array of people" do
    people = Array(JSONPerson).from_json(%([{"name": "John"}, {"name": "Doe"}]))
    people.size.should eq(2)
  end

  it "does to_json" do
    person = JSONPerson.from_json(%({"name": "John", "age": 30}))
    person2 = JSONPerson.from_json(person.to_json)
    person2.should eq(person)
  end

  it "parses person with unknown attributes" do
    person = JSONPerson.from_json(%({"name": "John", "age": 30, "foo": "bar"}))
    person.should be_a(JSONPerson)
    person.name.should eq("John")
    person.age.should eq(30)
  end

  it "parses strict person with unknown attributes" do
    ex = expect_raises JSON::ParseException, "Unknown json attribute: foo" do
      StrictJSONPerson.from_json <<-JSON
        {
          "name": "John",
          "age": 30,
          "foo": "bar"
        }
        JSON
    end
    ex.location.should eq({4, 3})
  end

  it "raises if non-nilable attribute is nil" do
    ex = expect_raises JSON::ParseException, "Missing json attribute: name" do
      JSONPerson.from_json(%({"age": 30}))
    end
    ex.location.should eq({1, 1})
  end

  it "doesn't emit null by default when doing to_json" do
    person = JSONPerson.from_json(%({"name": "John"}))
    (person.to_json =~ /age/).should be_falsey
  end

  it "emits null on request when doing to_json" do
    person = JSONPersonEmittingNull.from_json(%({"name": "John"}))
    (person.to_json =~ /age/).should be_truthy
  end

  it "doesn't raises on false value when not-nil" do
    json = JSONWithBool.from_json(%({"value": false}))
    json.value.should be_false
  end

  it "parses json with Time::Format converter" do
    json = JSONWithTime.from_json(%({"value": "2014-10-31 23:37:16"}))
    json.value.should be_a(Time)
    json.value.to_s.should eq("2014-10-31 23:37:16")
    json.to_json.should eq(%({"value":"2014-10-31 23:37:16"}))
  end

  it "allows setting a nilable property to nil" do
    person = JSONPerson.new("John")
    person.age = 1
    person.age = nil
  end

  it "parses simple mapping" do
    person = JSONWithSimpleMapping.from_json(%({"name": "John", "age": 30}))
    person.should be_a(JSONWithSimpleMapping)
    person.name.should eq("John")
    person.age.should eq(30)
  end

  it "outputs with converter when nilable" do
    json = JSONWithNilableTime.new
    json.to_json.should eq("{}")
  end

  it "outputs with converter when nilable when emit_null is true" do
    json = JSONWithNilableTimeEmittingNull.new
    json.to_json.should eq(%({"value":null}))
  end

  it "parses json with keywords" do
    json = JSONWithKeywordsMapping.from_json(%({"end": 1, "abstract": 2}))
    json.end.should eq(1)
    json.abstract.should eq(2)
  end

  it "parses json with any" do
    json = JSONWithAny.from_json(%({"name": "Hi", "any": [{"x": 1}, 2, "hey", true, false, 1.5, null]}))
    json.name.should eq("Hi")
    json.any.raw.should eq([{"x" => 1}, 2, "hey", true, false, 1.5, nil])
    json.to_json.should eq(%({"name":"Hi","any":[{"x":1},2,"hey",true,false,1.5,null]}))
  end

  it "parses json with problematic keys" do
    json = JsonWithProblematicKeys.from_json(%({"key": 1, "pull": 2}))
    json.key.should eq(1)
    json.pull.should eq(2)
  end

  it "parses json array as set" do
    json = JsonWithSet.from_json(%({"set": ["a", "a", "b"]}))
    json.set.should eq(Set(String){"a", "b"})
  end

  it "allows small types of integer" do
    json = JSONWithSmallIntegers.from_json(%({"foo": 23, "bar": 7}))

    json.foo.should eq(23)
    typeof(json.foo).should eq(Int16)

    json.bar.should eq(7)
    typeof(json.bar).should eq(Int8)
  end

  describe "parses json with defaults" do
    it "mixed" do
      json = JsonWithDefaults.from_json(%({"a":1,"b":"bla"}))
      json.a.should eq 1
      json.b.should eq "bla"

      json = JsonWithDefaults.from_json(%({"a":1}))
      json.a.should eq 1
      json.b.should eq "Haha"

      json = JsonWithDefaults.from_json(%({"b":"bla"}))
      json.a.should eq 11
      json.b.should eq "bla"

      json = JsonWithDefaults.from_json(%({}))
      json.a.should eq 11
      json.b.should eq "Haha"

      json = JsonWithDefaults.from_json(%({"a":null,"b":null}))
      json.a.should eq 11
      json.b.should eq "Haha"
    end

    it "bool" do
      json = JsonWithDefaults.from_json(%({}))
      json.c.should eq true
      typeof(json.c).should eq Bool
      json.d.should eq false
      typeof(json.d).should eq Bool

      json = JsonWithDefaults.from_json(%({"c":false}))
      json.c.should eq false
      json = JsonWithDefaults.from_json(%({"c":true}))
      json.c.should eq true

      json = JsonWithDefaults.from_json(%({"d":false}))
      json.d.should eq false
      json = JsonWithDefaults.from_json(%({"d":true}))
      json.d.should eq true
    end

    it "with nilable" do
      json = JsonWithDefaults.from_json(%({}))

      json.e.should eq false
      typeof(json.e).should eq(Bool | Nil)

      json.f.should eq 1
      typeof(json.f).should eq(Int32 | Nil)

      json.g.should eq nil
      typeof(json.g).should eq(Int32 | Nil)

      json = JsonWithDefaults.from_json(%({"e":false}))
      json.e.should eq false
      json = JsonWithDefaults.from_json(%({"e":true}))
      json.e.should eq true
    end

    it "create new array every time" do
      json = JsonWithDefaults.from_json(%({}))
      json.h.should eq [1, 2, 3]
      json.h << 4
      json.h.should eq [1, 2, 3, 4]

      json = JsonWithDefaults.from_json(%({}))
      json.h.should eq [1, 2, 3]
    end
  end

  it "uses Time::EpochConverter" do
    string = %({"value":1459859781})
    json = JSONWithTimeEpoch.from_json(string)
    json.value.should be_a(Time)
    json.value.should eq(Time.epoch(1459859781))
    json.to_json.should eq(string)
  end

  it "uses Time::EpochMillisConverter" do
    string = %({"value":1459860483856})
    json = JSONWithTimeEpochMillis.from_json(string)
    json.value.should be_a(Time)
    json.value.should eq(Time.epoch_ms(1459860483856))
    json.to_json.should eq(string)
  end

  it "parses raw value from int" do
    string = %({"value":123456789123456789123456789123456789})
    json = JSONWithRaw.from_json(string)
    json.value.should eq("123456789123456789123456789123456789")
    json.to_json.should eq(string)
  end

  it "parses raw value from float" do
    string = %({"value":123456789123456789.123456789123456789})
    json = JSONWithRaw.from_json(string)
    json.value.should eq("123456789123456789.123456789123456789")
    json.to_json.should eq(string)
  end

  it "parses raw value from object" do
    string = %({"value":[null,true,false,{"x":[1,1.5]}]})
    json = JSONWithRaw.from_json(string)
    json.value.should eq(%([null,true,false,{"x":[1,1.5]}]))
    json.to_json.should eq(string)
  end

  it "parses with root" do
    json = %({"result":{"heroes":[{"name":"Batman"}]}})
    result = JSONWithRoot.from_json(json)
    result.result.should be_a(Array(JSONPerson))
    result.result.first.name.should eq "Batman"
    result.to_json.should eq(json)
  end

  it "parses with nilable root" do
    json = %({"result":null})
    result = JSONWithNilableRoot.from_json(json)
    result.result.should be_nil
    result.to_json.should eq("{}")
  end

  it "parses with nilable root and emit null" do
    json = %({"result":null})
    result = JSONWithNilableRootEmitNull.from_json(json)
    result.result.should be_nil
    result.to_json.should eq(json)
  end

  it "parses nilable union" do
    obj = JSONWithNilableUnion.from_json(%({"value": 1}))
    obj.value.should eq(1)
    obj.to_json.should eq(%({"value":1}))

    obj = JSONWithNilableUnion.from_json(%({"value": null}))
    obj.value.should be_nil
    obj.to_json.should eq(%({}))

    obj = JSONWithNilableUnion.from_json(%({}))
    obj.value.should be_nil
    obj.to_json.should eq(%({}))
  end

  it "parses nilable union2" do
    obj = JSONWithNilableUnion2.from_json(%({"value": 1}))
    obj.value.should eq(1)
    obj.to_json.should eq(%({"value":1}))

    obj = JSONWithNilableUnion2.from_json(%({"value": null}))
    obj.value.should be_nil
    obj.to_json.should eq(%({}))

    obj = JSONWithNilableUnion2.from_json(%({}))
    obj.value.should be_nil
    obj.to_json.should eq(%({}))
  end

  describe "parses JSON with presence markers" do
    it "parses person with absent attributes" do
      json = JSONWithPresence.from_json(%({"first_name": null}))
      json.first_name.should be_nil
      json.first_name_present?.should be_true
      json.last_name.should be_nil
      json.last_name_present?.should be_false
    end
  end
end
