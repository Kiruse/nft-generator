{render} = require './image-generator'
{clone, enumerate, getCombinationWeight, repeat, shuffle} = require './utils'

# Abstraction of an NFT collection
module.exports = class Collection
  constructor: (@config, @combos) -> @reset()
  reset: ->
    @mint = @config.collectionSize
    @limits = clone @config.restrict?.limit ? {}
    @collection = []
    @part1 = @combos.slice()
    @cidImages = undefined
    @cidMetas  = undefined
    return this
  
  # split this set of combinations into two sets based on a trait
  # both partitions are cleaned when limits are reached
  partition: (trait) ->
    original = @part1
    @part1 = []
    @part2 = []
    for combo in original
      if combo.some (attr) => attr.name is trait
        @part1.push combo
      else
        @part2.push combo
    [@part1, @part2]
  # re-join partitions back together
  joinPartition: ->
    @part1 = [@part1..., @part2...]
    delete @part2
    return this
  # drop the first partition, taking only the second
  dropPartition: ->
    @part1 = @part2
    delete @part2
    return this
  
  filter: (pred) ->
    @part1 = @part1.filter pred
    @part2 = @part2.filter pred if @part2?
    return this
  filterValid: -> @filter (combo) => @isValid combo
  isValid: (combo) ->
    countOccurrences = (combo, traits) => traits.filter((trait) => combo.some (attr) => attr.name is trait).length
    
    # mutex means at most one named trait may appear per combination
    if @config.restrict?.mutex?.length
      return false if @config.restrict.mutex.some (forbidden) => countOccurrences(combo, forbidden) > 1
    
    # forbid means all named traits must not appear in the same combination together, but less are allowed
    if @config.restrict?.forbid?.length
      return false if @config.restrict.forbid.some (forbidden) => countOccurrences(combo, forbidden) is forbidden.length
    
    return true
  
  # pick a single combination from the pool based on weighted probability
  # side effects inside!
  pickSingle: ->
    if @part1.length is 0
      throw Error 'not enough combinations to pick from'
    idx = @getWeightedRandomIndex()
    [combo] = @part1.splice idx, 1
    @collection.push combo
    @mint--
    @reduceLimits attr.name for attr in combo
    combo
  
  # pick a selection of combinations from the pool until all `exact` limits have been reached
  # excess combinations ARE discarded
  pickExact: ->
    for trait of @limits
      unless @limits[trait].exact
        continue
      @partition trait
      @collection = [
        @collection...
        repeat(@limits[trait].exact, => @pickSingle())...
      ]
      @dropPartition()
  # pick a selection of combinations from the pool until all `min` limits have been reached
  # excess combinations are NOT discarded
  pickMin: ->
    for trait of @limits
      unless @limits[trait].min
        continue
      @partition trait
      @collection = [
        @collection...
        repeat(@limits[trait].min, => @pickSingle())...
      ]
      @joinPartition()
  
  pick: ->
    if @mint > @combos.length
      throw Error "not enough possible combinations (#{@combos.length} < #{@mint})"
    @pickExact()
    @pickMin()
    @pickSingle() while @mint > 0
    return this
  
  shuffle: ->
    shuffle @collection
    return this
  
  generateImages: (onUpdate) ->
    await Promise.all @collection.map (combo, tokenId) =>
      tokenId++
      filepath = await render @config, tokenId, combo
      onUpdate tokenId, combo
  generateMetadata: (collection, onUpdate) ->
    for [tokenId, combo] from enumerate collection
      tokenId++
      filename = @config.filenameTemplate.replace('{}', tokenId) + '.json'
      metadata =
        name: @config.nameTemplate.replace '{}', tokenId
        description: @config.descTemplate.replace '{}', tokenId if @config.descTemplate?
  
  # get a randomized index by weighted probability
  getWeightedRandomIndex: ->
    total = @getTotalCombinationsWeight @part1
    random = Math.floor Math.random() * total
    
    virtualIndex = 0
    for [i, combo] from enumerate @part1
      weight = getCombinationWeight combo
      if random < virtualIndex + weight
        return i
      virtualIndex += weight
    throw Error 'should not happen'
  getTotalCombinationsWeight: ->
    total = 0
    total += getCombinationWeight combo for combo in @part1
    total
  
  reduceLimits: (trait) ->
    unless @limits[trait]
      return this
    
    if @limits[trait].min
      @limits[trait].min--
      unless @limits[trait].min
        delete @limits[trait].min
    if @limits[trait].max
      @limits[trait].max--
      unless @limits[trait].max
        delete @limits[trait].max
        @removeTrait trait
    if @limits[trait].exact
      @limits[trait].exact--
      unless @limits[trait].exact
        delete @limits[trait].exact
        @removeTrait trait
    
    return this
  removeTrait: (trait) ->
    filter = (combo) => combo.every (attr) => attr.name isnt trait
    @part1 = @part1.filter filter
    @part2 = @part2.filter filter
    return this
