require "spec"
require "db"
require "./dummy_driver"

describe DB::Driver do
  it "should get driver class by name" do
    DB.driver_class("dummy").should eq(DummyDriver)
  end

  it "should instantiate driver with options" do
    driver = DB.driver "dummy", {"host": "localhost", "port": "1027"}
    driver.options["host"].should eq("localhost")
    driver.options["port"].should eq("1027")
  end
end
