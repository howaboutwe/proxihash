## Proxihash

A [GeoHash][geohash] implementation geared toward indexing data for performing
proximity searches at different radii.

The algorithm underlying Proxihash is the GeoHash algorithm, however the hashes
are returned offer the bit string as a numeric value, rather than a base-32
representation. This allows bit-precision, rather than 5-bit precision, which
comes in handy for variable-distance proximity searches.

Proxihash computes for you the tileset required for a given radius search from a
given point, within the specified bit precision range. This range lets you limit
your index to certain precisions, which reflects the search distances you need
to support.

[geohash]: http://en.wikipedia.org/wiki/Geohash

### Usage

Create a proxihash with 31 bits of precision:

    proxihash = Proxihash.encode(42.6, -5.6, 31)

Get the numeric value, for storage:

    proxihash.value     # 939008154
    proxihash.num_bits  # 31

Compute the tile (bounding box) represented by the proxihash:

    proxihash.tile    # [42.5994873046875, 42.60498046875, -5.60302734375, -5.5975341796875]

Find neighbors at the same precision:

    proxihash.neighbor(-1,  1)  # tile to the south-east
    proxihash.neighbor( 1, -1)  # tile to the north-west

    # Alternatively:
    proxihash.north  # same as proxihash.neighbor( 1,  0)
    proxihash.east   # same as proxihash.neighbor( 0,  1)
    proxihash.west   # same as proxihash.neighbor( 0, -1)
    proxihash.south  # same as proxihash.neighbor(-1,  0)

Find the midpoint of the tile:

    proxihash.decode  # [42.60223388671875, -5.60028076171875]

Note that roundtripping through `encode` then `decode` may not give you the same
initial point, as decoding gives you the *center* of the tile. It will give you
a nearby point, however. Roundtripping through `decode` then `encode` will give
you back the same tile.

## Indexing

The idea is to index your data with proxihashes at the precisions you care
about. These precisions depend on the search distances you need to support.

Consider that the radius of the earth is about 40,036 km, (24,873 miles). This
means 16 bits of longitude (16 + 15 = 31 bit proxihash) will give you
sub-kilometer precision. Sub-mile precision requires 29 bits. These fit nicely
into a 32-bit integer.

## Searching

Once you've indexed all your data by their proxihash at the precisions you care
about, you probably want to answer a query like "find all users within 25 miles
of `(lat,lng)`". To do this, you have to find the tiles to search for:

    Proxihash.radius = :earth_in_miles
    Proxihash.search_tiles(lat, lng, 25, min_bits: 11, max_bits: 31)

The first line sets the units to use (default is kilometers).

The second returns up to 4 tiles (proxihashes): the tile that `(lat,lng)` falls
on, plus the 3 neighbors that need to be searched. The 3 neighbors depend on
which quadrant of the center tile `(lat,lng)` falls on. The tile size is the
smallest that will cover the 25 mile search circle.

The precision of the tiles (proxihashes) computed depends on two things: the
distance, and the latitude.

Larger tiles (shorter proxihashes) are required for larger distances and
latitudes nearer the poles; smaller tiles (longer proxihashes) for shorter
distances and latitudes nearer the equator. The latitude makes a difference
because tiles nearer the poles are smaller, and so a circle of a given radius
can cover more tiles of the same angular size near the poles than near the
equator.

There is one caveat that arises from this: Finding neighboring tiles degenerates
toward the poles. If the search circle overlaps a pole, or finding a neighboring
tile requires crossing a pole, a `PoleWrapException` is raised.

The `:max_bits` option prevents you from computing an arbitrarily precise
proxihash if you take the distance from user input. It will simply cap the
precision of the proxihashes returned. The `:min_bits` option makes
`search_tiles` return nil if a larger tile is required. `search_tiles` currently
does not return more than 4 tiles to accomodate a smaller tileset.

## Contributing

 * [Bug reports](https://github.com/howaboutwe/proxihash/issues)
 * [Source](https://github.com/howaboutwe/proxihash)
 * Patches: Fork on Github, send pull request.
   * Include tests where practical.
   * Leave the version alone, or bump it in a separate commit.

## Copyright

Copyright (c) George Ogata. See LICENSE for details.
