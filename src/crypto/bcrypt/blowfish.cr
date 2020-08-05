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
      @p.to_unsafe[i] ^= next_word(key, pointerof(pos))
    end

    l, r, pos = 0_u32, 0_u32, 0

    (0..17).step(2) do |i|
      l ^= next_word(data, pointerof(pos))
      r ^= next_word(data, pointerof(pos))
      l, r = encrypt_pair(l, r)
      @p.to_unsafe[i] = l
      @p.to_unsafe[i + 1] = r
    end

    (0..1023).step(2) do |i|
      l ^= next_word(data, pointerof(pos))
      r ^= next_word(data, pointerof(pos))
      l, r = encrypt_pair(l, r)
      @s.to_unsafe[i] = l
      @s.to_unsafe[i + 1] = r
    end
  end
end
