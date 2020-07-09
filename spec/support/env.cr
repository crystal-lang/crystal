def with_env(**values)
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
