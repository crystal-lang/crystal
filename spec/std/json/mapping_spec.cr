require "spec"
require "json"

class JSONPerson
  json_mapping({
    name: {type: String},
    age: {type: Int32, nilable: true},
  })

  def_equals name, age

  def initialize(@name : String)
  end
end

class StrictJSONPerson
  json_mapping({
    name: {type: String},
    age: {type: Int32, nilable: true},
  }, true)
end

class JSONPersonEmittingNull
  json_mapping({
    name: {type: String},
    age: {type: Int32, nilable: true, emit_null: true},
  })
end

class JSONWithBool
  json_mapping({
    value: {type: Bool},
  })
end

class JSONWithTime
  json_mapping({
    value: {type: Time, converter: TimeFormat.new("%F %T")},
  })
end

class JSONWithNilableTime
  json_mapping({
    value: {type: Time, converter: TimeFormat.new("%F")},
  })

  def initialize
  end
end

class JSONWithNilableTimeEmittingNull
  json_mapping({
    value: {type: Time, converter: TimeFormat.new("%F"), emit_null: true},
  })

  def initialize
  end
end

class JSONWithSimpleMapping
  json_mapping({name: String, age: Int32})
end

class JSONWithKeywordsMapping
  json_mapping({end: Int32, abstract: Int32})
end

class JSONWithAny
  json_mapping({name: String, any: JSON::Any})
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
    person.name.length.should eq(4) # This verifies that name is not nilable
    person.age.should be_nil
  end

  it "parses array of people" do
    people = Array(JSONPerson).from_json(%([{"name": "John"}, {"name": "Doe"}]))
    people.length.should eq(2)
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
    expect_raises Exception, "unknown json attribute: foo" do
      StrictJSONPerson.from_json(%({"name": "John", "age": 30, "foo": "bar"}))
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

  it "parses json with TimeFormat converter" do
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
    json.any.should eq([{"x": 1}, 2, "hey", true, false, 1.5, nil])
    json.to_json.should eq(%({"name":"Hi","any":[{"x":1},2,"hey",true,false,1.5,null]}))
  end
end
