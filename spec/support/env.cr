# Takes advantage that spec runs tests sequentially, and never concurrently or
# in parallel, so we can merely dup/restore the internal snapshot, and only have
# to be careful of reentrant calls.

require "path"

module Crystal::System::Env
  def self.set(key : String, value : String) : Nil
    if self.responds_to?(:check_valid_key)
      self.check_valid_key(key)
    end
    previous_def unless ENV.mocking?
  end

  def self.set(key : String, value : Nil) : Nil
    if self.responds_to?(:check_valid_key)
      self.check_valid_key(key)
    end
    previous_def unless ENV.mocking?
  end
end

{% if flag?(:win32) %}
  module Crystal::System::Dir
    # We could simplify the original method, but GetTempPathW appears to do
    # more than just reading the environment variables (undocumented). For
    # example it also transforms relative paths into absolute paths relative to
    # `Dir.current`.
    def self.tempdir : String
      if ENV.mocking?
        tmp = ENV["TMP"]? || ENV["TEMP"]? || ENV["USERPROFILE"]? || Process.windows_directory
        tmp = ::File.join(current, tmp) unless ::Path.windows(tmp).absolute?
        tmp.rchop('\\')
      else
        previous_def
      end
    end
  end
{% end %}

module ENV
  @@mocking = 0

  def self.mocking?
    @@mocking > 0
  end

  def self.mock(env = nil, &)
    @@mocking += 1
    begin
      original = @@lock.write { @@env.dup }
      begin
        env.try(&.each do |key, value|
          set_internal(key.to_s, value.try(&.to_s))
        end)
        yield
      ensure
        @@lock.write { @@env = original }
      end
    ensure
      @@mocking -= 1
    end
  end
end

def with_env(values : Hash, &)
  ENV.mock(values) { yield }
end

def with_env(**values, &)
  ENV.mock(values) { yield }
end
