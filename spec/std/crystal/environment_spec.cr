require "spec"
require "crystal/environment"

def with_env(env)
  old_env = ENV[Crystal::Environment::ENV_KEY]?
  begin
    ENV[Crystal::Environment::ENV_KEY] = env
    yield
  ensure
    ENV[Crystal::Environment::ENV_KEY] = old_env
  end
end

describe "Crystal.env" do
  it "makes an alias to Crystal::Environment" do
    Crystal.env.should be_a(Crystal::Environment)
  end
end

describe "Crystal::Environment" do
  it "returns \"#{Crystal::Environment::ENV_DEFAULT}\" as default #name when #{Crystal::Environment::ENV_KEY} variable is not set" do
    with_env(nil) do
      Crystal::Environment.name.should eq Crystal::Environment::ENV_DEFAULT
    end
  end

  it "returns value of #{Crystal::Environment::ENV_KEY} variable as #name" do
    with_env("foo") do
      Crystal::Environment.name.should eq("foo")
    end
  end

  it "sets given #name as value of #{Crystal::Environment::ENV_KEY} variable" do
    old_env = ENV[Crystal::Environment::ENV_KEY]?
    begin
      Crystal::Environment.name = "foo"
      ENV[Crystal::Environment::ENV_KEY]?.should eq("foo")
    ensure
      Crystal::Environment.name = old_env
      ENV[Crystal::Environment::ENV_KEY]?.should eq(old_env)
    end
  end

  {% for env in Crystal::Environment::ENV_VALUES %}
    it "defines {{ env.id }} query method" do
      Crystal::Environment.{{ env.id }}?.should_not be_nil
    end

    it "returns true if given \"{{ env.id }}\" environment matches #{Crystal::Environment::ENV_KEY}" do
      with_env({{ env.id.stringify }}) do
        Crystal::Environment.{{ env.id }}?.should be_true
      end
    end

    it "returns false if given \"{{ env.id }}\" environment does not match #{Crystal::Environment::ENV_KEY}" do
      with_env("foo") do
        Crystal::Environment.{{ env.id }}?.should be_false
      end
    end
  {% end %}
end
