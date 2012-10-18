$:.unshift File.expand_path('../lib', File.dirname(__FILE__))

require 'minitest/spec'
require 'set'
require 'proxihash'

describe Proxihash do
  describe '.encode' do
    it "returns a proxihash for the given lat/lng at the given precision" do
      Proxihash.encode(0, 0, 8).must_equal Proxihash.new(0b00111111, 8)
    end

    it "returns a sub-mile (30-bit) proxihash by default" do
      Proxihash.encode(0, 0).must_equal Proxihash.new(0x0f_ff_ff_ff, 30)
    end

    it "computes the proxihash correctly" do
      Proxihash.encode(-35.15625, 64.6875, 12).must_equal Proxihash.new(0b01_10_01_00_11_11, 12)
    end
  end

  describe ".search_tiles" do
    describe "when in the 1st quadrant of a tile" do
      it "returns the center tile and the 3 neighbors to the top and right" do
        center = Proxihash.new(0xc000, 16)
        Proxihash.search_tiles(0.352, 0.704, 97).to_set.must_equal Set[
          center, center.neighbor(1, 0), center.neighbor(1, 1), center.neighbor(0, 1)
        ]
      end
    end

    describe "when in the 2nd quadrant of a tile" do
      it "returns the center tile and the 3 neighbors to the top and left" do
        center = Proxihash.new(0xc000, 16)
        Proxihash.search_tiles(0.352, 0.703, 97).to_set.must_equal Set[
          center, center.neighbor(1, 0), center.neighbor(1, -1), center.neighbor(0, -1)
        ]
      end
    end

    describe "when in the 3rd quadrant of a tile" do
      it "returns the center tile and the 3 neighbors to the bottom and left" do
        center = Proxihash.new(0xc000, 16)
        Proxihash.search_tiles(0.351, 0.703, 97).to_set.must_equal Set[
          center, center.neighbor(0, -1), center.neighbor(-1, -1), center.neighbor(-1, 0)
        ]
      end
    end

    describe "when in the 4th quadrant of a tile" do
      it "returns the center tile and the 3 neighbors to the bottom and right" do
        center = Proxihash.new(0xc000, 16)
        Proxihash.search_tiles(0.351, 0.704, 97).to_set.must_equal Set[
          center, center.neighbor(-1, 0), center.neighbor(-1, 1), center.neighbor(0, 1)
        ]
      end
    end

    describe "larger-radius search" do
      it "returns shorter proxihashes" do
        center = Proxihash.new(0x3000, 14)
        Proxihash.search_tiles(0.704, 1.407, 98).to_set.must_equal Set[
          center, center.neighbor(1, 0), center.neighbor(1, 1), center.neighbor(0, 1)
        ]
      end
    end

    describe "lower-radius search" do
      it "returns longer proxihashes" do
        center = Proxihash.new(0x30000, 18)
        Proxihash.search_tiles(0.176, 0.352, 48).to_set.must_equal Set[
          center, center.neighbor(1, 0), center.neighbor(1, 1), center.neighbor(0, 1)
        ]
      end
    end
  end

  describe '.lng_bits' do
    Proxihash.singleton_class.send :public, :lng_bits

    it "is higher toward the poles" do
      Proxihash.lng_bits(  0, 48.63).must_equal 9
      Proxihash.lng_bits( 60, 48.63).must_equal 8
      Proxihash.lng_bits(-60, 48.63).must_equal 8
    end

    it "is lower for larger radii" do
      Proxihash.lng_bits(0, 48.63).must_equal 9
      Proxihash.lng_bits(0, 48.64).must_equal 8
    end

    it "raises a PoleWrapException if the search circle overlaps a pole" do
      Proxihash.lng_bits( 60, 2075)
      ->{ Proxihash.lng_bits( 60, 2076) }.must_raise Proxihash::PoleWrapException

      Proxihash.lng_bits(-60, 2075)
      ->{ Proxihash.lng_bits(-60, 2076) }.must_raise Proxihash::PoleWrapException
    end

    it "raises a PoleWrapException at either pole" do
      ->{ Proxihash.lng_bits( 90, 0.1) }.must_raise Proxihash::PoleWrapException
      ->{ Proxihash.lng_bits(-90, 0.1) }.must_raise Proxihash::PoleWrapException
    end

    it "raises an ArgumentError if the radius is zero" do
      ->{ Proxihash.lng_bits(0, 0) }.must_raise ArgumentError
    end
  end

  describe '#decode' do
    it "returns the lat/lng for the center of the given proxihash's tile" do
      Proxihash.new(0, 12).decode.must_equal [-88.59375, -177.1875]
      Proxihash.new(0, 18).decode.must_equal [-89.82421875, -179.6484375]
    end

    it "computes the lat/lng correctly" do
      Proxihash.new(0b01_10_01_00_11_11, 12).decode.must_equal [-35.15625, 64.6875]
    end
  end

  describe "#tile" do
    it "returns the lat/lng ranges of the given proxihash's tile" do
      Proxihash.new(0b01_10_01_00_11_11, 12).tile.must_equal [-36.5625, -33.75, 61.875, 67.5]
    end
  end

  describe "#neighbor" do
    describe "to the north" do
      it "increments the latitude" do
        Proxihash.new(0b00_00, 4).neighbor(1, 0).must_equal Proxihash.new(0b00_10, 4)
      end

      it "carries the 1 as necessary" do
        Proxihash.new(0b00_00_10_10, 8).neighbor(1, 0).must_equal Proxihash.new(0b00_10_00_00, 8)
      end

      it "raises a PoleWrapException at the north pole" do
        ->{ Proxihash.new(0b11_10_11_10, 8).neighbor(1, 0) }.must_raise Proxihash::PoleWrapException
      end
    end

    describe "to the south" do
      it "decrements the latitude" do
        Proxihash.new(0b11_11, 4).neighbor(-1, 0).must_equal Proxihash.new(0b11_01, 4)
      end

      it "borrows a 1 as necessary" do
        Proxihash.new(0b11_11_01_01, 8).neighbor(-1, 0).must_equal Proxihash.new(0b11_01_11_11, 8)
      end

      it "raises a PoleWrapException at the south pole" do
        ->{ Proxihash.new(0b01_00_01_00, 8).neighbor(-1, 0) }.must_raise Proxihash::PoleWrapException
      end
    end

    describe "to the east" do
      it "increments the longitude" do
        Proxihash.new(0b00_00, 4).neighbor(0, 1).must_equal Proxihash.new(0b00_01, 4)
      end

      it "carries the 1 as necessary" do
        Proxihash.new(0b00_00_01_01, 8).neighbor(0, 1).must_equal Proxihash.new(0b00_01_00_00, 8)
      end

      it "wraps around at the prime meridian" do
        Proxihash.new(0b11_01_11_01, 8).neighbor(0, 1).must_equal Proxihash.new(0b10_00_10_00, 8)
      end
    end

    describe "to the west" do
      it "decrements the longitude" do
        Proxihash.new(0b11_11, 4).neighbor(0, -1).must_equal Proxihash.new(0b11_10, 4)
      end

      it "borrows a 1 as necessary" do
        Proxihash.new(0b11_11_10_10, 8).neighbor(0, -1).must_equal Proxihash.new(0b11_10_11_11, 8)
      end

      it "wraps around at the prime meridian" do
        Proxihash.new(0b10_00_10_00, 8).neighbor(0, -1).must_equal Proxihash.new(0b11_01_11_01, 8)
      end
    end

    describe "to the north-east" do
      it "increments both latitude and longitude" do
        Proxihash.new(0b00_00, 4).neighbor(1, 1).must_equal Proxihash.new(0b00_11, 4)
      end
    end

    describe "to the north-west" do
      it "increments the latitude, decrements the longitude" do
        Proxihash.new(0b00_01, 4).neighbor(1, -1).must_equal Proxihash.new(0b00_10, 4)
      end
    end

    describe "to the south-east" do
      it "decrements the latitude, increments the longitude" do
        Proxihash.new(0b00_10, 4).neighbor(-1, 1).must_equal Proxihash.new(0b00_01, 4)
      end
    end

    describe "to the south-west" do
      it "decrements both latitude and longitude" do
        Proxihash.new(0b11_11, 4).neighbor(-1, -1).must_equal Proxihash.new(0b11_00, 4)
      end
    end

    describe "when both arguments are zero" do
      it "returns itself" do
        Proxihash.new(0b00_00, 4).neighbor(0, 0).must_equal Proxihash.new(0b00_00, 4)
      end
    end
  end

  describe "#inspect" do
    it "shows the raw binary string to the correct precision" do
      Proxihash.new(0b0011001100, 10).inspect.must_equal 'Proxihash[0011001100]'
    end
  end

  describe "#hash and #eql?" do
    it "allows proxihashes to be used as hash keys" do
      hash = {}
      hash[Proxihash.new(0b0011001100, 10)] = 1
      hash[Proxihash.new(0b0011001100, 10)] = 2
      hash[Proxihash.new(0b0011001100, 10)].must_equal 2
    end

    it "does not treat Proxihashes with different precisions as the same hash key" do
      hash = {}
      hash[Proxihash.new(0b0011001100, 10)] = 1
      hash[Proxihash.new(0b0011001100,  9)] = 2
      hash[Proxihash.new(0b0011001100, 10)].must_equal 1
    end
  end

  describe "tile adjacency" do
    it "returns tiles whose bounding boxes border the given tile" do
      tile = Proxihash.new(0b11_00, 4)

      tl = tile.neighbor( 1, -1).tile
      tc = tile.neighbor( 1,  0).tile
      tr = tile.neighbor( 1,  1).tile
      ml = tile.neighbor( 0, -1).tile
      mc = tile.neighbor( 0,  0).tile
      mr = tile.neighbor( 0,  1).tile
      bl = tile.neighbor(-1, -1).tile
      bc = tile.neighbor(-1,  0).tile
      br = tile.neighbor(-1,  1).tile

      tl[0].must_be_close_to ml[1]
      tc[0].must_be_close_to mc[1]
      tr[0].must_be_close_to mr[1]

      ml[0].must_be_close_to bl[1]
      mc[0].must_be_close_to bc[1]
      mr[0].must_be_close_to br[1]

      tl[3].must_be_close_to tc[2]
      ml[3].must_be_close_to mc[2]
      bl[3].must_be_close_to bc[2]

      tc[3].must_be_close_to tr[2]
      mc[3].must_be_close_to mr[2]
      bc[3].must_be_close_to br[2]

      tl[0].must_be_close_to tc[0]
      tl[1].must_be_close_to tc[1]
      tl[0].must_be_close_to tr[0]
      tl[1].must_be_close_to tr[1]

      tl[2].must_be_close_to ml[2]
      tl[3].must_be_close_to ml[3]
      tl[2].must_be_close_to bl[2]
      tl[3].must_be_close_to bl[3]

      [tl,tc,tr,ml,mc,mr,bl,bc,br].each do |tile|
        assert tile[0] < tile[1]
        assert tile[2] < tile[3]
      end
    end
  end

  describe 'roundtripping' do
    it "returns the original lat/lng if the lat/lng is in the center of a tile" do
      proxihash = Proxihash.encode(-35.15625, 64.6875, 12)
      proxihash.decode.must_equal [-35.15625, 64.6875]
    end

    it "returns the center of the tile of the given lat/lng" do
      proxihash = Proxihash.encode(-35, 65, 12)
      proxihash.decode.must_equal [-35.15625, 64.6875]
    end
  end
end
