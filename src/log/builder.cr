require "weak_ref"

# Used in `Log.setup` methods to configure the binding to be used.
module Log::Configuration
  # Binds a *source* pattern to a *backend* for all logs that are of severity equal or higher to *level*.
  abstract def bind(source : String, level : Severity, backend : Backend)
end

# A `Log::Builder` creates `Log` instances for a given source.
# It allows you to bind sources and patterns to a given backend.
# Already created `Log` will be reconfigured as needed.
class Log::Builder
  include Configuration

  @mutex = Mutex.new(:unchecked)
  @logs = Hash(String, WeakRef(Log)).new

  private record Binding, source : String, level : Severity, backend : Backend
  @bindings = Array(Binding).new

  # Binds a *source* pattern to a *backend* for all logs that are of severity equal or higher to *level*.
  def bind(source : String, level : Severity, backend : Backend) : Nil
    # TODO validate source is a valid path

    @mutex.synchronize do
      binding = Binding.new(source: source, level: level, backend: backend)
      @bindings << binding

      each_log do |log|
        if Builder.matches(log.source, binding.source)
          append_backend(log, binding.level, binding.backend)
        end
      end
    end
  end

  # :nodoc:
  # Removes an existing bind. It assumes there was a single bind with that backend.
  def unbind(source : String, level : Severity, backend : Backend) : Nil
    @mutex.synchronize do
      binding = Binding.new(source: source, level: level, backend: backend)
      @bindings.delete(binding) || raise ArgumentError.new("Non-existing binding #{source}, #{level}, #{backend}")

      each_log do |log|
        if Builder.matches(log.source, binding.source)
          remove_backend(log, binding.backend)
        end
      end
    end
  end

  # Removes all existing bindings.
  def clear : Nil
    @mutex.synchronize do
      @bindings.clear
      each_log do |log|
        log.backend = nil
        log.initial_level = :none
      end
    end
  end

  # Returns a `Log` for the given *source* with a severity level and
  # backend according to the bindings in `self`.
  # If new bindings are applied, the existing `Log` instances will be
  # reconfigured.
  # Calling this method multiple times with the same value will return
  # the same object.
  def for(source : String) : Log
    @mutex.synchronize do
      log = @logs[source]?.try &.value

      if log.nil?
        log = Log.new(source, nil, :none)
        @bindings.each do |binding|
          next unless Builder.matches(log.source, binding.source)
          append_backend(log, binding.level, binding.backend)
        end
        @logs[source] = WeakRef.new(log)
      end

      log
    end
  end

  # :nodoc:
  private def each_log(&)
    @logs.reject! { |_, log_ref| log_ref.value.nil? }

    @logs.each_value do |log_ref|
      log = log_ref.value
      yield log if log
    end
  end

  # :nodoc:
  private def append_backend(log : Log, level : Severity, backend : Backend)
    current_backend = log.backend
    case current_backend
    when Nil
      log.backend = backend
      log.initial_level = level
    when backend
      # if the bind applies for the same backend, the last applied
      # level should be used
      log.initial_level = level
    else
      broadcast = current_backend.as?(BroadcastBackend)
      # If the current backend is not a broadcast backend , we need to
      # auto-create a broadcast backend for distributing the different log backends.
      # A broadcast backend explicitly added as a binding, must not be mutated,
      # so that requires to create a new one as well.
      if !broadcast || @bindings.any? { |binding| binding.backend.same?(current_backend) }
        broadcast = BroadcastBackend.new
        broadcast.append(current_backend, log.initial_level)
        log.backend = broadcast
      end
      broadcast.append(backend, level)
      broadcast.level = log.changed_level
      log.initial_level = broadcast.min_level
    end
  end

  # :nodoc:
  private def remove_backend(log : Log, backend : Backend)
    current_backend = log.backend
    case current_backend
    when Nil
      raise ArgumentError.new("Trying to remove backend of a log without one")
    when BroadcastBackend
      current_backend.remove(backend)
      if (single_backend = current_backend.single_backend?)
        log.backend = single_backend[0]
        log.initial_level = single_backend[1]
      else
        log.initial_level = current_backend.min_level
      end
    else
      log.backend = nil
      log.initial_level = :none
    end
  end

  # :nodoc:
  def close : Nil
    @bindings.each &.backend.close
  end

  # :nodoc:
  def self.matches(source : String, pattern : String) : Bool
    return true if source == pattern
    return true if pattern == "*"
    if prefix = pattern.rchop?(".*")
      return true if source == prefix
      # do not match foobar with foo.*
      return true if source.starts_with?(prefix) && source[prefix.size] == '.'
    end
    false
  end
end
