require "../spec_helper"
require "./spec_helper"

describe Crystal::Config do
  it ".host_target" do
    Crystal::Config.host_target.should eq Crystal::Codegen::Target.new({{ `crystal --version`.lines[-1] }}.lstrip("Default target: "))
  end

  {% if flag?(:linux) %}
    it ".linux_runtime_libc" do
      Crystal::Config.linux_runtime_libc.should eq {{ flag?(:musl) ? "musl" : "gnu" }}
    end
  {% end %}
end
