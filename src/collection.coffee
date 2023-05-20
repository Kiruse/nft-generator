CSV = require 'csv-stringify/sync'
fs = require 'node:fs/promises'
path = require 'node:path'
{render} = require './image-generator'
{getCombinationWeight, shuffle} = require './utils'

# Abstraction of an NFT collection
module.exports = class Collection
  constructor: (@config, @collection) ->
  
  shuffle: ->
    shuffle @collection
    return this
  
  generateImages: (onUpdate) ->
    await Promise.all @collection.map (combo, tokenId) =>
      tokenId++
      filepath = await render @config, tokenId, combo
      onUpdate tokenId, combo
      filepath
  generateMetadata: (onUpdate) ->
    timestamp = Date.now()
    await fs.mkdir path.join(@config.out, 'metadata'), {recursive: true}
    await Promise.all @collection.map (combo, tokenId) =>
      tokenId++
      filename = path.join @config.out, 'metadata', @config.filenameTemplate.replace('{}', tokenId) + '.json'
      metadata =
        name: @config.nameTemplate.replace '{}', tokenId
        description: @config.descTemplate.replace '{}', tokenId if @config.descTemplate?
        image: "REPLACE/#{tokenId}.png"
        external_url: @config.externalUrlTemplate.replace '{}', tokenId if @config.externalUrlTemplate?
        edition: tokenId
        date: timestamp
        attributes: combo.map (attr) =>
          trait_type: attr.layer.name
          value: attr.name
        compiler: "Kiru's NFT Generator"
      await fs.writeFile filename, JSON.stringify(metadata, null, 2), 'utf8'
      onUpdate tokenId, combo, metadata
      metadata
  generateCSV: (layers) ->
    data = @collection.map (combo, tokenId) => [
      tokenId + 1
      combo.map((attr) => attr.name)...
      getCombinationWeight combo
    ]
    await fs.writeFile path.join(@config.out, 'collections.csv'), CSV.stringify [
      ['tokenId', ...layers.map((layer) => layer.name), 'weight']
      data...
    ]
    return this
