require "spec"
require "http"

describe HTTP::Status do
  describe "#informational?" do
    it "returns true when given 1xx status code" do
      HTTP::Status.new(100).informational?.should be_true
    end

    it "returns false unless given 1xx status code" do
      HTTP::Status.new(999).informational?.should be_false
    end
  end

  describe "#success?" do
    it "returns true when given 2xx status code" do
      HTTP::Status.new(200).success?.should be_true
    end

    it "returns false unless given 2xx status code" do
      HTTP::Status.new(999).success?.should be_false
    end
  end

  describe "#redirection?" do
    it "returns true when given 3xx status code" do
      HTTP::Status.new(300).redirection?.should be_true
    end

    it "returns false unless given 3xx status code" do
      HTTP::Status.new(999).redirection?.should be_false
    end
  end

  describe "#client_error?" do
    it "returns true when given 4xx status code" do
      HTTP::Status.new(400).client_error?.should be_true
    end

    it "returns false unless given 4xx status code" do
      HTTP::Status.new(999).client_error?.should be_false
    end
  end

  describe "#server_error?" do
    it "returns true when given 5xx status code" do
      HTTP::Status.new(500).server_error?.should be_true
    end

    it "returns false unless given 5xx status code" do
      HTTP::Status.new(999).server_error?.should be_false
    end
  end

  describe "#message" do
    it "returns default message for status 200" do
      HTTP::Status.new(200).message.should eq("OK")
    end

    it "returns empty string on non-existent status" do
      HTTP::Status.new(0).message.should eq("")
    end
  end
end
