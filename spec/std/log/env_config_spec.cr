require "spec"
require "log"

private def s(value : Log::Severity)
  value
end

private def with_env(**values)
  old_values = {} of String => String?
  begin
    values.each do |key, value|
      key = key.to_s
      old_values[key] = ENV[key]?
      ENV[key] = value
    end

    yield
  ensure
    old_values.each do |key, old_value|
      ENV[key] = old_value
    end
  end
end

describe "Log.setup_from_env" do
  describe "backend" do
    it "is a IOBackend" do
      with_env "CRYSTAL_LOG_LEVEL": nil, "CRYSTAL_LOG_SOURCES": nil do
        builder = Log::Builder.new
        Log.setup_from_env(builder: builder)

        builder.for("").backend.should be_a(Log::IOBackend)
      end
    end

    it "can be changed" do
      with_env "CRYSTAL_LOG_LEVEL": nil, "CRYSTAL_LOG_SOURCES": nil do
        builder = Log::Builder.new
        backend = Log::MemoryBackend.new
        Log.setup_from_env(builder: builder, backend: backend)

        builder.for("").backend.should be(backend)
      end
    end
  end

  describe "default_level" do
    it "is info" do
      with_env "CRYSTAL_LOG_LEVEL": nil, "CRYSTAL_LOG_SOURCES": nil do
        builder = Log::Builder.new
        Log.setup_from_env(builder: builder)

        builder.for("").initial_level.should eq(s(:info))
      end
    end

    it "is used if no CRYSTAL_LOG_LEVEL is set" do
      with_env "CRYSTAL_LOG_LEVEL": nil, "CRYSTAL_LOG_SOURCES": nil do
        builder = Log::Builder.new
        Log.setup_from_env(builder: builder, default_level: :warning)

        builder.for("").initial_level.should eq(s(:warning))
      end
    end

    it "is not used if CRYSTAL_LOG_LEVEL is set" do
      with_env "CRYSTAL_LOG_LEVEL": "DEBUG", "CRYSTAL_LOG_SOURCES": nil do
        builder = Log::Builder.new
        Log.setup_from_env(builder: builder, default_level: :error)

        builder.for("").initial_level.should eq(s(:debug))
      end
    end
  end

  describe "default_sources" do
    it "is *" do
      with_env "CRYSTAL_LOG_LEVEL": nil, "CRYSTAL_LOG_SOURCES": nil do
        builder = Log::Builder.new
        Log.setup_from_env(builder: builder)

        builder.for("lorem.ipsum").backend.should_not be_nil
        builder.for("").backend.should_not be_nil
      end
    end

    it "is used if no CRYSTAL_LOG_SOURCES is set" do
      with_env "CRYSTAL_LOG_LEVEL": nil, "CRYSTAL_LOG_SOURCES": nil do
        builder = Log::Builder.new
        Log.setup_from_env(builder: builder, default_sources: "foo.*")

        builder.for("").backend.should be_nil
        builder.for("lorem.ipsum").backend.should be_nil

        builder.for("foo").backend.should_not be_nil
        builder.for("foo.bar").backend.should_not be_nil
      end
    end

    it "is not used if CRYSTAL_LOG_SOURCES is set" do
      with_env "CRYSTAL_LOG_LEVEL": "DEBUG", "CRYSTAL_LOG_SOURCES": "" do
        builder = Log::Builder.new
        Log.setup_from_env(builder: builder, default_sources: "foo.*")

        builder.for("").backend.should_not be_nil

        builder.for("lorem.ipsum").backend.should be_nil
        builder.for("foo").backend.should be_nil
        builder.for("foo.bar").backend.should be_nil
      end
    end
  end

  it "raises on invalid level" do
    expect_raises(ArgumentError) do
      with_env "CRYSTAL_LOG_LEVEL": "invalid", "CRYSTAL_LOG_SOURCES": nil do
        builder = Log::Builder.new
        Log.setup_from_env(builder: builder)
      end
    end
  end

  it "splits sources by comma" do
    with_env "CRYSTAL_LOG_LEVEL": "info", "CRYSTAL_LOG_SOURCES": "db, , foo.*  " do
      builder = Log::Builder.new
      Log.setup_from_env(builder: builder)

      builder.for("db").backend.should_not be_nil
      builder.for("").backend.should_not be_nil
      builder.for("foo").backend.should_not be_nil
      builder.for("foo.bar.baz").backend.should_not be_nil
      builder.for("other").backend.should be_nil
    end
  end
end
