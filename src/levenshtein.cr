def levenshtein(s, t)
  return 0 if s == t

  s_len = s.length
  t_len = t.length

  return t_len if s_len == 0
  return s_len if t_len == 0

  # This is to allocate less memory
  if t_len > s_len
    t, s = s, t
    t_len, s_len = s_len, t_len
  end

  s = s.cstr
  t = t.cstr

  v0 = Pointer(Int32).malloc(t_len + 1) { |i| i }
  v1 = Pointer(Int32).malloc(t_len + 1)

  s_len.times do |i|
    v1[0] = i + 1

    0.upto(t_len - 1) do |j|
      cost = s[i] == t[j] ? 0 : 1
      v1[j + 1] = Math.min(Math.min(v1[j] + 1, v0[j + 1] + 1), v0[j] + cost)
    end

    v0.copy_from(v1, t_len + 1)
  end

  v1[t_len]
end

