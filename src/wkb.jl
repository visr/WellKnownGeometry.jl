"""
Well Known Binary (WKB) represents `geometry` as:
- `UInt8` an endianess header
- `UInt32` a geometry type (if not known beforehand)
- `UInt32` the number of subgeometries (if any depending on the type)
- `Vector[geometry]` the subgeometries (if any depending on the type) or
- `Vector[Float64]` the coordinates of the underlying points

Knowing the type of subgeometries (and thus the SF type hierarchy) is required.
For example, because a Polygon always has rings (either exterior or interior ones),
the (sub)geometry type of those rings are skipped (LinearRing). The opposite
is true for a GeometryCollection, when the subgeometry types are not known beforehand.
"""

# Map GeoInterface type traits directly to their WKB UInt32 interpretation
@enum GeometryType::UInt32 begin
    PointTrait = 1
    LineStringTrait = 2
    PolygonTrait = 3
    MultiPointTrait = 4
    MultiLineStringTrait = 5
    MultiPolygonTrait = 6
    GeometryCollectionTrait = 7
end
inst = instances(GeometryType)
syms = getfield.(Ref(GI), Symbol.(inst))
geowkb = Dict(zip(syms, inst))

"""
getwkb(geom)

Retrieve the Well Known Binary (WKB) as `Vector[UInt8]` for a `geom` that implements the GeoInterface.
"""
function getwkb(geom)
    data = UInt8[]
    getwkb!(data, GI.geomtype(geom), geom, true)
    return data
end

"""
Push WKB to `data` for a Pointlike `type` of `geom``.

`first` indicates whether we need to indicate the type in case this outer geometry or part of a geometrycollection.
"""
function getwkb!(data, type::T, geom, first) where {T<:GI.AbstractPointTrait}
    first && push!(data, 0x01)  # endianness
    first && push!(data, reinterpret(UInt8, [UInt32(geowkb[typeof(type)])])...)
    for i in 1:GI.ncoord(geom)
        push!(data, reinterpret(UInt8, [GI.getcoord(geom, i)])...)
    end
end

"""
Push WKB to `data` for non Pointlike `type` of `geom`.

`first` indicates whether we need to indicate the type in case this outer geometry.
`repeat` indicates whether sub geometries need to indicate their type, in case `geom` is
a geometrycollection.
"""
function _getwkb!(data, type, geom, first, repeat)
    first && push!(data, 0x01)  # endianness
    first && push!(data, reinterpret(UInt8, [UInt32(geowkb[typeof(type)])])...)
    n = GI.ngeom(geom)
    push!(data, reinterpret(UInt8, [UInt32(n)])...)
    for i in 1:n
        sgeom = GI.getgeom(geom, i)
        type = GI.geomtype(sgeom)
        getwkb!(data, type, sgeom, repeat)
    end
end

function getwkb!(data, type::T, geom, first) where {T<:GI.AbstractGeometryTrait}
    _getwkb!(data, type, geom, first, false)
end

function getwkb!(data, type::T, geom, first) where {T<:GI.AbstractGeometryCollectionTrait}
    _getwkb!(data, type, geom, first, true)
end

getwkb!(data, ::Nothing, geom, first) = nothing  # empty geometry has unknown type
