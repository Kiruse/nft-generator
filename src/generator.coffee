CSV = require 'csv-stringify/sync'
fs = require 'node:fs/promises'
path = require 'node:path'
Collection = require './collection'
{getCombinationWeight} = require './utils'

module.exports = class Generator
  constructor: (@config) ->
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
    await Promise.all attrs.map (attr) => @readAttribute layer, attr
    layer
  readAttribute: (layer, attrname) ->
    name = cleanAttributeName attrname
    weight = extractWeight attrname
    weight = 1 if isNaN weight
    
    filepath = path.join layer.path, attrname
    attr =
      name: name
      layer: layer
      weight: weight
      path: filepath
      image: await fs.readFile filepath
    layer.attributes[name] = attr
    layer.totalWeights += weight
    attr
  
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
  generateCSV: (collection) ->
    data = collection.map (combo, tokenId) => [
      tokenId + 1
      combo.map((attr) => attr.name)...
      getCombinationWeight combo
    ]
    CSV.stringify [
      ['tokenId', ...@layers.map((layer) => layer.name), 'weight']
      data...
    ]
  # generate randomized collection by the configured settings
  # only generates the combinations, not the actual images & metadata
  generateCollection: -> new Collection(@config, @generateCombinations()).filterValid().pick().shuffle()

extractWeight = (filename) ->
  [, weight] = filename.match(/#(\d+)\.(jpe?g|png)$/) ? []
  parseInt weight
extractZIndex = (dirname) ->
  [, index] = dirname.match(/^(\d+)[.-]/) ? []
  parseInt index

cleanAttributeName = (filename) -> filename.replace(/#\d+\.(jpe?g|png)$|\.(jpe?g|png)$/, '')
cleanLayerName = (dirname) -> dirname.replace(/^\d+[.-]/, '')
