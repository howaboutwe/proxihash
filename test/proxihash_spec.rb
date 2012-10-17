$:.unshift File.expand_path('../lib', File.dirname(__FILE__))

require 'minitest/spec'
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
end
