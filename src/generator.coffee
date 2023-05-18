CSV = require 'csv-stringify/sync'
fs = require 'node:fs/promises'
hash = require 'object-hash'
path = require 'node:path'
{createCanvas, loadImage} = require 'canvas'

module.exports = class Generator
  constructor: (@config) ->
    [width, height] = @config.imageSize
    @canvas = createCanvas width, height
    @layers = []
  
  init: ->
    @layers = await @readLayers()
    return this
  readLayers: ->
    # structure is layers/<layer name>/<attribute>#<rarity>.<extension>
    files = await fs.readdir @config.in, {withFileTypes: true}
    files = files.filter (entry) => entry.isDirectory()
      .map (entry) => entry.name
    
    layers = await Promise.all files.map (file, i) => @readLayer @config.in, file, i
    layers.sort (a, b) => a.index - b.index
  readLayer: (dir, layername, index) ->
    name = cleanLayerName layername
    zIndex = extractZIndex layername
    zIndex = index if isNaN zIndex
    
    layer =
      name: name
      path: path.join dir, layername
      index: zIndex
      attributes: {}
      totalWeights: 0
      position: @config.layout[name]?.position ? [0, 0]
      size: @config.layout[name]?.size ? @config.imageSize
    
    attrs = await fs.readdir path.join(dir, layer.name), {withFileTypes: true}
    attrs = attrs.filter (entry) => entry.isFile()
      .filter (entry) => entry.name.match(/\.(jpe?g|png)$/)?
      .map (entry) => entry.name
      .forEach (attr) => @readAttribute layer, attr
    layer
  readAttribute: (layer, attrname) ->
    name = cleanAttributeName attrname
    weight = extractWeight attrname
    weight = 1 if isNaN weight
    
    filepath = path.join layer.path, attrname
    attr =
      name: name
      weight: weight
      path: filepath
      image: await loadImage filepath
    layer.attributes[name] = attr
    layer.totalWeights += weight
    attr
  
  flush: ->
    bytes = @canvas.toBuffer 'image/png'
    [w, h] = @config.imageSize
    ctx = @canvas.getContext '2d'
    ctx.clearRect 0, 0, w, h
    bytes
  drawLayer: (layer, attribute) ->
    ctx = @canvas.getContext '2d'
    ctx.drawImage attribute.image, layer.position..., layer.size...
  
  # Generate all possible combinations of traits/attributes per layers
  generateCombinations: ->
    generate = (layers) ->
      [first] = layers
      sublayers = layers.slice 1
      
      if sublayers.length is 0
        yield [attr] for attr in Object.values first.attributes
      else
        subcombos = [generate(sublayers)...]
        for attr in Object.values first.attributes
          yield [attr, subcombo...] for subcombo in subcombos
    [generate(@layers)...]
  generateImages: (combos) ->
    # TODO
    throw Error 'not yet implemented'
  generateMetadata: (combos) ->
    # TODO
    throw Error 'not yet implemented'
  generateCSV: (combos) ->
    data = combos.map (combo, tokenId) => [
      tokenId + 1
      combo.map((attr) => attr.name)...
      @getCombinationWeight combo
    ]
    CSV.stringify [
      ['tokenId', ...@layers.map((layer) => layer.name), 'weight']
      data...
    ]
  
  getCombinationWeight: (combo) ->
    total = 0
    total += attr.weight for attr in combo
    total
  getTotalCombinationsWeight: (combos) ->
    total = 0
    total += @getCombinationWeight combo for combo in combos
    total
  
  # generate randomized collection by the configured settings
  # only generates the combinations, not the actual images & metadata
  generateCollection: ->
    combos = @generateCombinations().filter (combo) => @isValidCombination combo
    if combos.length < @config.collectionSize
      throw Error 'not enough combinations to generate collection'
    limits = clone @config.restrict.limit
    collection = []
    
    toMint = @config.collectionSize
    getRandom = (combos) =>
      idx = @getWeightedRandomIndex combos
      [combo] = combos.splice idx, 1
      combo
    partition = (trait) => [
        combos.filter (combo) => combo.some (attr) => attr.name is trait
        combos.filter (combo) => combo.every (attr) => attr.name isnt trait
      ]
    
    for trait of limits
      if limits[trait].exact?
        [subcombo, combos] = partition trait
        collection = [
          collection...
          repeat(limits[trait].exact, => getRandom(subcombo))...
        ]
        toMint -= limits[trait].exact
      else if limits[trait].min
        [subcombo, remain] = partition trait
        if subcombo.length < limits[trait].min
          throw Error "not enough combinations with trait #{trait} to generate collection"
        
        collection = [
          collection...
          repeat(limits[trait].min, => getRandom(subcombo))...
        ]
        
        # getRandom removes the selected combos from the pool, so we add the remaining subcombos back in
        combos = [subcombo..., remain...]
        toMint -= limits[trait].min
    
    for i in [0...toMint]
      collection.push combo = getRandom combos
      # console.log limits
      for attr in combo
        if limits[attr.name]?.max?
          remain = --limits[attr.name].max
          if remain is 0
            combos = @removeTrait combos, attr.name
            if combos.length < toMint - i
              throw Error "not enough combinations with trait #{attr.name} to generate collection"
    shuffle collection
  
  # remove all combinations with a specific trait
  removeTrait: (combos, trait) -> combos.filter (combo) => combo.every (attr) => attr.name isnt trait
  
  # get a randomized index by weighted probability
  getWeightedRandomIndex: (combos) ->
    total = @getTotalCombinationsWeight combos
    random = Math.floor Math.random() * total
    
    virtualIndex = 0
    for [i, combo] from enumerate combos
      weight = @getCombinationWeight combo
      if random < virtualIndex + weight
        return i
      virtualIndex += weight
    throw Error 'should not happen'
  
  # check if combination is valid based on config's restrictions
  isValidCombination: (combo) ->
    countOccurrences = (combo, traits) => traits.filter((trait) => combo.some (attr) => attr.name is trait).length
    
    # mutex means at most one named trait may appear per combination
    if @config.restrict?.mutex?.length
      return false if @config.restrict.mutex.some (forbidden) => countOccurrences(combo, forbidden) > 1
    
    # forbid means all named traits must not appear in the same combination together, but less are allowed
    if @config.restrict?.forbid?.length
      return false if @config.restrict.forbid.some (forbidden) => countOccurrences(combo, forbidden) is forbidden.length
    
    return true


extractWeight = (filename) ->
  [, weight] = filename.match(/#(\d+)\.(jpe?g|png)$/) ? []
  parseInt weight
extractZIndex = (dirname) ->
  [, index] = dirname.match(/^(\d+)\./) ? []
  parseInt index

cleanAttributeName = (filename) -> filename.replace(/#\d+\.(jpe?g|png)$|\.(jpe?g|png)$/, '')
cleanLayerName = (dirname) -> dirname.replace(/^\d+\./, '')

clone = (obj) => JSON.parse JSON.stringify obj
enumerate = (iterable) ->
  i = 0
  yield [i++, value] for value in iterable
repeat = (n, x) =>
  if typeof x is 'function'
    Array(n).fill(0).map (, i) => x(i)
  else
    Array(n).fill(x)
shuffle = (array) => # shuffle array in-place
  unless Array.isArray array
    throw Error 'not an array'
  for i in [0...array.length]
    j = Math.floor Math.random() * array.length
    [array[i], array[j]] = [array[j], array[i]]
  array
