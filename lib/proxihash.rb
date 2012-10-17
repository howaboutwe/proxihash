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
  end

  BYTE_TO_CHAR = []
  CHAR_TO_BYTE = []
  chars = '0123456789abcdefghijklmnopqrstuvwxzABCDEFGHIJKLMNOPQRSTUVWXZ#$%_'
  chars.each_byte.each_with_index do |byte, index|
    BYTE_TO_CHAR[index] = byte
    CHAR_TO_BYTE[byte] = index
  end
end
