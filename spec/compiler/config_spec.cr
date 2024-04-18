require "../spec_helper"
require "./spec_helper"

describe Crystal::Config do
  it ".host_target" do
    {% begin %}
      {% host_triple = Crystal.constant("HOST_TRIPLE") || Crystal::DESCRIPTION.lines[-1].gsub(/^Default target: /, "") %}
      Crystal::Config.host_target.should eq Crystal::Codegen::Target.new({{ host_triple }})
    {% end %}
  end

  {% if flag?(:linux) %}
    it ".linux_runtime_libc" do
      Crystal::Config.linux_runtime_libc.should eq {{ flag?(:musl) ? "musl" : "gnu" }}
    end
  {% end %}
end
