def with_env(values : Hash)
  old_values = ENV.to_h
  begin
    values.each do |key, value|
      key = key.to_s
      ENV[key] = value
    end
    yield
  ensure
    old_values.each do |key, old_value|
      ENV[key] = old_value
    end
  end
end

def with_env(**values)
  with_env(values.to_h) { yield }
end
