require "spec"
require "db"
require "./dummy_driver"

describe DB::Driver do
  it "should get driver class by name" do
    DB.driver_class("dummy").should eq(DummyDriver)
  end

  it "should instantiate driver with options" do
    db = DB.open "dummy", {"host": "localhost", "port": "1027"}
    db.driver_class.should eq(DummyDriver)
    db.options["host"].should eq("localhost")
    db.options["port"].should eq("1027")
  end
end
