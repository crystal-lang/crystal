require "../../spec_helper"

describe "Semantic: require" do
  describe "file not found" do
    it "require" do
      error = assert_error %(require "file_that_doesnt_exist"),
        "can't find file 'file_that_doesnt_exist'"

      error.message.not_nil!.should contain "If you're trying to require a shard:"
    end

    it "relative require" do
      error = assert_error %(require "./file_that_doesnt_exist"),
        "can't find file './file_that_doesnt_exist'"

      error.message.not_nil!.should_not contain "If you're trying to require a shard:"
    end

    it "wildcard" do
      error = assert_error %(require "file_that_doesnt_exist/*"),
        "can't find file 'file_that_doesnt_exist/*'"

      error.message.not_nil!.should contain "If you're trying to require a shard:"
    end

    it "relative wildcard" do
      error = assert_error %(require "./file_that_doesnt_exist/*"),
        "can't find file './file_that_doesnt_exist/*'"

      error.message.not_nil!.should_not contain "If you're trying to require a shard:"
    end
  end
end
