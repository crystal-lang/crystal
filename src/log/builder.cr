require "weak_ref"

# A `Log::Builder` creates `Log` instances for a given source.
# It allows you to bind sources and patterns to a given backend.
# Already created `Log` will be reconfigured as needed.
class Log::Builder
  @mutex = Mutex.new(:unchecked)
  @logs = Hash(String, WeakRef(Log)).new

  private record Binding, source : String, level : Severity, backend : Backend
  @bindings = Array(Binding).new

  # Binds a *source* pattern to a *backend* for all logs that are of severity equal or higher to *level*.
  def bind(source : String, level : Severity, backend : Backend)
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

  # Removes all existing bindings
  def clear
    @mutex.synchronize do
      @bindings.clear
      each_log do |log|
        log.backend = nil
        log.initial_level = :none
      end
    end
  end

  # Returns a `Log` for the given *source* with a severity level and
  # backend according to the bindings in *self*.
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
  def each_log
    @logs.each_value do |log_ref|
      log = log_ref.value
      yield log if log
      # TODO should remove entry if log.nil?
    end
  end

  # :nodoc:
  private def append_backend(log : Log, level : Severity, backend : Backend)
    current_backend = log.backend
    case current_backend
    when Nil
      log.backend = backend
      log.initial_level = level
    when BroadcastBackend
      current_backend.append(backend, level)
      # initial_level needs to be recomputed since the append_backend
      # might be called with the same backend as before but with a
      # different (higher) level
      log.initial_level = current_backend.min_level
      current_backend.level = log.changed_level
    else
      if current_backend == backend
        # if the bind applies for the same backend, the last applied
        # level should be used
        log.initial_level = level
      else
        broadcast = BroadcastBackend.new
        broadcast.append(current_backend, log.initial_level)
        broadcast.append(backend, level)
        broadcast.level = log.changed_level
        log.backend = broadcast
        log.initial_level = broadcast.min_level
      end
    end
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
