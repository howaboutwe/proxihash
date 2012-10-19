class Proxihash
  autoload :VERSION, 'proxihash/version'

  def initialize(value, num_bits)
    @value = value
    @num_bits = num_bits
  end

  attr_reader :value, :num_bits

  class << self
    def radius=(radius)
      @radius =
        case radius
        when :earth_in_miles
          3958.761
        when :earth_in_kilometers
          6371.009
        else
          radius
        end
    end

    attr_reader :radius

    def encode(lat, lng, num_bits=30)
      lat = lat.to_f
      lng = lng.to_f

      value = 0

      lat0 = -90.0
      lat1 =  90.0
      lng0 = -180.0
      lng1 =  180.0

      (num_bits - 1).downto(0) do |i|
        if i.odd?
          mid = 0.5 * (lat0 + lat1)
          if lat > mid
            value |= (1 << i)
            lat0 = mid
          else
            lat1 = mid
          end
        else
          mid = 0.5 * (lng0 + lng1)
          if lng > mid
            value |= (1 << i)
            lng0 = mid
          else
            lng1 = mid
          end
        end
      end

      new(value, num_bits)
    end

    def search_tiles(lat, lng, distance)
      lat = lat.to_f
      lng = lng.to_f
      bits = 2*lng_bits(lat, distance.to_f)
      center = encode(lat, lng, bits)

      tile_lat, tile_lng = center.decode
      dlat = lat < tile_lat ? -1 : 1
      dlng = lng < tile_lng ? -1 : 1
      [
        center,
        center.neighbor(0   , dlng),
        center.neighbor(dlat, dlng),
        center.neighbor(dlat,    0),
      ]
    end

    private

    def lng_bits(lat, distance)
      lat = Math::PI / 180.0 * lat
      distance >= Float::EPSILON or
        raise ArgumentError, "distance too small"
      distance <= Proxihash.radius*(0.5*Math::PI - lat.abs) or
        raise PoleWrapException, "cannot search across pole"
      dlng = Math.asin(Math.sin(0.5*distance/Proxihash.radius)/Math.cos(lat))
      Math.log2(Math::PI/dlng.abs).ceil - 1
    end

    def bump(bytes, mask, inc_map, dec_map, direction, i = bytes.size - 1)
      return bytes if direction == 0
      map = direction > 0 ? inc_map : dec_map
      byte = bytes[i]
      bits = map[byte & mask]
      if bits
        bytes[i] = (byte & ~mask) | bits
      elsif i == 0
        if mask == LAT_MASK
          raise PoleWrapException, "can't wrap around pole"
        elsif direction > 0
          bytes[i] &= ~mask
        else
          bytes[i] |= mask
        end
      else
        bytes = bump(bytes, mask, inc_map, dec_map, direction, i-1)
        if direction > 0
          bytes[i] &= ~mask
        else
          bytes[i] |= mask
        end
      end
      bytes
    end
  end

  def decode
    lat0, lat1, lng0, lng1 = tile
    [0.5 * (lat0 + lat1), 0.5 * (lng0 + lng1)]
  end

  def tile
    lat0 = -90.0
    lat1 =  90.0
    lng0 = -180.0
    lng1 =  180.0

    (num_bits - 1).downto(0) do |i|
      if i.odd?
        mid = 0.5 * (lat0 + lat1)
        if value[i] == 1
          lat0 = mid
        else
          lat1 = mid
        end
      else
        mid = 0.5 * (lng0 + lng1)
        if value[i] == 1
          lng0 = mid
        else
          lng1 = mid
        end
      end
    end

    [lat0, lat1, lng0, lng1]
  end

  def neighbor(dlat, dlng)
    value = self.value
    value = bump(value, 1, dlat, false) unless dlat.zero?
    value = bump(value, 0, dlng, true ) unless dlng.zero?
    self.class.new(value, num_bits)
  end

  def ==(other)
    other.is_a?(Proxihash) && value == other.value && num_bits == other.num_bits
  end

  def hash
    value.hash ^ num_bits
  end
  alias eql? ==

  def inspect
    "Proxihash[#{value.to_s(2).rjust(num_bits, '0')}]"
  end

  private

  def bump(value, offset, direction, wrap)
    bit = offset
    if direction > 0
      while bit < num_bits
        if value[bit] == 0
          return value | (1 << bit)
        else
          value &= ~(1 << bit)
        end
        bit += 2
      end
      return value if wrap
    else
      while bit < num_bits
        if value[bit] == 0
          value |= 1 << bit
        else
          return value & ~(1 << bit)
        end
        bit += 2
      end
      return value if wrap
    end
    raise PoleWrapException, "can't wrap around pole"
  end

  PoleWrapException = Class.new(ArgumentError)
  self.radius = :earth_in_kilometers
end
