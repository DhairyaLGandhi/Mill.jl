# Data nodes

## Index
```@index
Pages = ["data_nodes.md"]
```

## API
```@docs
AbstractNode
AbstractProductNode
AbstractBagNode

Mill.data
Mill.metadata
catobs
Mill.subset
Mill.mapdata
removeinstances

ArrayNode
ArrayNode(::AbstractArray)

BagNode
BagNode(::AbstractNode, ::AbstractVector, m)

WeightedBagNode
WeightedBagNode(::AbstractNode, ::AbstractVector, ::Vector, m)

ProductNode
ProductNode(::Any)

LazyNode
LazyNode(::Symbol, ::Any)

Mill.unpack2mill
```

