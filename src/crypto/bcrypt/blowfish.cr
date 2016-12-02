require "../bcrypt"
require "../blowfish"

# :nodoc:
class Crypto::Bcrypt::Blowfish < Crypto::Blowfish
  def enhance_key_schedule(data, key, cost)
    enhance_key_schedule(data, key)

    (1_u32 << cost).times do
      expand_key(key)
      expand_key(data)
    end
  end

  def enhance_key_schedule(data, key)
    pos = 0

    0.upto(17) do |i|
      @p[i] ^= next_word(key, pointerof(pos))
    end

    l, r, pos = 0, 0, 0

    0.step(17, 2) do |i|
      l ^= next_word(data, pointerof(pos))
      r ^= next_word(data, pointerof(pos))
      l, r = encrypt_pair(l, r)
      @p[i] = l
      @p[i + 1] = r
    end

    0.upto(3) do |i|
      0.step(255, 2) do |j|
        l ^= next_word(data, pointerof(pos))
        r ^= next_word(data, pointerof(pos))
        l, r = encrypt_pair(l, r)
        @s[i][j] = l
        @s[i][j + 1] = r
      end
    end
  end
end
