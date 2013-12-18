macro assert_type(var, type)"
  if #{var}.is_a?(#{type})
    #{var}
  else
    raise \"expected #{var} to be a #{type}, not \#{#{var}}\"
  end
"end

macro assert_responds_to(var, method)"
  if #{var}.responds_to?(:#{method})
    #{var}
  else
    raise \"expected #{var} to respond to :#{method}, not \#{#{var}}\"
  end
"end
