require "../../spec_helper"

describe "Semantic: require" do
  describe "file not found" do
    it "require" do
      error = assert_error %(require "file_that_doesnt_exist"),
        "can't find file 'file_that_doesnt_exist'",
        inject_primitives: false

      error.message.not_nil!.should contain "If you're trying to require a shard:"
    end

    it "relative require" do
      error = assert_error %(require "./file_that_doesnt_exist"),
        "can't find file './file_that_doesnt_exist'",
        inject_primitives: false

      error.message.not_nil!.should_not contain "If you're trying to require a shard:"
    end

    it "wildecard" do
      error = assert_error %(require "file_that_doesnt_exist/*"),
        "can't find file 'file_that_doesnt_exist/*'",
        inject_primitives: false

      error.message.not_nil!.should contain "If you're trying to require a shard:"
    end

    it "relative wildecard" do
      error = assert_error %(require "./file_that_doesnt_exist/*"),
        "can't find file './file_that_doesnt_exist/*'",
        inject_primitives: false

      error.message.not_nil!.should_not contain "If you're trying to require a shard:"
    end
  end
end
