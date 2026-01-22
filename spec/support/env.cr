# NOTE: spec runs examples sequentially (one after the other) so modifying the
# environment in an example won't affect other examples... If spec starts
# running examples concurrently the guarantee won't stand anymore and `with_env`
# will have to use a reentrant mutex!

def with_env(values : Hash, &)
  old_values = {} of String => String?
  begin
    values.each do |key, value|
      key = key.to_s
      old_values[key] = ENV[key]?
      ENV.unsafe_set(key, value)
    end

    yield
  ensure
    old_values.each do |key, old_value|
      ENV.unsafe_set(key, old_value)
    end
  end
end

def with_env(**values, &)
  with_env(values.to_h) { yield }
end
