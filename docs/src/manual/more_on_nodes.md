```@setup more_on_nodes 
using Mill
```

# More on nodes

## Node nesting 
The main advantage of the Mill library is that it allows to arbitrarily nest and cross-product [`BagModel`](@ref)s, as described in Theorem 5 in [Pevny2019](@cite). In other words, instances themselves may be represented in much more complex way than in the [`BagNode`](@ref) and [`BagModel`](@ref) example.

Let's start the demonstration by nesting two MIL problems. The outer MIL model contains three samples (outer-level bags), whose instances are (inner-level) bags themselves. The first outer-level bag contains one inner-level bag problem with two inner-level instances, the second outer-level bag contains two inner-level bags with total of three inner-level instances, and finally the third outer-level bag contains two inner bags with four instances:

```@repl more_on_nodes
ds = BagNode(BagNode(ArrayNode(randn(4, 10)),
                     [1:2, 3:4, 5:5, 6:7, 8:10]),
             [1:1, 2:3, 4:5])
```

Here is one example of a model, which is appropriate for this hierarchy:

```@repl more_on_nodes
using Flux: Dense, Chain, relu
m = BagModel(
        BagModel(
            ArrayModel(Dense(4, 3, relu)),   
            meanmax_aggregation(3),
            ArrayModel(Dense(7, 3, relu))),
        meanmax_aggregation(3),
        ArrayModel(Chain(Dense(7, 3, relu), Dense(3, 2))))
```

and can be directly applied to obtain a result:

```@repl more_on_nodes
m(ds)
```

Here we again make use of the property that even if each instance is represented with an arbitrarily complex structure, we always obtain a vector representation after applying instance model `im`, regardless of the complexity of `im` and `Mill.data(ds)`:

```@repl more_on_nodes
m.im(Mill.data(ds))
```

In one final example we demonstrate a complex model consisting of all types of nodes introduced so far:

```@repl more_on_nodes
ds = BagNode(ProductNode((BagNode(ArrayNode(randn(4, 10)),
                                  [1:2, 3:4, 5:5, 6:7, 8:10]),
                          ArrayNode(randn(3, 5)),
                          BagNode(BagNode(ArrayNode(randn(2, 30)),
                                          [i:i+1 for i in 1:2:30]),
                                  [1:3, 4:6, 7:9, 10:12, 13:15]),
                          ArrayNode(randn(2, 5)))),
             [1:1, 2:3, 4:5])
```

Instead of defining a model manually, we make use of [Model Reflection](@ref), another [`Mill.jl`](https://github.com/pevnak/Mill.jl) functionality, which simplifies model creation:

```@repl more_on_nodes
m = reflectinmodel(ds)
m(ds)
```

## Node conveniences

To make the handling of data and model hierarchies easier, [`Mill.jl`](https://github.com/pevnak/Mill.jl) provides several tools. Let's setup some data:

```@repl more_on_nodes
AN = ArrayNode(Float32.([1 2 3 4; 5 6 7 8]))
AM = reflectinmodel(AN)
BN = BagNode(AN, [1:1, 2:3, 4:4])
BM = reflectinmodel(BN)
PN = ProductNode((a=ArrayNode(Float32.([1 2 3; 4 5 6])), b=BN))
PM = reflectinmodel(PN)
```

### Function: `nobs`

`nobs` function from [`StatsBase.jl`](https://github.com/JuliaStats/StatsBase.jl) returns a number of samples from the current level point of view. This number usually increases as we go down the tree when [`BagNode`](@ref)s are involved, as each bag may contain more than one instance.

```@repl more_on_nodes
using StatsBase: nobs
nobs(AN)
nobs(BN)
nobs(PN)
```

### Indexing and Slicing

Indexing in [`Mill.jl`](https://github.com/pevnak/Mill.jl) operates **on the level of observations**:

```@repl more_on_nodes
AN[1]
nobs(ans)
BN[2]
nobs(ans)
PN[3]
nobs(ans)
AN[[1, 4]]
nobs(ans)
BN[1:2]
nobs(ans)
PN[[2, 3]]
nobs(ans)
PN[Int[]]
nobs(ans)
```

This may be useful for creating minibatches and their permutations.

Note that apart from the perhaps apparent recurrent effect, this operation requires other implicit actions, such as properly recomputing bag indices:

```@repl more_on_nodes
BN.bags
BN[[1, 3]].bags
```

### Function: [`catobs`](@ref)

[`catobs`](@ref) function concatenates several datasets (trees) together:

```@repl more_on_nodes
catobs(AN[1], AN[4])
catobs(BN[3], BN[[2, 1]])
catobs(PN[[1, 2]], PN[3:3]) == PN
```

Again, the effect is recurrent and everything is appropriately recomputed:

```@repl more_on_nodes
BN.bags
catobs(BN[3], BN[[1]]).bags
```

!!! ukn "More tips"
    For more tips for handling datasets and models, see [External tools](@ref HierarchicalUtils.jl).
