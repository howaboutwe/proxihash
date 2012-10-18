$:.unshift File.expand_path('../lib', File.dirname(__FILE__))

require 'minitest/spec'
require 'set'
require 'proxihash'

describe Proxihash do
  describe '.encode' do
    it "returns a proxihash for the given lat/lng at the given precision" do
      Proxihash.encode(0, 0, 2).must_equal 'f_'
    end

    it "returns a 5-char proxihash by default" do
      Proxihash.encode(0, 0).must_equal 'f____'
    end

    it "computes the proxihash correctly" do
      # 01-10-01 00-11-11 = pf
      Proxihash.encode(-35.15625, 64.6875, 2).must_equal 'pf'
    end
  end

  describe '.decode' do
    it "returns the lat/lng for the center of the given proxihash's tile" do
      Proxihash.decode('00').must_equal [-88.59375, -177.1875]
      Proxihash.decode('000').must_equal [-89.82421875, -179.6484375]
    end

    it "computes the lat/lng correctly" do
      # 01-10-01 00-11-11 = pf
      Proxihash.decode('pf').must_equal [-35.15625, 64.6875]
    end
  end

  describe 'roundtripping' do
    it "returns the original lat/lng if the lat/lng is in the center of a tile" do
      proxihash = Proxihash.encode(-35.15625, 64.6875, 2)
      Proxihash.decode(proxihash).must_equal [-35.15625, 64.6875]
    end

    it "returns the center of the tile of the given lat/lng" do
      proxihash = Proxihash.encode(-35, 65, 2)
      Proxihash.decode(proxihash).must_equal [-35.15625, 64.6875]
    end
  end

  describe ".tile" do
    it "returns the lat/lng ranges of the given proxihash's tile" do
      Proxihash.tile('pf').must_equal [-36.5625, -33.75, 61.875, 67.5]
    end
  end

  describe ".tiles_for_search" do
    describe "when in 1st quadrant of center tile" do
      it "returns the center tile and the 3 neighbors to the top and right" do
        Proxihash.tiles_for_search(12.9, 25.7, 48.64).to_set.must_equal Set['NNN','NNO','NNP','NNQ']
      end
    end

    describe "when in 2nd quadrant of center tile" do
      it "returns the center tile and the 3 neighbors to the top and left" do
        Proxihash.tiles_for_search(12.9, 25.6, 48.64).to_set.must_equal Set['NNN','NNC','NNE','NNP']
      end
    end

    describe "when in 3rd quadrant of center tile" do
      it "returns the center tile and the 3 neighbors to the bottom and left" do
        Proxihash.tiles_for_search(12.8, 25.6, 48.64).to_set.must_equal Set['NNN','NNC','NNf','NNq']
      end
    end

    describe "when in 4th quadrant of center tile" do
      it "returns the center tile and the 3 neighbors to the bottom and right" do
        Proxihash.tiles_for_search(12.8, 25.7, 48.64).to_set.must_equal Set['NNN','NNO','NNq','NNr']
      end
    end

    describe "higher-radius search" do
      it "returns shorter proxihashes" do
        Proxihash.tiles_for_search(12.66, 25.32, 389.0).to_set.must_equal Set['NN','NO','NP','NQ']
      end
    end

    describe "lower-radius search" do
      it "returns longer proxihashes" do
        Proxihash.tiles_for_search(12.86, 25.71, 6.0).to_set.must_equal Set['NNNN','NNNO','NNNP','NNNQ']
      end
    end
  end

  describe ".neighbor" do
    Proxihash.singleton_class.send :public, :neighbor

    describe "from the center tile" do
      it "returns the tile in the given direction" do
        Proxihash.neighbor('ccc', -1, -1).must_equal 'cc3'
        Proxihash.neighbor('ccc', -1,  0).must_equal 'cc6'
        Proxihash.neighbor('ccc', -1,  1).must_equal 'cc7'

        Proxihash.neighbor('ccc',  0, -1).must_equal 'cc9'
        Proxihash.neighbor('ccc',  0,  0).must_equal 'ccc'
        Proxihash.neighbor('ccc',  0,  1).must_equal 'ccd'

        Proxihash.neighbor('ccc',  1, -1).must_equal 'ccb'
        Proxihash.neighbor('ccc',  1,  0).must_equal 'cce'
        Proxihash.neighbor('ccc',  1,  1).must_equal 'ccf'
      end
    end

    describe "partially recursive case" do
      it "returns the right hash when incrementing the latitude" do
        Proxihash.neighbor('cc_', 1, 0).must_equal 'cel'
      end

      it "returns the right hash when decrementing the latitude" do
        Proxihash.neighbor('cc0', -1, 0).must_equal 'c6H'
      end

      it "returns the right hash when incrementing the longitude" do
        Proxihash.neighbor('cc_', 0, 1).must_equal 'cdH'
      end

      it "returns the right hash when decrementing the longitude" do
        Proxihash.neighbor('cc0', 0, -1).must_equal 'c9l'
      end
    end

    describe "wrapping around lat/lng = 0" do
      it "raises an exception if we wrap around the north pole" do
        ->{ Proxihash.neighbor('000', -1, 0) }.must_raise(Proxihash::PoleWrapException)
      end

      it "raises an exception if we wrap around the south pole" do
        ->{ Proxihash.neighbor('___', 1, 0) }.must_raise(Proxihash::PoleWrapException)
      end

      it "wraps around succesfully when incrementing past the prime meridian" do
        Proxihash.neighbor('lll', 0, 1).must_equal '000'
      end

      it "wraps around succesfully when decrementing past the prime meridian" do
        Proxihash.neighbor('000', 0, -1).must_equal 'lll'
      end
    end

    it "returns tiles whose bounding boxes border the given tile" do
      mc = Proxihash.tile('ccc')

      tl = Proxihash.tile(Proxihash.neighbor('ccc',  1, -1))
      tc = Proxihash.tile(Proxihash.neighbor('ccc',  1,  0))
      tr = Proxihash.tile(Proxihash.neighbor('ccc',  1,  1))
      ml = Proxihash.tile(Proxihash.neighbor('ccc',  0, -1))
      mr = Proxihash.tile(Proxihash.neighbor('ccc',  0,  1))
      bl = Proxihash.tile(Proxihash.neighbor('ccc', -1, -1))
      bc = Proxihash.tile(Proxihash.neighbor('ccc', -1,  0))
      br = Proxihash.tile(Proxihash.neighbor('ccc', -1,  1))

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

  describe '.bits_for_search' do
    Proxihash.singleton_class.send :public, :bits_for_search

    it "is higher toward the poles" do
      Proxihash.bits_for_search(  0, 48.63).must_equal 9
      Proxihash.bits_for_search( 60, 48.63).must_equal 8
      Proxihash.bits_for_search(-60, 48.63).must_equal 8
    end

    it "is lower for larger radii" do
      Proxihash.bits_for_search(0, 48.63).must_equal 9
      Proxihash.bits_for_search(0, 48.64).must_equal 8
    end

    it "raises a PoleWrapException if the search circle overlaps a pole" do
      Proxihash.bits_for_search( 60, 2075)
      ->{ Proxihash.bits_for_search( 60, 2076) }.must_raise Proxihash::PoleWrapException

      Proxihash.bits_for_search(-60, 2075)
      ->{ Proxihash.bits_for_search(-60, 2076) }.must_raise Proxihash::PoleWrapException
    end

    it "raises a PoleWrapException at either pole" do
      ->{ Proxihash.bits_for_search( 90, 0.1) }.must_raise Proxihash::PoleWrapException
      ->{ Proxihash.bits_for_search(-90, 0.1) }.must_raise Proxihash::PoleWrapException
    end

    it "raises an ArgumentError if the radius is zero" do
      ->{ Proxihash.bits_for_search(0, 0) }.must_raise ArgumentError
    end
  end
end
