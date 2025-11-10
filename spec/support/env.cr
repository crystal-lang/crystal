def with_env(values : Hash, &)
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

def with_env(**values, &)
  with_env(values.to_h) { yield }
end

def with_system_env(values : Hash, &)
  old_values = {} of String => String?
  begin
    values.each do |key, value|
      key = key.to_s
      old_values[key] = Crystal::System::Env.get(key)
      Crystal::System::Env.set(key, value)
    end

    yield
  ensure
    old_values.each do |key, old_value|
      Crystal::System::Env.set(key, old_value) if old_value
    end
  end
end

def with_system_env(**values, &)
  with_system_env(values.to_h) { yield }
end
