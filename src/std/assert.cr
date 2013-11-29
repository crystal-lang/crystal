macro assert_type(var, type)"
  if #{var}.is_a?(#{type})
    #{var}
  else
    raise \"expected #{var} to be a #{type}, not \#{#{var}}\"
  end
"end
