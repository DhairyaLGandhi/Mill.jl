"""
    sparsify(x, nnzrate)

Replace `AbstractMatrix` `x` with `SparseMatrixCSC` if at most `nnzrate` fraction of elements is non-zero.

```jldoctest
julia> n = ArrayNode([0 0; 0 0])
2×2 ArrayNode{Array{Int64,2},Nothing}:
 0  0
 0  0

julia> Mill.mapdata(i -> sparsify(i, 0.05), n)
2×2 ArrayNode{SparseMatrixCSC{Int64,Int64},Nothing}:
 0  0
 0  0
```

See also: [`Mill.mapdata`](@ref).
"""
sparsify(x, nnzrate) = x
sparsify(x::Matrix, nnzrate) = (mean(x .!= 0) < nnzrate) ? sparse(x) : x

# can be removed when https://github.com/FluxML/Flux.jl/pull/1357 is merged
function Base.:*(A::AbstractMatrix, B::Adjoint{Bool,<: Flux.OneHotMatrix})
    m = size(A,1)
    Y = similar(A, m, size(B,2))
    Y .= 0
    BT = B'
    for (j,ohv) in enumerate(BT.data)
        ix = ohv.ix
        for i in 1:m
            @inbounds Y[i,ix] += A[i,j]
        end
    end
    Y
end

"""
    pred_lens(p, n)

Return a `Vector` of `Setfield.Lens`es for accessing all nodes/fields in `n` conforming to predicate `p`.

# Examples
```jldoctest
julia> n = ProductNode((BagNode(missing, bags([0:-1, 0:-1])), ArrayNode([1 2; 3 4])))
ProductNode with 2 obs
  ├── BagNode with 2 obs
  │     └── ∅
  └── ArrayNode(2×2 Array with Int64 elements) with 2 obs

julia> pred_lens(x -> x isa ArrayNode, n)
1-element Array{Union{Setfield.ComposedLens{_A,_B} where _B where _A, Setfield.PropertyLens{_A} where _A},1}:
 (@lens _.data[2])
```

See also: [`list_lens`](@ref), [`find_lens`](@ref), [`findnonempty_lens`](@ref).
"""
pred_lens(p::Function, n) = _pred_lens(p, n)

"""
    list_lens(n)

Return a `Vector` of `Setfield.Lens`es for accessing all nodes/fields in `n`.

# Examples
```jldoctest
julia> n = ProductNode((BagNode(missing, bags([0:-1, 0:-1])), ArrayNode([1 2; 3 4])))
ProductNode with 2 obs
  ├── BagNode with 2 obs
  │     └── ∅
  └── ArrayNode(2×2 Array with Int64 elements) with 2 obs

julia> list_lens(n)
9-element Array{Lens,1}:
 (@lens _)
 (@lens _.data[1])
 (@lens _.data[1].data)
 (@lens _.data[1].bags)
 (@lens _.data[1].metadata)
 (@lens _.data[2])
 (@lens _.data[2].data)
 (@lens _.data[2].metadata)
 (@lens _.metadata)
```

See also: [`pred_lens`](@ref), [`find_lens`](@ref), [`findnonempty_lens`](@ref).
"""
list_lens(n) = pred_lens(t -> true, n)

"""
    findnonempty_lens(n)

Return a `Vector` of `Setfield.Lens`es for accessing all nodes/fields in `n` that have at least one observation.

# Examples
```jldoctest
julia> n = ProductNode((BagNode(missing, bags([0:-1, 0:-1])), ArrayNode([1 2; 3 4])))
ProductNode with 2 obs
  ├── BagNode with 2 obs
  │     └── ∅
  └── ArrayNode(2×2 Array with Int64 elements) with 2 obs

julia> findnonempty_lens(n)
3-element Array{Lens,1}:
 (@lens _)
 (@lens _.data[1])
 (@lens _.data[2])
```

See also: [`pred_lens`](@ref), [`list_lens`](@ref), [`find_lens`](@ref).
"""
findnonempty_lens(n) = pred_lens(t -> t isa AbstractNode && nobs(t) > 0, n)

"""
    find_lens(n, x)

Return a `Vector` of `Setfield.Lens`es for accessing all nodes/fields in `n` that return `true` when
compared to `x` using `Base.===`.

# Examples
```jldoctest
julia> n = ProductNode((BagNode(missing, bags([0:-1, 0:-1])), ArrayNode([1 2; 3 4])))
ProductNode with 2 obs
  ├── BagNode with 2 obs
  │     └── ∅
  └── ArrayNode(2×2 Array with Int64 elements) with 2 obs

julia> find_lens(n, n.data[1])
1-element Array{Union{Setfield.ComposedLens{_A,_B} where _B where _A, Setfield.PropertyLens{_A} where _A},1}:
 (@lens _.data[1])
```

See also: [`pred_lens`](@ref), [`list_lens`](@ref), [`findnonempty_lens`](@ref).
"""
find_lens(n, x) = pred_lens(t -> t === x, n)

_pred_lens(p::Function, n) = p(n) ? [IdentityLens()] : Lens[]
function _pred_lens(p::Function, n::T) where T <: MillStruct
    res = vcat([map(l -> PropertyLens{k}() ∘ l, _pred_lens(p, getproperty(n, k)))
                for k in fieldnames(T)]...)
    p(n) ? [IdentityLens(); res] : res
end
function _pred_lens(p::Function, n::Union{Tuple, NamedTuple})
    vcat([map(l -> IndexLens(tuple(i)) ∘ l, _pred_lens(p, n[i])) for i in eachindex(n)]...)
end

"""
    code2lens(n, c)

Convert code `c` from [HierarchicalUtils.jl](@ref) traversal to `Setfield.Lens` such that they access
the same node in tree `n`.

# Examples
```jldoctest
julia> n = ProductNode((BagNode(missing, bags([0:-1, 0:-1])), ArrayNode([1 2; 3 4])));

julia> printtree(n; trav=true)
ProductNode with 2 obs [""]
  ├── BagNode with 2 obs ["E"]
  │     └── ∅ ["M"]
  └── ArrayNode(2×2 Array with Int64 elements) with 2 obs ["U"]

julia> code2lens(n, "U")
(@lens _.data[2])
```

See also: [`lens2code`](@ref).
"""
code2lens(n::MillStruct, c::AbstractString) = find_lens(n, n[c]) |> only

"""
    lens2code(n, l)

Convert `Setfield.Lens` l to code `c` from [HierarchicalUtils.jl](@ref) traversal such that they access
the same node in tree `n`.

# Examples
```jldoctest
julia> n = ProductNode((BagNode(missing, bags([0:-1, 0:-1])), ArrayNode([1 2; 3 4])));

julia> printtree(n; trav=true)
ProductNode with 2 obs [""]
  ├── BagNode with 2 obs ["E"]
  │     └── ∅ ["M"]
  └── ArrayNode(2×2 Array with Int64 elements) with 2 obs ["U"]

julia> lens2code(n, (@lens _.data[2]))
"U"

```

See also: [`code2lens`](@ref).
"""
lens2code(n::MillStruct, l::Lens) = HierarchicalUtils.find_traversal(n, get(n, l)) |> only

"""
    model_lens(m, l)

Convert `Setfield.Lens` `l` for a data node to a new lens for accessing the same location in model `m`.

# Examples
```jldoctest
julia> n = ProductNode((BagNode(ArrayNode(randn(2, 2)), bags([0:-1, 0:-1])), ArrayNode([1 2; 3 4])))
ProductNode with 2 obs
  ├── BagNode with 2 obs
  │     └── ArrayNode(2×2 Array with Float64 elements) with 2 obs
  └── ArrayNode(2×2 Array with Int64 elements) with 2 obs

julia> m = reflectinmodel(n)
ProductModel … ↦ ArrayModel(Dense(20, 10))
  ├── BagModel … ↦ ⟨SegmentedMean(10), SegmentedMax(10)⟩ ↦ ArrayModel(Dense(21, 10))
  │     └── ArrayModel(Dense(2, 10))
  └── ArrayModel(Dense(2, 10))

julia> model_lens(m, (@lens _.data[2]))
(@lens _.ms[2])
```

See also: [`data_lens`](@ref).
"""
function model_lens(model, lens::ComposedLens)
    outerlens = model_lens(model, lens.outer)
    outerlens ∘ model_lens(get(model, outerlens), lens.inner)
end
model_lens(::ArrayModel, ::PropertyLens{:data}) = @lens _.m
model_lens(::BagModel, ::PropertyLens{:data}) = @lens _.im
model_lens(::ProductModel, ::PropertyLens{:data}) = @lens _.ms
model_lens(::Union{NamedTuple, Tuple}, lens::IndexLens) = lens
model_lens(::Union{AbstractMillModel, NamedTuple, Tuple}, lens::IdentityLens) = lens

"""
    data_lens(n, l)

Convert `Setfield.Lens` `l` for a model node to a new lens for accessing the same location in data node `n`.

# Examples
```jldoctest
julia> n = ProductNode((BagNode(ArrayNode(randn(2, 2)), bags([0:-1, 0:-1])), ArrayNode([1 2; 3 4])))
ProductNode with 2 obs
  ├── BagNode with 2 obs
  │     └── ArrayNode(2×2 Array with Float64 elements) with 2 obs
  └── ArrayNode(2×2 Array with Int64 elements) with 2 obs

julia> m = reflectinmodel(n)
ProductModel … ↦ ArrayModel(Dense(20, 10))
  ├── BagModel … ↦ ⟨SegmentedMean(10), SegmentedMax(10)⟩ ↦ ArrayModel(Dense(21, 10))
  │     └── ArrayModel(Dense(2, 10))
  └── ArrayModel(Dense(2, 10))

julia> data_lens(n, (@lens _.ms[2]))
(@lens _.data[2])
```

See also: [`data_lens`](@ref).
"""
function data_lens(ds, lens::ComposedLens)
    outerlens = data_lens(ds, lens.outer)
    outerlens ∘ data_lens(get(ds, outerlens), lens.inner)
end
data_lens(::ArrayNode, ::PropertyLens{:m}) = @lens _.data
data_lens(::AbstractBagNode, ::PropertyLens{:im}) = @lens _.data
data_lens(::AbstractProductNode, ::PropertyLens{:ms}) = @lens _.data
data_lens(::Union{NamedTuple, Tuple}, lens::IndexLens) = lens
data_lens(::Union{AbstractNode, NamedTuple, Tuple}, lens::IdentityLens) = lens

"""
    replacein(n, old, new)

Replace in data node or model `n` each occurence of `old` by `new`.

Short description

# Examples
```jldoctest
julia> n = ProductNode((BagNode(ArrayNode(randn(2, 2)), bags([0:-1, 0:-1])), ArrayNode([1 2; 3 4])))
ProductNode with 2 obs
  ├── BagNode with 2 obs
  │     └── ArrayNode(2×2 Array with Float64 elements) with 2 obs
  └── ArrayNode(2×2 Array with Int64 elements) with 2 obs

julia> replacein(n, n.data[1], ArrayNode(maybehotbatch([1, 2], 1:2)))
ProductNode with 2 obs
  ├── ArrayNode(2×2 MaybeHotMatrix with Bool elements) with 2 obs
  └── ArrayNode(2×2 Array with Int64 elements) with 2 obs
```
"""
replacein(x, oldnode, newnode) = x
replacein(x::Tuple, oldnode, newnode) = tuple([replacein(m, oldnode, newnode) for m in x]...)
replacein(x::NamedTuple, oldnode, newnode) = (; [k => replacein(x[k], oldnode, newnode) for k in keys(x)]...)

function replacein(x::T, oldnode, newnode) where T <: MillStruct
    x === oldnode && return(newnode)
    fields = map(f -> replacein(getproperty(x, f), oldnode, newnode), fieldnames(T))
    n = nameof(T)
    p = parentmodule(T)
    eval(:($p.$n))(fields...)
end

function replacein(x::LazyNode{N}, oldnode, newnode) where {N}
    x === oldnode && return newnode
    LazyNode{N}(replacein(x.data, oldnode, newnode))
end

function replacein(x::LazyModel{N}, oldnode, newnode) where {N}
    x === oldnode && return newnode
    LazyModel{N}(replacein(x.m, oldnode, newnode))
end
