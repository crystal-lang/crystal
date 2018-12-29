require "spec"
require "http"

describe HTTP::StatusCode do
  describe ".informational?" do
    it "returns true when given 1xx status code" do
      HTTP::StatusCode.informational?(100).should be true
    end

    it "returns false unless given 1xx status code" do
      HTTP::StatusCode.informational?(999).should be false
    end
  end

  describe ".success?" do
    it "returns true when given 2xx status code" do
      HTTP::StatusCode.success?(200).should be true
    end

    it "returns false unless given 2xx status code" do
      HTTP::StatusCode.success?(999).should be false
    end
  end

  describe ".redirection?" do
    it "returns true when given 3xx status code" do
      HTTP::StatusCode.redirection?(300).should be true
    end

    it "returns false unless given 3xx status code" do
      HTTP::StatusCode.redirection?(999).should be false
    end
  end

  describe ".client_error?" do
    it "returns true when given 4xx status code" do
      HTTP::StatusCode.client_error?(400).should be true
    end

    it "returns false unless given 4xx status code" do
      HTTP::StatusCode.client_error?(999).should be false
    end
  end

  describe ".server_error?" do
    it "returns true when given 5xx status code" do
      HTTP::StatusCode.server_error?(500).should be true
    end

    it "returns false unless given 5xx status code" do
      HTTP::StatusCode.server_error?(999).should be false
    end
  end

  describe ".default_message_for" do
    it "returns a default message for status 200" do
      HTTP::StatusCode.default_message_for(200).should eq("OK")
    end

    it "returns an empty string on non-existent status" do
      HTTP::StatusCode.default_message_for(0).should eq("")
    end
  end
end
