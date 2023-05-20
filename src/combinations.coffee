{clone, enumerate, shuffle, sleep} = require './utils'

module.exports = class Combinations
  constructor: (@config, layers) ->
    @layers = layers.map (layer) =>
      Object.assign {}, layer,
        attributes: Object.assign {}, layer.attributes
    @limits = clone  @config.restrict?.limit ? {}
    @forbid = clone (@config.restrict?.forbid ? []).slice()
    @mutex  = clone  @config.restrict?.mutex ? []
    # minted is a special variant of `forbid` with a fixed length and order matching the layers
    @minted = []
  
  pick: (n, onUpdate) ->
    combos = Array(n)
    for i in [0...n]
      combos[i] = @pickSingle()
      onUpdate i, combos[i] if onUpdate?
      await sleep 0 # give CLI time to update/rerender
    combos
  pickSingle: ->
    for trait, limits of @limits
      if limits.exact
        return @pickTrait trait
      if limits.min
        return @pickTrait trait
    return @pickWeighted()
  pickTrait: (trait) ->
    if @isTraitCapped trait
      throw Error "no more #{trait} traits available"
    
    combo = Array(@layers.length).fill()
    combo[@getLayerIndex @getLayerByTrait trait] = @getAttribute trait
    combo = @_pickWeighted combo
    
    @reduceLimits combo
    @addMinted combo
    combo
  pickWeighted: ->
    combo = @_pickWeighted Array(@layers.length).fill()
    @reduceLimits combo
    @addMinted combo
    combo
  
  _pickWeighted: (_combo) ->
    retries = 100
    order = _combo.map((v, i) => unless v? then i).filter((v) => v?)
    for round1 in [0...retries]
      @enableTraits()
      shuffle order
      combo = _combo.slice()
      random = Math.random()
      try
        for [round2, i] from enumerate order
          layer = @layers[i]
          @disableForbid combo
          @disableMutex combo
          @disableMinted combo, i if round2 is order.length-1
          combo[i] = @getWeightedTrait layer, random
        return combo
      catch err
        if round1 < retries-1 and err.message isnt 'no more active traits'
          throw err
    throw Error 'failed to pick traits'
  
  getWeightedTrait: (layer, random) ->
    totalWeights = @getActiveWeights layer
    if totalWeights is 0
      throw Error 'no more active traits'
    pick = random * totalWeights
    for trait, attr of layer.attributes
      continue unless attr.enabled
      pick -= attr.weight
      return attr if pick <= 0
    throw Error 'should not reach'
  getActiveWeights: (layer) ->
    attrs = layer.attributes
    weight = 0
    weight += attr.weight for trait, attr of attrs when attr.enabled
    weight
  getLayerByTrait: (trait) -> @layers.find (layer) => trait of layer.attributes
  getLayerIndex: (layer) ->
    index = @layers.indexOf layer
    return index if index > -1
    index = @layers.findIndex (l) => l.name is layer.name
    return index if index > -1
    throw Error "layer not found"
  getAttribute: (trait) ->
    layer = @getLayerByTrait trait
    layer.attributes[trait]
  isTraitCapped: (trait) ->
    return false unless @limits[trait]?
    limits = @limits[trait]
    return true if limits.exact is 0
    return true if limits.max   is 0
    return false
  
  enableTraits: ->
    for layer in @layers
      for trait, attr of layer.attributes
        attr.enabled = not @isTraitCapped trait
    return this
  disableTrait: (trait) ->
    @getAttribute(trait).enabled = false
    return this
  # given `combo`, strip all forbidden traits from the other layers (indicated by `unknown` traits in `combo`)
  disableForbid: (combo) ->
    for forbidden from @getMatchingForbid combo
      @disableTrait trait for trait in forbidden
    return this
  disableMutex: (combo) ->
    for mutex from @getMatchingMutex combo
      @disableTrait trait for trait in mutex
    return this
  disableMinted: (combo, layerIndex) ->
    if count(combo, (attr) => attr?) isnt @layers.length-1
      throw Error 'should not reach'
    for minted in @minted
      if combo.every (attr, i) => i is layerIndex or attr is minted[i]
        @disableTrait minted[layerIndex].name
    return this
  getMatchingForbid: (combo) ->
    for forbidden in @forbid
      if count(combo, (attr) => attr?) is forbidden.length-1
        yield forbidden if combo.every (attr) => not attr? or attr in forbidden
  getMatchingMutex: (combo) ->
    for mutex in @mutex
      yield mutex if mutex.some (attr) => attr in combo
  addMinted: (combo) ->
    @minted.push combo
    return this
  
  reduceLimits: (combo) ->
    for attr in combo
      continue unless @limits[attr.name]?
      limits = @limits[attr.name]
      limits.exact-- if limits.exact
      limits.min--   if limits.min
      limits.max--   if limits.max
    return

count = (array, pred) =>
  result = 0
  result++ for item in array when pred item
  result
