{expect} = require 'chai'
path = require 'node:path'
{loadConfig} = require './config'
Generator = require './generator'

describe 'Generator', ->
  config = undefined
  before ->
    config = await loadConfig path.join __dirname, '..', 'test'
  
  it 'initializes', ->
    gen = new Generator config
    await gen.init()
    layers = gen.layers
    
    expect(Object.values(layers).map (layer) => layer.name).to.have.members ['Sparkle', 'Lighting', 'Orb', 'Back']
    expect(Object.values(layers).map (layer) => layer.index).to.deep.equal [0, 1, 2, 3]
    
    expect(Object.values(layers[0].attributes)).to.have.lengthOf 4
    expect(Object.values(layers[1].attributes)).to.have.lengthOf 4
    expect(Object.values(layers[2].attributes)).to.have.lengthOf 3
    expect(Object.values(layers[3].attributes)).to.have.lengthOf 3
    
    expect(Object.values(layers[0].attributes).map (attr) => {name: attr.name, weight: attr.weight})
      .to.have.deep.members [
        {name: 'RedBG', weight: 10}
        {name: 'CyanBG', weight: 10}
        {name: 'GreenBG', weight: 10}
        {name: 'PurpleBG', weight: 1}
      ]
    expect(Object.values(layers[1].attributes).map (attr) => {name: attr.name, weight: attr.weight})
      .to.have.deep.members [
        {name: 'RedOrb', weight: 3}
        {name: 'BlueOrb', weight: 10}
        {name: 'GreenOrb', weight: 5}
        {name: 'PurpleOrb', weight: 1}
      ]
    expect(Object.values(layers[2].attributes).map (attr) => {name: attr.name, weight: attr.weight})
      .to.have.deep.members [
        {name: 'RedShine', weight: 10}
        {name: 'GreenShine', weight: 10}
        {name: 'WhiteShine', weight: 1}
      ]
    expect(Object.values(layers[3].attributes).map (attr) => {name: attr.name, weight: attr.weight})
      .to.have.deep.members [
        {name: 'Wisps', weight: 1}
        {name: 'Spirits', weight: 10}
        {name: 'Lighters', weight: 100}
      ]
