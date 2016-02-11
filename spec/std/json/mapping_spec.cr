require "spec"
require "json"

class JSONPerson
  JSON.mapping({
    name: {type: String},
    age:  {type: Int32, nilable: true},
  })

  def_equals name, age

  def initialize(@name : String)
  end
end

class StrictJSONPerson
  JSON.mapping({
    name: {type: String},
    age:  {type: Int32, nilable: true},
  }, true)
end

class JSONPersonEmittingNull
  JSON.mapping({
    name: {type: String},
    age:  {type: Int32, nilable: true, emit_null: true},
  })
end

class JSONWithBool
  JSON.mapping({
    value: {type: Bool},
  })
end

class JSONWithTime
  JSON.mapping({
    value: {type: Time, converter: Time::Format.new("%F %T")},
  })
end

class JSONWithNilableTime
  JSON.mapping({
    value: {type: Time, nilable: true, converter: Time::Format.new("%F")},
  })

  def initialize
  end
end

class JSONWithNilableTimeEmittingNull
  JSON.mapping({
    value: {type: Time, nilable: true, converter: Time::Format.new("%F"), emit_null: true},
  })

  def initialize
  end
end

class JSONWithSimpleMapping
  JSON.mapping({name: String, age: Int32})
end

class JSONWithKeywordsMapping
  JSON.mapping({end: Int32, abstract: Int32})
end

class JSONWithAny
  JSON.mapping({name: String, any: JSON::Any})
end

class JsonWithProblematicKeys
  JSON.mapping({
    key:  Int32,
    pull: Int32,
  })
end

class JsonWithSet
  JSON.mapping({set: Set(String)})
end

class JsonWithDefaults
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
    expect_raises JSON::ParseException, "unknown json attribute: foo" do
      StrictJSONPerson.from_json(%({"name": "John", "age": 30, "foo": "bar"}))
    end
  end

  it "raises if non-nilable attribute is nil" do
    expect_raises JSON::ParseException, "missing json attribute: name" do
      JSONPerson.from_json(%({"age": 30}))
    end
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
    json.any.raw.should eq([{"x": 1}, 2, "hey", true, false, 1.5, nil])
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
end
