class URI
  # `Punycode` provides an interface for IDNA encoding ([RFC 5980](https://tools.ietf.org/html/rfc5980)), defined in [RFC 3492](https://tools.ietf.org/html/rfc3492).
  #
  # Implementation based on Mathias Bynens' [punnycode.js](https://github.com/bestiejs/punycode.js) project.
  class Punycode
    private BASE         =  36
    private TMIN         =   1
    private TMAX         =  26
    private SKEW         =  38
    private DAMP         = 700
    private INITIAL_BIAS =  72
    private INITIAL_N    = 128

    private DELIMITER = '-'

    private BASE36 = "abcdefghijklmnopqrstuvwxyz0123456789"

    private def self.adapt(delta, numpoints, firsttime)
      delta //= firsttime ? DAMP : 2
      delta += delta // numpoints
      k = 0
      while delta > ((BASE - TMIN) * TMAX) // 2
        delta //= BASE - TMIN
        k += BASE
      end
      k + (((BASE - TMIN + 1) * delta) // (delta + SKEW))
    end

    def self.encode(string) : String
      String.build { |io| encode string, io }
    end

    def self.encode(string, io) : Nil
      others = [] of Char

      string.each_char do |c|
        if c < '\u0080'
          io << c
        else
          others.push c
        end
      end

      return if others.empty?
      others.sort!

      h = string.size - others.size + 1
      delta = 0_u32
      n = INITIAL_N
      bias = INITIAL_BIAS
      firsttime = true
      prev = nil

      io << DELIMITER if h > 1

      others.each do |m|
        next if m == prev
        prev = m

        raise Exception.new("Overflow: input needs wider integers to process") if m.ord - n > (Int32::MAX - delta) // h
        delta += (m.ord - n) * h
        n = m.ord + 1

        string.each_char do |c|
          if c < m
            raise Exception.new("Overflow: input needs wider integers to process") if delta > Int32::MAX - 1
            delta += 1
          elsif c == m
            q = delta
            k = BASE
            loop do
              t = k <= bias ? TMIN : k >= bias + TMAX ? TMAX : k - bias
              break if q < t
              io << BASE36[t + ((q - t) % (BASE - t))]
              q = (q - t) // (BASE - t)
              k += BASE
            end
            io << BASE36[q]

            bias = adapt delta, h, firsttime
            delta = 0
            h += 1
            firsttime = false
          end
        end
        delta += 1
      end
    end

    def self.decode(string) : String
      output, _, rest = string.rpartition(DELIMITER)
      output = output.chars

      n = INITIAL_N
      bias = INITIAL_BIAS
      i = 0
      init = true
      w = oldi = k = 0

      rest.each_char do |c|
        if init
          w = 1
          oldi = i
          k = BASE
          init = false
        end

        digit = case c
                when .ascii_lowercase?
                  c.ord - 0x61
                when .ascii_uppercase?
                  c.ord - 0x41
                when .ascii_number?
                  c.ord - 0x30 + 26
                else
                  raise ArgumentError.new("Invalid input")
                end

        i += digit * w
        t = k <= bias ? TMIN : k >= bias + TMAX ? TMAX : k - bias

        unless digit < t
          w *= BASE - t
          k += BASE
        else
          outsize = output.size + 1
          bias = adapt i - oldi, outsize, oldi == 0
          n += i // outsize
          i %= outsize
          output.insert i, n.chr
          i += 1
          init = true
        end
      end

      raise ArgumentError.new("Invalid input") unless init

      output.join
    end

    def self.to_ascii(string) : String
      return string if string.ascii_only?

      String.build do |io|
        first = true
        string.split('.') do |part|
          unless first
            io << '.'
          end

          if part.ascii_only?
            io << part
          else
            io << "xn--"
            encode part, io
          end

          first = false
        end
      end
    end
  end
end
