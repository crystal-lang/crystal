require "../spec_helper"
require "./spec_helper"

describe Crystal::Config do
  it ".host_target" do
    {% begin %}
      # TODO: SPEC_COMPILER must be quoted (#11456)
      {% compiler = (env("SPEC_COMPILER") || "bin/crystal").id %}
      Crystal::Config.host_target.should eq Crystal::Codegen::Target.new({{ `#{compiler} --version`.lines[-1] }}.lchop("Default target: "))
    {% end %}
  end

  {% if flag?(:linux) %}
    it ".linux_runtime_libc" do
      Crystal::Config.linux_runtime_libc.should eq {{ flag?(:musl) ? "musl" : "gnu" }}
    end
  {% end %}
end
