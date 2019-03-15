mutable struct BagNode{T <: Union{Missing, Mill.AbstractNode}, B <: AbstractBags, C} <: AbstractBagNode
    data::T
    bags::B
    metadata::C

    function BagNode(d::T, b::B, m::C) where {T <: Union{Missing, Mill.AbstractNode}, B <: AbstractBags, C}
        ismissing(d) && any(_len.(b.bags) .!= 0) && error("BagNode with nothing in data cannot have a non-empty bag")
        new{T, B, C}(d, b, m)
    end
end

_len(a::UnitRange) = max(a.stop - a.start + 1, 0)
_len(a::Vector) = length(a)

BagNode(data::T, b::Vector, metadata::M = nothing) where {T, M} = BagNode(data, bags(b), metadata)

mapdata(f, x::BagNode) = BagNode(mapdata(f, x.data), x.bags, x.metadata)

Base.ndims(x::BagNode) = 0
LearnBase.nobs(a::AbstractBagNode) = length(a.bags)
LearnBase.nobs(a::AbstractBagNode, ::Type{ObsDim.Last}) = nobs(a)

function Base.getindex(x::BagNode, i::VecOrRange)
    nb, ii = remapbag(x.bags, i)
    isempty(ii) && return(BagNode(missing, nb, nothing))
    BagNode(subset(x.data,ii), nb, subset(x.metadata, i))
end

function reduce(::typeof(catobs), as::Vector{T}) where {T <: BagNode}
    data = filter(!ismissing, [x.data for x in as])
    metadata = filter(!isnothing, [x.metadata for x in as])
    bags = vcat((d.bags for d in as)...)
    BagNode(isempty(data) ? missing : reduce(catobs, data),
            bags,
            isempty(metadata) ? nothing : reduce(catobs, metadata))
end

removeinstances(a::BagNode, mask) = BagNode(subset(a.data, findall(mask)), adjustbags(a.bags, mask), a.metadata)

adjustbags(bags::AlignedBags, mask::T) where {T<:Union{Vector{Bool}, BitArray{1}}} = length2bags(map(b -> sum(@view mask[b]), bags))

function dsprint(io::IO, n::BagNode{T}; pad=[], s="", tr=false) where T
    c = COLORS[(length(pad)%length(COLORS))+1]
    m = T <: Nothing ? " missing " : ""
    paddedprint(io,"BagNode with $(length(n.bags))$(m)bag(s)$(tr_repr(s, tr))\n", color=c)
    paddedprint(io, "  └── ", color=c, pad=pad)
    dsprint(io, n.data, pad = [pad; (c, "      ")], s=s * encode(1, 1), tr=tr)
end
