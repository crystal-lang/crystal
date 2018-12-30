require "spec"
require "http"

describe HTTP::Status do
  describe ".informational?" do
    it "returns true when given 1xx status code" do
      HTTP::Status.informational?(100).should be_true
    end

    it "returns false unless given 1xx status code" do
      HTTP::Status.informational?(999).should be_false
    end
  end

  describe ".success?" do
    it "returns true when given 2xx status code" do
      HTTP::Status.success?(200).should be_true
    end

    it "returns false unless given 2xx status code" do
      HTTP::Status.success?(999).should be_false
    end
  end

  describe ".redirection?" do
    it "returns true when given 3xx status code" do
      HTTP::Status.redirection?(300).should be_true
    end

    it "returns false unless given 3xx status code" do
      HTTP::Status.redirection?(999).should be_false
    end
  end

  describe ".client_error?" do
    it "returns true when given 4xx status code" do
      HTTP::Status.client_error?(400).should be_true
    end

    it "returns false unless given 4xx status code" do
      HTTP::Status.client_error?(999).should be_false
    end
  end

  describe ".server_error?" do
    it "returns true when given 5xx status code" do
      HTTP::Status.server_error?(500).should be_true
    end

    it "returns false unless given 5xx status code" do
      HTTP::Status.server_error?(999).should be_false
    end
  end

  describe ".default_message_for" do
    it "returns a default message for status 200" do
      HTTP::Status.default_message_for(200).should eq("OK")
    end

    it "returns an empty string on non-existent status" do
      HTTP::Status.default_message_for(0).should eq("")
    end
  end
end
