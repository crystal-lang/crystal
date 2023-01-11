def with_env(values : Hash)
  old_values = ENV.to_h
  begin
    ENV.merge! values
    yield
  ensure
    ENV.replace old_values
  end
end

def with_env(**values)
  with_env(values.to_h) { yield }
end
