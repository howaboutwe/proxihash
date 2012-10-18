module Proxihash
  autoload :VERSION, 'proxihash/version'

  class << self
    def encode(lat, lng, precision=5)
      lat = lat.to_f
      lng = lng.to_f

      proxihash = ''

      lat0 = -90.0
      lat1 =  90.0
      lng0 = -180.0
      lng1 =  180.0

      precision.times do
        byte = 0
        bit = 5

        while bit >= 0
          mid = 0.5 * (lat0 + lat1)
          if lat > mid
            byte |= (1 << bit)
            lat0 = mid
          else
            lat1 = mid
          end
          bit -= 1

          mid = 0.5 * (lng0 + lng1)
          if lng > mid
            byte |= (1 << bit)
            lng0 = mid
          else
            lng1 = mid
          end
          bit -= 1
        end

        proxihash << BYTE_TO_CHAR[byte]
      end

      proxihash
    end

    def decode(proxihash)
      lat0, lat1, lng0, lng1 = tile(proxihash)
      [0.5 * (lat0 + lat1), 0.5 * (lng0 + lng1)]
    end

    def tile(proxihash)
      lat0 = -90.0
      lat1 =  90.0
      lng0 = -180.0
      lng1 =  180.0

      proxihash.each_byte do |char|
        byte = CHAR_TO_BYTE[char]
        bit = 5

        while bit >= 0
          mid = 0.5 * (lat0 + lat1)
          if byte[bit] == 1
            lat0 = mid
          else
            lat1 = mid
          end
          bit -= 1

          mid = 0.5 * (lng0 + lng1)
          if byte[bit] == 1
            lng0 = mid
          else
            lng1 = mid
          end
          bit -= 1
        end
      end

      [lat0, lat1, lng0, lng1]
    end

    def tiles_for_search(lat, lng, radius)
      lat = lat.to_f
      lng = lng.to_f
      bits = bits_for_search(lat, radius.to_f)
      bytes = (bits/3.0).ceil
      center = encode(lat, lng, bytes)

      tile_lat, tile_lng = decode(center)
      dlat = lat < tile_lat ? -1 : 1
      dlng = lng < tile_lng ? -1 : 1
      [
        center,
        neighbor(center, 0   , dlng),
        neighbor(center, dlat, dlng),
        neighbor(center, dlat,    0),
      ]
    end

    private

    def bits_for_search(lat, radius)
      lat = Math::PI / 180.0 * lat
      radius >= Float::EPSILON or
        raise ArgumentError, "radius too small"
      radius <= RADIUS_OF_EARTH_IN_MILES*(0.5*Math::PI - lat.abs) or
        raise PoleWrapException, "cannot search across pole"
      dlng = Math.asin(Math.sin(0.5*radius/RADIUS_OF_EARTH_IN_MILES)/Math.cos(lat))
      Math.log2(Math::PI/dlng.abs).ceil - 1
    end

    def neighbor(tile, dlat, dlng)
      bytes = tile.each_byte.map { |byte| CHAR_TO_BYTE[byte] }
      bytes = bump(bytes, LAT_MASK, LAT_INCREMENT_MAP, LAT_DECREMENT_MAP, dlat)
      bytes = bump(bytes, LNG_MASK, LNG_INCREMENT_MAP, LNG_DECREMENT_MAP, dlng)
      bytes.map { |byte| BYTE_TO_CHAR[byte].chr }.join
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

  PoleWrapException = Class.new(ArgumentError)

  LAT_MASK = 0b00101010
  LNG_MASK = 0b00010101

  LAT_INCREMENT_MAP = {
    0b000000 => 0b000010,
    0b000010 => 0b001000,
    0b001000 => 0b001010,
    0b001010 => 0b100000,
    0b100000 => 0b100010,
    0b100010 => 0b101000,
    0b101000 => 0b101010,
  }

  LAT_DECREMENT_MAP = {
    0b000010 => 0b000000,
    0b001000 => 0b000010,
    0b001010 => 0b001000,
    0b100000 => 0b001010,
    0b100010 => 0b100000,
    0b101000 => 0b100010,
    0b101010 => 0b101000,
  }

  LNG_INCREMENT_MAP = {
    0b000000 => 0b000001,
    0b000001 => 0b000100,
    0b000100 => 0b000101,
    0b000101 => 0b010000,
    0b010000 => 0b010001,
    0b010001 => 0b010100,
    0b010100 => 0b010101,
  }

  LNG_DECREMENT_MAP = {
    0b000001 => 0b000000,
    0b000100 => 0b000001,
    0b000101 => 0b000100,
    0b010000 => 0b000101,
    0b010001 => 0b010000,
    0b010100 => 0b010001,
    0b010101 => 0b010100,
  }

  BYTE_TO_CHAR = []
  CHAR_TO_BYTE = []
  chars = '0123456789abcdefghijklmnopqrstuvwxzABCDEFGHIJKLMNOPQRSTUVWXZ#$%_'
  chars.each_byte.each_with_index do |byte, index|
    BYTE_TO_CHAR[index] = byte
    CHAR_TO_BYTE[byte] = index
  end

  RADIUS_OF_EARTH_IN_MILES = 3963.1676
end
