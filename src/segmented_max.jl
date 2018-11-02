function _segmented_max(x::Matrix, bags::Bags)
    o = similar(x, size(x,1), length(bags))
    fill!(o, typemin(eltype(x)))
    for (j,b) in enumerate(bags)
        for bi in b
            for i in 1:size(x, 1)
                o[i, j] = max(o[i, j], x[i, bi])
            end
        end
    end
    o[o.== typemin(eltype(x))] .= 0
    o
end

_segmented_max(x::Matrix, bags::Bags, w::Vector) = _segmented_max(x, bags)

function _segmented_max_back(Δ, x::TrackedMatrix, bags::Bags)
    x = Flux.data(x)
    Δ = Flux.data(Δ)
    dx = zero(x)
    v = similar(x, size(x,1))
    idxs = zeros(Int, size(x,1))
    @inbounds for (j,b) in enumerate(bags)
        fill!(v, typemin(eltype(x)))
        for bi in b
            for i in 1:size(x, 1)
                if v[i] < x[i, bi]
                    idxs[i] = bi
                    v[i] = x[i, bi]
                end
            end
        end

        for i in 1:size(x, 1)
            dx[i, idxs[i]] = Δ[i, j]
        end
    end
    dx, nothing
end

_segmented_max_back(Δ, x::TrackedMatrix, bags::Bags, w::Vector) = tuple(_segmented_max_back(Δ, x, bags)..., nothing)
