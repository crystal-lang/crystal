module Crystal::System::Time
  def self.compute_utc_offset(seconds : Int64) : Int32
    raise NotImplementedError.new("Crystal::System::Time.compute_utc_offset")
  end

  def self.compute_utc_seconds_and_nanoseconds : {Int64, Int32}
    raise NotImplementedError.new("Crystal::System::Time.compute_utc_seconds_and_nanoseconds")
  end
end
