class Proxihash
  autoload :VERSION, 'proxihash/version'

  def initialize(value, num_bits)
    @value = value
    @num_bits = num_bits
    num_bits.odd? or
      raise ArgumentError, "bitlength must be odd"
    value < 1 << num_bits or
      raise ArgumentError, "value too large for #{num_bits} bits"
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

    def angular_units=(units)
      case units
      when :radians
        @min_lat = -Math::PI/2
        @max_lat =  Math::PI/2
        @min_lng = -Math::PI
        @max_lng =  Math::PI
      when :degrees
        @min_lat = -90
        @max_lat =  90
        @min_lng = -180
        @max_lng =  180
      else
        raise ArgumentError "angular units must be :radians or :degrees (#{units.inspect} given)"
      end
      @angular_units = units
    end

    attr_reader :radius, :angular_units
    attr_reader :min_lat, :max_lat, :min_lng, :max_lng

    def encode(lat, lng, num_bits=31)
      lat = lat.to_f
      lng = lng.to_f

      value = 0

      lat0 = min_lat
      lat1 = max_lat
      lng0 = min_lng
      lng1 = max_lng

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

    def search_tiles(lat, lng, distance, options={})
      lat = lat.to_f
      lng = lng.to_f
      bits = 2*lng_bits(lat, distance.to_f) - 1

      if (min_bits = options[:min_bits]) && bits < min_bits
        return nil
      end

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
      lat = Math::PI / 180.0 * lat if angular_units == :degrees
      distance >= Float::EPSILON or
        raise ArgumentError, "distance too small"
      distance <= Proxihash.radius*(0.5*Math::PI - lat.abs) or
        raise PoleWrapException, "cannot search across pole"
      dlng = Math.asin(Math.sin(0.5*distance/Proxihash.radius)/Math.cos(lat))
      Math.log2(Math::PI/dlng.abs).ceil - 1
    end
  end

  [:min_lat, :max_lat, :min_lng, :max_lng].each do |name|
    class_eval "def #{name}; self.class.#{name}; end"
  end

  def decode
    lat0, lat1, lng0, lng1 = tile
    [0.5 * (lat0 + lat1), 0.5 * (lng0 + lng1)]
  end

  def tile
    lat0 = min_lat
    lat1 = max_lat
    lng0 = min_lng
    lng1 = max_lng

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

  def north
    neighbor(1, 0)
  end

  def south
    neighbor(-1, 0)
  end

  def east
    neighbor(0, 1)
  end

  def west
    neighbor(0, -1)
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
  self.angular_units = :degrees
end
