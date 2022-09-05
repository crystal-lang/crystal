require "../spec_helper"
require "./spec_helper"

describe Crystal::Config do
  it ".host_target" do
    {% begin %}
      # TODO: CRYSTAL_SPEC_COMPILER_BIN must be quoted (#11456)
      {% compiler = (env("CRYSTAL_SPEC_COMPILER_BIN") || "bin/crystal").id %}
      Crystal::Config.host_target.should eq Crystal::Codegen::Target.new({{ `#{compiler} --version`.lines[-1] }}.lchop("Default target: "))
    {% end %}
  end

  {% if flag?(:linux) %}
    it ".linux_runtime_libc" do
      Crystal::Config.linux_runtime_libc.should eq {{ flag?(:musl) ? "musl" : "gnu" }}
    end
  {% end %}
end
