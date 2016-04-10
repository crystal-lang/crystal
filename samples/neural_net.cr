# Copied with little modifications from: https://github.com/jruby/rubybench/blob/master/time/bench_neural_net.rb

class Synapse
  property weight : Float64
  property prev_weight : Float64
  property :source_neuron
  property :dest_neuron

  def initialize(@source_neuron : Neuron, @dest_neuron : Neuron)
    @prev_weight = @weight = rand * 2 - 1
  end
end

class Neuron
  LEARNING_RATE = 1.0
  MOMENTUM      = 0.3

  property :synapses_in
  property :synapses_out
  property threshold : Float64
  property prev_threshold : Float64
  property :error
  property :output

  def initialize
    @prev_threshold = @threshold = rand * 2 - 1
    @synapses_in = [] of Synapse
    @synapses_out = [] of Synapse
    @output = 0.0
    @error = 0.0
  end

  def calculate_output
    activation = synapses_in.reduce(0.0) do |sum, synapse|
      sum + synapse.weight * synapse.source_neuron.output
    end
    activation -= threshold

    @output = 1.0 / (1.0 + Math.exp(-activation))
  end

  def derivative
    output * (1 - output)
  end

  def output_train(rate, target)
    @error = (target - output) * derivative
    update_weights(rate)
  end

  def hidden_train(rate)
    @error = synapses_out.reduce(0.0) do |sum, synapse|
      sum + synapse.prev_weight * synapse.dest_neuron.error
    end * derivative
    update_weights(rate)
  end

  def update_weights(rate)
    synapses_in.each do |synapse|
      temp_weight = synapse.weight
      synapse.weight += (rate * LEARNING_RATE * error * synapse.source_neuron.output) + (MOMENTUM * (synapse.weight - synapse.prev_weight))
      synapse.prev_weight = temp_weight
    end
    temp_threshold = threshold
    @threshold += (rate * LEARNING_RATE * error * -1) + (MOMENTUM * (threshold - prev_threshold))
    @prev_threshold = temp_threshold
  end
end

class NeuralNetwork
  @input_layer : Array(Neuron)
  @hidden_layer : Array(Neuron)
  @output_layer : Array(Neuron)

  def initialize(inputs, hidden, outputs)
    @input_layer = (1..inputs).map { Neuron.new }
    @hidden_layer = (1..hidden).map { Neuron.new }
    @output_layer = (1..outputs).map { Neuron.new }

    @input_layer.product(@hidden_layer) do |source, dest|
      synapse = Synapse.new(source, dest)
      source.synapses_out << synapse
      dest.synapses_in << synapse
    end
    @hidden_layer.product(@output_layer) do |source, dest|
      synapse = Synapse.new(source, dest)
      source.synapses_out << synapse
      dest.synapses_in << synapse
    end
  end

  def train(inputs, targets)
    feed_forward(inputs)

    @output_layer.zip(targets) do |neuron, target|
      neuron.output_train(0.3, target)
    end
    @hidden_layer.each do |neuron|
      neuron.hidden_train(0.3)
    end
  end

  def feed_forward(inputs)
    @input_layer.zip(inputs) do |neuron, input|
      neuron.output = input.to_f64
    end
    @hidden_layer.each do |neuron|
      neuron.calculate_output if neuron
    end
    @output_layer.each do |neuron|
      neuron.calculate_output if neuron
    end
  end

  def current_outputs
    @output_layer.map do |neuron|
      neuron.output
    end
  end
end

(ARGV[0]? || 5).to_i.times do
  xor = NeuralNetwork.new(2, 10, 1)

  10000.times do
    xor.train([0, 0], [0])
    xor.train([1, 0], [1])
    xor.train([0, 1], [1])
    xor.train([1, 1], [0])
  end

  xor.feed_forward([0, 0])
  puts xor.current_outputs
  xor.feed_forward([0, 1])
  puts xor.current_outputs
  xor.feed_forward([1, 0])
  puts xor.current_outputs
  xor.feed_forward([1, 1])
  puts xor.current_outputs
end
