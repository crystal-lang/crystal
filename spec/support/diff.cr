def pending_diff(description = "assert", file = __FILE__, line = __LINE__, end_line = __END_LINE__, &block)
  if Spec.use_diff?
    it(description, file, line, end_line, &block)
  else
    pending("#{description} [no diff]", file, line, end_line)
  end
end
