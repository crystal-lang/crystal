require "spec"
require "sysctl"

describe Sysctl do
  describe "get_int" do
    it "returns the sysctl value as an int" do
      keys = {% if flag?(:darwin) %}
        ["hw.ncpu", "hw.byteorder"]
      {% elsif flag?(:linux) %}
        ["net.ipv4.ip_forward", "kernel.pty.max"]
      {% else %}
        [] of String
      {% end %}

      keys.each do |key|
        real_value = `sysctl #{key}`.split(": ")[1].to_i32
        value = Sysctl.get_i32(key)
        value.should eq(real_value)
      end
    end

    it "raises on invalid key" do
      expect_raises do
        key = "this.is.an.invalid.sysctl.key"
        Sysctl.get_i32 key
      end
    end
  end

  describe "get_str" do
    it "returns the sysctl value as a string" do
      keys = {% if flag?(:darwin) %}
          ["kern.version", "kern.corefile"]
        {% elsif flag?(:linux) %}
          [] of String
        {% else %}
          [] of String
        {% end %}

      keys.each do |key|
        real_value = `sysctl #{key}`.gsub("#{key}: ", "").chomp
        value = Sysctl.get_str(key, 512)
        value.should eq(real_value)
      end
    end

    it "raises on invalid key" do
      expect_raises do
        key = "this.is.an.invalid.sysctl.key"
        Sysctl.get_str key, 1
      end
    end
  end
end
