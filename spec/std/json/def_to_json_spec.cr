require "spec"
require "json"

private record JSONPerson, name : String, age : String? = nil do
  JSON.def_to_json({
    name: true,
    age:  true,
  })

  def to_s(io : IO)
    io << name << " (age " << (age || "unknown") << ")"
  end
end

private record JSONPersonEmittingNull, name : String, age : String? = nil do
  JSON.def_to_json({
    name: true,
    age:  {emit_null: true},
  })
end

private record JSONWithBool, value : Bool do
  JSON.def_to_json value: Bool
end

private class JSONWithTime
  JSON.def_to_json({
    value: {converter: Time::Format.new("%F %T")},
  })

  def value
    Time.now
  end
end

private class JSONWithNilableTime
  JSON.def_to_json({
    value: {converter: Time::Format.new("%F")},
  })
  getter value : Time? = nil
end

private class JSONWithNilableTimeEmittingNull
  JSON.def_to_json({
    value: {converter: Time::Format.new("%F"), emit_null: true},
  })
  getter value : Time? = nil
end

private class JSONSimpleSyntax
  JSON.def_to_json([name, :age])

  getter name = "John"
  getter age = 12
end

private class JSONKeywordProperties
  JSON.def_to_json(
    end: {property: end_value},
    abstract: {property: :abstract_value}
  )

  getter end_value = "end"
  getter abstract_value = "abstract"
end

private record JSONWithTimeEpoch, value : Time do
  JSON.def_to_json({
    value: {converter: Time::EpochConverter},
  })
end

private record JSONWithTimeEpochMillis, value : Time do
  JSON.def_to_json({
    value: {converter: Time::EpochMillisConverter},
  })
end

private record JSONWithRaw, value : String do
  JSON.def_to_json({
    value: {converter: String::RawConverter},
  })
end

private record JSONWithRoot, result : Array(JSONPerson) do
  JSON.def_to_json({
    result: {root: "heroes"},
  })
end

private class JSONWithNilableRoot
  JSON.def_to_json({
    result: {root: "heroes"},
  })
  getter result : String? = nil
end

private class JSONWithNilableRootEmitNull
  JSON.def_to_json({
    result: {root: "heroes", emit_null: true},
  })
  getter result : String? = nil
end

private record JSONStringConverted, value : JSONPerson do
  JSON.def_to_json({
    value: {converter: JSON::StringConverter},
  })
end

private record Location, lat : Float64, long : Float64 do
  JSON.def_to_json([lat, long])
end

private record House, street : String, street_number : Int32, location : Location do
  JSON.def_to_json(
    address: true,
    loc: {property: location},
    empty_field: {emit_null: true},
  )

  def address
    "#{street} #{street_number}"
  end

  def empty_field
    nil
  end
end

private module NeighborhoodConverter
  extend self
  JSON.def_to_json(HouseInNeighborhood, {street_number: true})
end

private class HouseInNeighborhood
  getter street : String
  getter street_number : Int32
  getter neighbor : self? = nil

  JSON.def_to_json(
    address: true,
    neighbor: {converter: NeighborhoodConverter}
  )

  def initialize(@street, @street_number, @neighbor = nil)
  end

  def address
    "#{street} #{street_number}"
  end
end

describe "JSON.def_to_json" do
  it "doesn't emit null by default when doing to_json" do
    person = JSONPerson.new("John")
    person.to_json.should_not contain(%("age"))
  end

  it "emits null on request when doing to_json" do
    person = JSONPersonEmittingNull.new("John")
    person.to_json.should contain(%("age"))
  end

  it "outputs with converter when nilable" do
    json = JSONWithNilableTime.new
    json.to_json.should eq("{}")
  end

  it "outputs with converter when nilable when emit_null is true" do
    json = JSONWithNilableTimeEmittingNull.new
    json.to_json.should eq(%({"value":null}))
  end

  it "uses arbitrary method" do
    time = JSONWithTime.new
    time.to_json.should contain(%("value"))
  end

  it "uses Time::EpochConverter" do
    json = JSONWithTimeEpoch.new(Time.epoch(1459859781))
    json.to_json.should eq(%({"value":1459859781}))
  end

  it "uses Time::EpochMillisConverter" do
    json = JSONWithTimeEpochMillis.new(Time.epoch_ms(1459860483856))
    json.to_json.should eq(%({"value":1459860483856}))
  end

  it "uses raw value int" do
    json = JSONWithRaw.new("123456789123456789123456789123456789")
    json.to_json.should eq(%({"value":123456789123456789123456789123456789}))
  end

  it "uses raw value float" do
    json = JSONWithRaw.new("123456789123456789.123456789123456789")
    json.to_json.should eq(%({"value":123456789123456789.123456789123456789}))
  end

  it "uses raw value object" do
    json = JSONWithRaw.new(%([null,true,false,{"x":[1,1.5]}]))
    json.to_json.should eq(%({"value":[null,true,false,{"x":[1,1.5]}]}))
  end

  it "uses root" do
    result = JSONWithRoot.new([JSONPerson.new("Batman")])
    result.to_json.should eq(%({"result":{"heroes":[{"name":"Batman"}]}}))
  end

  it "uses nilable root" do
    result = JSONWithNilableRoot.new
    result.to_json.should eq("{}")
  end

  it "uses root and emit null" do
    result = JSONWithNilableRootEmitNull.new
    result.to_json.should eq(%({"result":null}))
  end

  it "supports simple array syntax" do
    JSONSimpleSyntax.new.to_json.should eq(%({"name":"John","age":12}))
  end

  it "supports keywords with alternate properties" do
    JSONKeywordProperties.new.to_json.should eq(%({"end":"end","abstract":"abstract"}))
  end

  it "uses string converter" do
    person = JSONStringConverted.new(JSONPerson.new("John"))
    person.to_json.should eq %({"value":"John (age unknown)"})
  end

  it "base example works" do
    house = House.new("Crystal Road", 1234, Location.new(12.3, 34.5))
    house.to_json.should eq(%({"address":"Crystal Road 1234","loc":{"lat":12.3,"long":34.5},"empty_field":null}))
  end

  it "converter example works" do
    neighbor = HouseInNeighborhood.new("Crystal Road", 1235)
    house = HouseInNeighborhood.new("Crystal Road", 1234, neighbor)
    house.to_json.should eq(%({"address":"Crystal Road 1234","neighbor":{"street_number":1235}}))
  end
end
