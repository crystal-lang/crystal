class PrettyPrint
  def self.with_color(color_enabled)
    old_color_enabled = PrettyPrint.color_enabled?
    PrettyPrint.color_enabled = color_enabled
    begin
      yield
    ensure
      PrettyPrint.color_enabled = old_color_enabled
    end
  end
end
