require "spec"
require "json"

class JsonPerson
  json_mapping({
    name: {type: String},
    age: {type: Int32, nilable: true},
  })

  def_equals name, age

  def initialize(@name : String)
  end
end

class StrictJsonPerson
  json_mapping({
    name: {type: String},
    age: {type: Int32, nilable: true},
  }, true)
end

class JsonPersonEmittingNull
  json_mapping({
    name: {type: String},
    age: {type: Int32, nilable: true, emit_null: true},
  })
end

class JsonWithBool
  json_mapping({
    value: {type: Bool},
  })
end

class JsonWithTime
  json_mapping({
    value: {type: Time, converter: TimeFormat.new("%F %T")},
  })
end

class JsonWithNilableTime
  json_mapping({
    value: {type: Time, converter: TimeFormat.new("%F")},
  })

  def initialize
  end
end

class JsonWithNilableTimeEmittingNull
  json_mapping({
    value: {type: Time, converter: TimeFormat.new("%F"), emit_null: true},
  })

  def initialize
  end
end

class JsonWithSimpleMapping
  json_mapping({name: String, age: Int32})
end

describe "Json mapping" do
  it "parses person" do
    person = JsonPerson.from_json(%({"name": "John", "age": 30}))
    person.should be_a(JsonPerson)
    person.name.should eq("John")
    person.age.should eq(30)
  end

  it "parses person without age" do
    person = JsonPerson.from_json(%({"name": "John"}))
    person.should be_a(JsonPerson)
    person.name.should eq("John")
    person.name.length.should eq(4) # This verifies that name is not nilable
    person.age.should be_nil
  end

  it "parses array of people" do
    people = Array(JsonPerson).from_json(%([{"name": "John"}, {"name": "Doe"}]))
    people.length.should eq(2)
  end

  it "does to_json" do
    person = JsonPerson.from_json(%({"name": "John", "age": 30}))
    person2 = JsonPerson.from_json(person.to_json)
    person2.should eq(person)
  end

  it "parses person with unknown attributes" do
    person = JsonPerson.from_json(%({"name": "John", "age": 30, "foo": "bar"}))
    person.should be_a(JsonPerson)
    person.name.should eq("John")
    person.age.should eq(30)
  end

  it "parses strict person with unknown attributes" do
    expect_raises Exception, "unknown json attribute: foo" do
      StrictJsonPerson.from_json(%({"name": "John", "age": 30, "foo": "bar"}))
    end
  end

  it "doesn't emit null by default when doing to_json" do
    person = JsonPerson.from_json(%({"name": "John"}))
    (person.to_json =~ /age/).should be_falsey
  end

  it "emits null on request when doing to_json" do
    person = JsonPersonEmittingNull.from_json(%({"name": "John"}))
    (person.to_json =~ /age/).should be_truthy
  end

  it "doesn't raises on false value when not-nil" do
    json = JsonWithBool.from_json(%({"value": false}))
    json.value.should be_false
  end

  it "parses json with TimeFormat converter" do
    json = JsonWithTime.from_json(%({"value": "2014-10-31 23:37:16"}))
    json.value.should be_a(Time)
    json.value.to_s.should eq("2014-10-31 23:37:16")
    json.to_json.should eq(%({"value":"2014-10-31 23:37:16"}))
  end

  it "allows setting a nilable property to nil" do
    person = JsonPerson.new("John")
    person.age = 1
    person.age = nil
  end

  it "parses simple mapping" do
    person = JsonWithSimpleMapping.from_json(%({"name": "John", "age": 30}))
    person.should be_a(JsonWithSimpleMapping)
    person.name.should eq("John")
    person.age.should eq(30)
  end

  it "outputs with converter when nilable" do
    json = JsonWithNilableTime.new
    json.to_json.should eq("{}")
  end

  it "outputs with converter when nilable when emit_null is true" do
    json = JsonWithNilableTimeEmittingNull.new
    json.to_json.should eq(%({"value":null}))
  end
end
