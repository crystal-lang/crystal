require "./spec_helper"
require "float16"

describe Float16 do
  it "unsafes cast from Int16 and safely convert to Float32 and Float64" do
    # See https://en.wikipedia.org/wiki/Half-precision_floating-point_format#Half_precision_examples
    binary_dump = 0b0_00000_0000000001_i16
    float16 = binary_dump.unsafe_as(Float16)

    float64 = float16.to_f
    float64.should be_a(Float64)
    float64.should be_close(5.96e-8, 0.01e-8)

    float64 = float16.to_f64
    float64.should be_a(Float64)
    float64.should be_close(5.96e-8, 0.01e-8)

    float32 = float16.to_f32
    float32.should be_a(Float32)
    float32.should be_close(5.96e-8, 0.01e-8)
  end

  it "creates from Float32 and Float64" do
    binary_dump = 0b0_00000_0000000001_i16
    float16 = binary_dump.unsafe_as(Float16)

    Float16.new(float16.to_f64).should eq(float16)
    Float16.new(float16.to_f32).should eq(float16)

    float16.to_f64.to_f16.should eq(float16)
    float16.to_f32.to_f16.should eq(float16)
  end

  it "can compare to Float32, Float64 and Int" do
    binary_dump = 0b0_00000_0000000001_i16
    float16_1 = binary_dump.unsafe_as(Float16)
    float16_2 = binary_dump.unsafe_as(Float16)

    float16_1.should eq(float16_2)

    float16_1.should eq(float16_1.to_f32)
    float16_1.should eq(float16_1.to_f64)
    float16_1.should eq(float16_1.to_f64)

    binary_dump_2 = 0b0_11110_1111111111
    float16_3 = binary_dump_2.unsafe_as(Float16)

    float16_3.should eq(65504)
  end

  it "#to_s and #inspect" do
    binary_dump = 0b0_00000_0000000001_i16
    float16 = binary_dump.unsafe_as(Float16)
    float16.to_s.should eq(float16.to_f64.to_s)
    float16.inspect.should eq(float16.to_f64.to_s)
  end
end
