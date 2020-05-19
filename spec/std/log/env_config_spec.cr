require "spec"
require "log"
require "log/spec"
require "../../support/env"

private def s(value : Log::Severity)
  value
end

describe "Log.setup_from_env" do
  after_all do
    # Setup logging in specs (again) since these specs perform Log.setup
    Spec.log_setup
  end

  describe "backend" do
    it "is a IOBackend" do
      with_env "LOG_LEVEL": nil do
        builder = Log::Builder.new
        Log.setup_from_env(builder: builder)

        builder.for("").backend.should be_a(Log::IOBackend)
      end
    end

    it "can be changed" do
      with_env "LOG_LEVEL": nil do
        builder = Log::Builder.new
        backend = Log::MemoryBackend.new
        Log.setup_from_env(builder: builder, backend: backend)

        builder.for("").backend.should be(backend)
      end
    end
  end

  describe "default_level" do
    it "is info" do
      with_env "LOG_LEVEL": nil do
        builder = Log::Builder.new
        Log.setup_from_env(builder: builder)

        builder.for("").initial_level.should eq(s(:info))
      end
    end

    it "is used if no LOG_LEVEL is set" do
      with_env "LOG_LEVEL": nil do
        builder = Log::Builder.new
        Log.setup_from_env(builder: builder, default_level: :warn)

        builder.for("").initial_level.should eq(s(:warn))
      end
    end

    it "is not used if LOG_LEVEL is set" do
      with_env "LOG_LEVEL": "DEBUG" do
        builder = Log::Builder.new
        Log.setup_from_env(builder: builder, default_level: :error)

        builder.for("").initial_level.should eq(s(:debug))
      end
    end
  end

  describe "default_sources" do
    it "is *" do
      with_env "LOG_LEVEL": nil do
        builder = Log::Builder.new
        Log.setup_from_env(builder: builder)

        builder.for("lorem.ipsum").backend.should_not be_nil
        builder.for("").backend.should_not be_nil
      end
    end

    it "is used" do
      with_env "LOG_LEVEL": nil do
        builder = Log::Builder.new
        Log.setup_from_env(builder: builder, default_sources: "foo.*")

        builder.for("").backend.should be_nil
        builder.for("lorem.ipsum").backend.should be_nil

        builder.for("foo").backend.should_not be_nil
        builder.for("foo.bar").backend.should_not be_nil
      end
    end

    it "splits sources by comma" do
      with_env "LOG_LEVEL": "info" do
        builder = Log::Builder.new
        Log.setup_from_env(builder: builder, default_sources: "db, , foo.*  ")

        builder.for("db").backend.should_not be_nil
        builder.for("").backend.should_not be_nil
        builder.for("foo").backend.should_not be_nil
        builder.for("foo.bar.baz").backend.should_not be_nil
        builder.for("other").backend.should be_nil
      end
    end
  end

  it "raises on invalid level" do
    expect_raises(ArgumentError) do
      with_env "LOG_LEVEL": "invalid" do
        builder = Log::Builder.new
        Log.setup_from_env(builder: builder)
      end
    end
  end
end
