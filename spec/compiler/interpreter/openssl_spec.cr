{% skip_file if flag?(:without_interpreter) %}
require "./spec_helper"
require "../loader/spec_helper"

describe Crystal::Repl::Interpreter do
  context "openssl" do
    it "can require" do
      interpret(<<-CR, prelude: "prelude")
        require "openssl"
        OpenSSL::SSL::Context::Server.new
        CR
    end
  end
end
