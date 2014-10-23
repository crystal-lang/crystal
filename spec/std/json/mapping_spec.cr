require "spec"
require "json"

class JsonPerson
  json_mapping({
    name: {type: String},
    age: {type: Int32, nilable: true},
  })

  def_equals name, age
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

describe "Json mapping" do
  it "parses person" do
    person = JsonPerson.from_json(%({"name": "John", "age": 30}))
    person.is_a?(JsonPerson).should be_true
    person.name.should eq("John")
    person.age.should eq(30)
  end

  it "parses person without age" do
    person = JsonPerson.from_json(%({"name": "John"}))
    person.is_a?(JsonPerson).should be_true
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
    person.is_a?(JsonPerson).should be_true
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
end
