# TODO inferred tests

@testset "attributes" begin
    l = 10
    I = [1, missing, 3, missing, 5]

    for i in I
        mhv = MaybeHotVector(i, l)
        @test size(mhv) == (l,)
        @test length(mhv) == l
    end

    mhm = MaybeHotMatrix(I, l)
    @test size(mhm) == (l, length(I))
    @test length(mhm) == l * length(I)
end

@testset "type construction" begin
    @test MaybeHotVector(1, 10) isa AbstractVector{Bool}
    @test MaybeHotVector(missing, 10) isa AbstractVector{Missing}
    @test MaybeHotMatrix([1, 2], 10) isa AbstractMatrix{Bool}
    @test MaybeHotMatrix([missing, missing], 10) isa AbstractMatrix{Missing}
    @test MaybeHotMatrix([1, missing], 10) isa AbstractMatrix{Union{Bool, Missing}}
end

@testset "hcat" begin
    l = 10
    I = [1, missing, 3, missing, 5]
    mhm = MaybeHotMatrix(I, l)
    mhvs = MaybeHotVector.(I, l)

    @test all(mhv -> isequal(hcat(mhv), mhv), mhvs)
    @test all(mhv -> isequal(reduce(hcat, [mhv]), MaybeHotMatrix(mhv)), mhvs)
    @test all(mhv -> isequal(reduce(catobs, [mhv]), MaybeHotMatrix(mhv)), mhvs)

    @test isequal(hcat(mhm), mhm)
    @test isequal(reduce(hcat, [mhm]), mhm)
    @test isequal(reduce(catobs, [mhm]), mhm)

    @test isequal(hcat(mhvs...), mhm)
    @test isequal(reduce(hcat, mhvs), mhm)
    @test isequal(reduce(catobs, mhvs), mhm)

    @test_throws DimensionMismatch hcat(MaybeHotVector.([1, 2], [l, l+1])...)
    @test_throws DimensionMismatch hcat(MaybeHotMatrix.([[1], [2, 3]], [l, l+1])...)
    @test_throws DimensionMismatch catobs(MaybeHotVector.([1, 2], [l, l+1])...)
    @test_throws DimensionMismatch catobs(MaybeHotMatrix.([[1], [2, 3]], [l, l+1])...)

    @test_throws ArgumentError reduce(hcat, MaybeHotVector[])
    @test_throws ArgumentError reduce(hcat, MaybeHotMatrix[])
end

@testset "indexing" begin
    l = 10
    I = [1, missing, 3, missing, 5]

    for i in I
        mhv = MaybeHotVector(i, l)
        if ismissing(i)
            @test all(isequal.(missing, mhv))
        else
            @test Vector(mhv) == onehot(i, 1:l)
        end
        @test_throws BoundsError mhv[0]
        @test_throws BoundsError mhv[l+1]
        @test all(isequal.(mhv[:], mhv))
    end

    mhm = MaybeHotMatrix(I, l)
    m = Matrix(mhm)
    for (k,i) in I |> enumerate
        if ismissing(i)
            @test all(isequal.(missing, m[:, k]))
            @test all(isequal.(missing, mhm[:, k]))
        else
            @test mhm[:, k] == m[:, k] == onehot(i, 1:l)
        end
    end
    @test isequal(mhm[[1,2,7], 3], m[[1,2,7], 3])
    @test isequal(mhm[CartesianIndex(2, 4)], m[2,4])
    for k in eachindex(I)
        @test isequal(mhm[:, k], MaybeHotVector(I[k], l))
    end
    @test isequal(mhm, mhm[:, eachindex(I)])
    @test isequal(mhm, mhm[:, eachindex(I) |> collect])
    @test isequal(mhm, mhm[:, :])
    @test isequal(mhm, hcat(MaybeHotVector.(I, l)...))
    @test isequal(mhm[:, [1,2,5]], hcat(MaybeHotVector.(I[[1,2,5]], l)...))

    @test_throws BoundsError mhm[0, 1]
    @test_throws BoundsError mhm[2, -1]
    @test_throws BoundsError mhm[CartesianIndex()]
    @test_throws BoundsError mhm[CartesianIndex(1)]
end

@testset "multiplication" begin
    W = rand(10, 10)
    x1 = MaybeHotVector(1, 10)
    x2 = MaybeHotVector(8, 10)
    x3 = MaybeHotVector(missing, 10)
    X1 = MaybeHotMatrix([7, 10], 10)
    X2 = MaybeHotMatrix([missing, missing], 10)
    X3 = MaybeHotMatrix([3, missing, 1, missing], 10)

    @test isequal(W * x1, W * Vector(x1))
    @test isequal(W * x2, W * Vector(x2))
    @test isequal(W * x3, W * Vector(x3))
    @test isequal(W * X1, W * Matrix(X1))
    @test isequal(W * X2, W * Matrix(X2))
    @test isequal(W * X3, W * Matrix(X3))

    @test_throws DimensionMismatch W * MaybeHotVector(1, 5)
    @test_throws DimensionMismatch W * MaybeHotVector(missing, 3)
    @test_throws DimensionMismatch W * MaybeHotMatrix([1, 2], 9)
    @test_throws DimensionMismatch W * MaybeHotMatrix([1, missing, 2], 9)
    @test_throws DimensionMismatch W * MaybeHotMatrix([missing, missing], 9)
end

@testset "equality" begin
    mhv1 = MaybeHotVector(1, 10)
    mhv2 = MaybeHotVector(1, 10)
    mhv3 = MaybeHotVector(1, 11)
    mhv4 = MaybeHotVector(missing, 11)
    mhv5 = MaybeHotVector(2, 10)
    @test mhv1 == mhv2
    @test mhv1 != mhv3
    @test mhv1 != mhv4
    @test mhv1 != mhv5

    mhm1 = MaybeHotMatrix([1,2], 10)
    mhm2 = MaybeHotMatrix([1,2], 10)
    mhm3 = MaybeHotMatrix([1], 10)
    mhm4 = MaybeHotMatrix([missing], 10)
    mhm5 = MaybeHotMatrix([1,2], 11)
    @test mhm1 == mhm2
    @test mhm1 != mhm3
    @test mhm1 != mhm4
    @test mhm1 != mhm5
end

@testset "onehot and onehotbatch" begin
    i = 1
    b = MaybeHotVector(i, 10)
    @test onehot(b) == onehot(i, 1:length(b))
    b = MaybeHotVector(missing, 10)
    @test_throws MethodError onehot(b)
    I = [3, 1, 2]
    B = MaybeHotMatrix(I, 10)
    @test onehotbatch(B) == onehotbatch(I, 1:size(B, 1))
    B = MaybeHotMatrix([3, missing, 2], 10)
    @test_throws MethodError onehotbatch(B)
end

@testset "AbstractMatrix * MaybeHotVector{<:Integer} gradtest" begin
    # for MaybeHot types with missing elements, it doesn't make sense to compute gradient
    for (m, n) in product(fill((1, 5, 10, 20), 2)...), i in [rand(1:n) for _ in 1:3]
        A = randn(m, n)
        b = MaybeHotVector(i, n)

        dA, db = gradient(sum ∘ *, A, b)
        @test dA ≈ gradient(A -> sum(A * b), A) |> only
        @test dA ≈ gradient(A -> sum(A * onehot(b)), A) |> only
        @test gradtest(A -> sum(A * b), A)

        @test db === gradient(b -> sum(A * b), b) |> only
        @test isnothing(db)
    end
end

@testset "AbstractMatrix * MaybeHotMatrix{<:Integer} gradtest" begin
    # for MaybeHot types with missing elements, it doesn't make sense to compute gradient
    for (m, n, k) in product(fill((1, 5, 10, 20), 3)...), I in [rand(1:n, k) for _ in 1:3]
        A = randn(m, n)
        B = MaybeHotMatrix(I, n)

        dA, dB = gradient(sum ∘ *, A, B)
        @test dA ≈ gradient(A -> sum(A * B), A) |> only
        @test dA ≈ gradient(A -> sum(A * onehotbatch(B)), A) |> only
        @test gradtest(A -> sum(A * B), A)

        @test dB === gradient(B -> sum(A * B), B) |> only
        @test isnothing(dB)
    end
end