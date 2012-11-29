class Nil
  def nil?
    true
  end

  def method_missing(name, args)
    puts "Called #{name}(#{args}) for nil"
    exit 1
    nil
  end
end