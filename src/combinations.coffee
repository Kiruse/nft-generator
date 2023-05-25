{collect, first, isArraylike, isIterable} = require './utils'

module.exports = class Combinations
  constructor: (@config, @layers) ->
    @layerNodes = Array(@layers.length).fill().map => []
    @root = Tree.from this
    filterCombinationTree this
  pick: (n = 1) -> @root.pick() for [0...n]

class Tree
  constructor: (@combinations, @attr, @prev = new Set(), @next = {}) ->
  
  @from: (combinations) ->
    tree = new Tree combinations
    nodes = new Set [tree]
    for layer in combinations.layers
      for trait, attr of layer.attributes
        next = new Tree combinations, attr
        node.link next for node from nodes
      nodes = new Set(collect(nodes).flatMap (node) => Object.values node.next)
      combinations.layerNodes[layer.index] = collect(nodes) # first iteration is the root, so we only add after getting the next layer
    tree.weight # precompute & cache
    tree
  
  # pick a weighted random combination
  pick: ->
    picked = Math.random() * @weight
    layerCount = @combinations.layers.length
    path = Array(layerCount)
    node = this
    findNext = ->
      picked -= node.attr.weight if node.attr? # attr is undefined when finding next on root
      for _, next of node.next
        if picked <= next.weight
          return node = next
        picked -= next.weight
      console.error 'CRASH! picked:', picked, 'weight:', node.weight, 'next weights:', Object.values(node.next).reduce(((sum, next) => sum + next.weight), 0)
      throw Error 'should not reach'
    for layerIndex in [0...layerCount]
      node = findNext()
      path[layerIndex] = node
    @remove path
    path.map (node) => node.attr
  
  link: (other) ->
    if other.attr?
      @next[other.attr.name] = other
      other.prev.add this
    return this
  unlink: (other) ->
    if other.attr?
      delete @next[other.attr.name]
      other.prev.delete this
    return this
  relink: (first, second) ->
    @unlink first
    @link second
    return this
  
  remove: (path) ->
    path = collect path if not isArraylike(path) and isIterable(path)
    unless isArraylike path
      throw Error 'path must be an array'
    
    switch path.length
      when 0 then return this # nothing to remove
      when 1 # move the given node from all paths
        if @layer is -1
          @find(path[0]).removeSelf()
        else
          @remove [this, path[0]]
      else
        clones = new Map()
        nodes = @find path[0]
        _subclone = (search) =>
          for node from nodes
            for _, next of node.next
              node.relink next, next.subclone search, clones
        for i in [1...path.length-1]
          break if nodes.isEmpty()
          _subclone path[i]
          nodes = nodes.find path[i]
        return this if nodes.isEmpty()
        last = path[path.length-1]
        _subclone last
        nodes = nodes.findBefore last
        for node from nodes
          node.removeNext last
          node.removeSelf() if node.shouldRemove()
    @removeSelf() if @shouldRemove()
    return this
  removeTrait: (trait) ->
    nodes = @find trait
    return this if nodes.isEmpty()
    unless nodes.size is 1
      throw Error 'multiple traits with the same name found'
    @remove [first(nodes).attr]
  removeSelf: ->
    backpropagateWeightLoss this
    for node from @prev
      node.unlink(this)
      node.removeSelf() if node.shouldRemove()
    console.log 'root weight:', @combinations.root.weight
    return
  removeNext: (search) ->
    switch
      when typeof search is 'string'
        if next = @next[search]
          backpropagateWeightLoss this, next.weight
          @unlink next
      when search.name? then return @removeNext search.name
      else
        for _, next of @next
          if isMatchingNode next, search
            backpropagateWeightLoss this, next.weight
            @unlink next
            break
    return this
  
  # create a new subtree from this node until the given searched node. the new subtree will clone
  # every single node up until the given node, including their siblings, but not the given node itself.
  # if this subtree does not contain the node, do nothing
  subclone: (search, clones) ->
    return clones.get this if clones.has this
    return this unless @has search
    result = new Tree @combinations, @attr
    result._weight = @weight
    for _, next of @next
      unless clones.has next
        if next.has search
          clones.set next, next.subclone(search, clones)
        else
          clones.set next, next
      result.link clones.get next
    return result
  
  # attempt to find the unique subtrees for a given trait. returns a set
  find: (search) ->
    if isMatchingNode(this, search) or typeof search is 'string' and search is @attr?.name
      return Trees.wrap(this)
    switch
      when isArraylike search
        switch search.length
          when 0 then return new Trees @combinations
          when 1 then return @find search[0]
          else
            nodes = @find search[0]
            for i in [1...search.length-1]
              nodes = nodes.find search[i]
            nodes.find search[search.length-1]
      when search instanceof Trees
        @find collect search
      else
        nodes = @findBefore search
        nodes.flatMap (node) => collect(node.findNext(search))
          .filter Boolean
  findNext: (search) ->
    nodes = switch
      when typeof search is 'string'
        Trees.wrap @next[search], @combinations
      when search.name
        Trees.wrap @next[search.name], @combinations
      else
        Trees.wrap Object.values(@next).find((node) => isMatchingNode node, search), @combinations
    nodes.filter (node) => node?
  findBefore: (search) ->
    switch
      when typeof search is 'string'
        layer = getLayerOfTrait @combinations, search
        unless layer?
          return new Trees(@combinations, new Set())
        else
          return @findBefore layer.index
      when typeof search is 'number'
        return new Trees @combinations, @getNodesOfLayer(search-1)
      else
        nodes = switch
          when search.index? then @findBefore search.index
          when search.layer? then @findBefore search.layer.index
          when search.name?  then @findBefore search.name
          else throw Error 'unsupported search term'
        nodes.filter (node) => node.hasNext search
  prev: -> new Trees @combinations, @prev
  has: (trait) -> !!@find(trait).size
  hasNext: (search) -> !!@findNext(search).size
  isLast: -> @index is @combinations.layers.length-1
  isEmpty: -> Object.keys(@next).length is 0
  shouldRemove: -> @isEmpty() and @attr? and not @isLast()
  getNodesOfLayer: (index, visited = new Set(), target = new Set()) ->
    return target if visited.has this
    visited.add this
    
    if @index is index
      target.add this
    else if @index < index
      node.getNodesOfLayer index, visited, target for _, node of @next
    target
Object.defineProperty Tree::, 'layer', get: -> @attr?.layer
Object.defineProperty Tree::, 'index', get: -> @attr?.layer.index ? -1
Object.defineProperty Tree::, 'weight',
  get: ->
    unless @_weight?
      @_weight = @attr?.weight ? 0
      @_weight += node.weight for _, node of @next
    @_weight

class Trees
  constructor: (@combinations, @trees = new Set()) ->
  @wrap: (node, combinations) ->
    nodes = if node? then new Set([node]) else new Set()
    new Trees combinations ? node.combinations, nodes
  
  remove: (path) ->
    tree.remove path for tree from @trees
    return this
  removeTrait: (trait) ->
    tree.removeTrait trait for tree from @trees
    return this
  removeSelf: ->
    tree.removeSelf() for tree from @trees
    @trees = new Set()
    return this
  
  find:       (trait) -> new Trees @combinations, new Set(collect(@trees).flatMap (tree) => collect tree.find(trait))
  findBefore: (trait) -> new Trees @combinations, new Set(collect(@trees).flatMap (tree) => collect tree.findBefore(trait))
  prev: ->
    nodes = new Set()
    for tree from @trees
      nodes.add node for node from tree.prev
    new Trees @combinations, nodes
  next: ->
    nodes = new Set()
    for tree from @trees
      nodes.add node for _, node of tree.next
    new Trees @combinations, nodes
  has: (trait) -> !!@find(trait).size
  hasNext: (search) ->
    for tree from @trees
      return true if tree.hasNext search
    return false
  map: (fn) ->
    @trees = new Set collect(@trees).map fn
    this
  flatMap: (fn) ->
    @trees = new Set collect(@trees).flatMap fn
    this
  filter: (fn = (v) => !!v) ->
    @trees = new Set collect(@trees).filter fn
    this
  forEach: (fn) ->
    fn node for node from @trees
    this
  
  isEmpty: -> @size is 0
Trees::[Symbol.iterator] = -> @trees[Symbol.iterator]()
Object.defineProperty Trees::, 'size', get: -> @trees.size

filterCombinationTree = (combinations) ->
  restrict = combinations.config.restrict
  return unless restrict?
  for mutex in restrict.mutex ? []
    for trait in mutex
      subs = combinations.root.find trait.name
      continue unless subs.size
      subs.removeTrait other.name for other in mutex
  for forbid in restrict.forbid ? []
    combinations.root.remove forbid
  return

getLayerOfTrait = (combinations, trait) =>
  combinations.layers.find (layer) => layer.attributes[trait]?

isMatchingNode = (node, search) => (node is search) or (node.attr is search) or (search?.attr? and node.attr is search?.attr)

# run up the graph and subtract this node's weight from every ancestor node
backpropagateWeightLoss = (node, weight) =>
  weight ?= node.weight
  return unless weight
  # important: unlike most algorithms above which do actions only once per node, this algorithm HAS
  # to update the weight of every node for every connection, otherwise the weights will desync
  backpropagate = (node) =>
    node._weight -= weight
    backpropagate prev for prev from node.prev
  backpropagate node
  return

# useful for debugging
Combinations.displayTraits = displayTraits = (trees) -> collect(trees).map((tree) => tree.attr?.name ? '<root>').join(', ')
