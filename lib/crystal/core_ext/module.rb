class Module
  def simple_name
    name.gsub /^.*::/, ''
  end
end