using NCDatasets

export NCarray, NCstack

# CF standards don't enforce dimension names. 
# But these are common, and should take care most dims.
const dimmap = Dict("lat" => Lat, 
                    "latitude" => Lat, 
                    "lon" => Lon, 
                    "long" => Lon, 
                    "longitude" => Lon, 
                    "time" => Time, 
                    "lev" => Vert, 
                    "level" => Vert, 
                    "vertical" => Vert) 

# DimensionalData methods for NCDatasets types ###############################

dims(dataset::NCDatasets.Dataset) = dims(first(keys(dataset)))
dims(dataset::NCDatasets.Dataset, key::Key) = begin
    v = dataset[string(key)]
    dims = []
    for (i, dimname) in enumerate(NCDatasets.dimnames(v))
        if haskey(dataset, dimname)
            dvar = dataset[dimname]
            # Find the matching dimension constructor. If its an unknown name use 
            # the generic Dim with the dim name as type parameter
            dimconstructor = get(dimmap, dimname, Dim{Symbol(dimname)})
            # Get the attrib metadata
            meta = Dict(metadata(dvar))
            order = dvar[end] > dvar[1] ? Order(Forward(), Forward()) : Order(Reverse(), Reverse())
            # Add the dim containing the dimension var array 
            push!(dims, dimconstructor(dvar[:], meta, order))
        else
            # The var doesn't exist. Maybe its `complex` or some other marker
            # so just make it a Dim with that name and range matching the indices
            push!(dims, Dim{Symbol(dimname)}(1:size(v, i)))
        end
    end
    dims = formatdims(v, (dims...,))
end
metadata(dataset::NCDatasets.Dataset) = Dict(dataset.attrib)
metadata(dataset::NCDatasets.Dataset, key::Key) = metadata(dataset[string(key)])

metadata(var::NCDatasets.CFVariable) = Dict(var.attrib)
missingval(var::NCDatasets.CFVariable{<:Union{Missing}}) = missing


# Array ########################################################################

@GeoArrayMixin struct NCarray{A<:AbstractArray{T,N},W} <: AbstractGeoArray{T,N,D} 
    window::W
end

# TODO make this lazy?
NCarray(path::AbstractString; refdims=(), window=()) = 
    ncapply(dataset -> NCarray(dataset; refdims=refdims, window=window), path) 
NCarray(dataset::NCDatasets.Dataset, key=first(nondimkeys(dataset)); 
        refdims=(), name=Symbol(key), window=()) = begin
    var = dataset[string(key)]
    NCarray(Array(var), dims(dataset, key), refdims, metadata(var), missingval(var), name, window)
end


# Stack ########################################################################


@GeoStackMixin struct NCstack{} <: AbstractGeoStack{T} end

"""
    NCstack(filepaths::Union{Tuple,Vector}; dims=(), refdims=(), window=(), metadata=Nothing)

Create a stack from an array or tuple of paths to netcdf files. The first non-dimension 
layer of each file will be used in the stack.

This constructor is intended for handling simple single-layer netcdfs.
"""
NCstack(filepaths::Union{Tuple,Vector}; dims=(), refdims=(), window=(), metadata=Nothing) = begin
    keys = Tuple(Symbol.((ncapply(dataset->first(nondimkeys(dataset)), fp) for fp in filepaths)))
    NCstack(NamedTuple{keys}(filepaths), dims, refdims, window, metadata)
end

safeapply(f, ::NCstack, path) = ncapply(f, path) 
data(s::NCstack, dataset, key::Key, I...) = 
    GeoArray(dataset[string(key)][I...], slicedims(dims(s, key), refdims(s), I)..., 
             metadata(s), missingval(s), Symbol(key))
data(::NCstack, dataset, key::Key, I::Vararg{Integer}) = dataset[string(key)][I...]
data(s::NCstack, dataset, key::Key) = 
    GeoArray(Array(dataset[string(key)]), dims(dataset, key), refdims(s), 
             metadata(s), missingval(s), Symbol(key))
dims(::NCstack, dataset, key::Key) = dims(dataset, key)
missingval(stack::NCstack) = missing

Base.keys(stack::NCstack{<:AbstractString}) = 
    Tuple(Symbol.(safeapply(nondimkeys, stack, source(stack))))
Base.copy!(dataset::AbstractArray, src::NCstack, key) = 
    safeapply(dataset -> copy!(dataset, dataset[string(key)]), src, source(src))


# Utils ########################################################################

ncapply(f, path) = NCDatasets.Dataset(f, path)

nondimkeys(dataset) = begin
    dimkeys = keys(dataset.dim)
    if "bnds" in dimkeys
        dimkeys = setdiff(dimkeys, ("bnds",))
        boundskeys = (k -> dataset[k].attrib["bounds"]).(dimkeys)
        dimkeys = union(dimkeys, boundskeys)
    end
    setdiff(keys(dataset), dimkeys)
end

# save(s::NCstack, path) = begin
#     ds = Dataset(path, "c")

#     for (key, val) in metadata(s)
#         ds[key] = val 
#     end

#     for (key, layer) in s
#         dimstrings = (shortname(dim) for dim in dims(value))

#         defDim.(Ref(ds), dimstrings, size.(val.(dims.(layer))))

#         # Define a variable
#         v = defVar(ds, key, eltype(v), size(layer))
#         # TODO: add dims to variable

#         for (key, val) in metadata(layer)
#             metadata(v)[key] = val
#         end
#         v .= replace_missing(parent(layer), NaN)
#     end
#     close(ds)
# end
