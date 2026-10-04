class Widget
  def convert(value : Int32 | Float64)
  end

  def convert(value : String)
  end
end

Widget.new.convert(true)
