require "spec"
require "http"

describe HTTP::Status do
  describe ".new" do
    it "raises when given invalid status code" do
      expect_raises(ArgumentError, "Invalid HTTP status code: 1000") do
        HTTP::Status.new(1000)
      end
    end

    it "returns an instance when given defined status code" do
      HTTP::Status.new(201).should eq HTTP::Status::CREATED
    end

    it "returns an instance when given undefined status code" do
      HTTP::Status.new(418).should eq HTTP::Status.new(418)
    end
  end

  describe "#code" do
    it "returns the status code" do
      HTTP::Status::INTERNAL_SERVER_ERROR.code.should eq 500
    end
  end

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

  describe "#description" do
    it "returns default description for status 200" do
      HTTP::Status.new(200).description.should eq("OK")
    end

    it "returns nil on non-existent status" do
      HTTP::Status.new(999).description.should eq(nil)
    end
  end
end
