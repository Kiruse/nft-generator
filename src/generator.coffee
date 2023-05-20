fs = require 'node:fs/promises'
path = require 'node:path'
Collection = require './collection'
Combinations = require './combinations'
{enumerate} = require './utils'

module.exports = class Generator
  constructor: (@config) ->
    @layers = []
  
  init: ->
    @layers = await @readLayers()
    @normalizeRestrict()
    return this
  readLayers: ->
    # structure is layers/<layer name>/<attribute>#<rarity>.<extension>
    files = await fs.readdir @config.in, {withFileTypes: true}
    files = files.filter (entry) => entry.isDirectory()
      .map (entry) => entry.name
    
    layers = await Promise.all files.map (file, i) => @readLayer @config.in, file, i
    layers.sort (a, b) => b.index - a.index
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
    
    attrs = await fs.readdir path.join(dir, layername), {withFileTypes: true}
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
  
  normalizeRestrict: ->
    return unless @config.restrict?
    normalizeTraits = (traits) =>
      traits.forEach (trait, i) =>
        traits[i] = @getLayerByTrait(trait).attributes[trait]
    if @config.restrict.mutex?
      @config.restrict.mutex.forEach (traits) => normalizeTraits traits
    if @config.restrict.forbid?
      @config.restrict.forbid.forEach (traits) => normalizeTraits traits
    return this
          
  getLayerByTrait: (trait) ->
    for layer in @layers
      return layer if layer.attributes[trait]?
    throw Error "no layer with trait #{trait}"
  getLayerIndex: (layer) ->
    index = @layers.indexOf layer
    return index if index > -1
    index = @layers.findIndex (l) => l.name is layer.name
    return index if index > -1
    throw Error "no layer #{layer.name}"
  
  generateCollection: (n, onUpdate) ->
    combinations = new Combinations @config, @layers
    combos = await combinations.pick n, onUpdate
    new Collection(@config, combos).shuffle()

extractWeight = (filename) ->
  [, weight] = filename.match(/#(\d+)\.(jpe?g|png)$/) ? []
  parseInt weight
extractZIndex = (dirname) ->
  [, index] = dirname.match(/^(\d+)[.-]/) ? []
  parseInt index

cleanAttributeName = (filename) -> filename.replace(/#\d+\.(jpe?g|png)$|\.(jpe?g|png)$/, '')
cleanLayerName = (dirname) -> dirname.replace(/^\d+[.-]/, '')
