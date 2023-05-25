{expect} = require 'chai'
path = require 'node:path'
Combinations = require './combinations'
{loadConfig} = require './config'
Generator = require './generator'
{first} = require './utils'

describe 'Combinations', ->
  config = gen = undefined
  before ->
    config = await loadConfig path.join __dirname, '..', 'test'
    gen = await new Generator(config).init()
  
  it 'initializes', ->
    combinations = new Combinations config, gen.layers
    expect(combinations.layerNodes).to.have.lengthOf 4
    expect(combinations.layerNodes[0]).to.have.lengthOf 4
    expect(combinations.layerNodes[1]).to.have.lengthOf 4
    expect(combinations.layerNodes[2]).to.have.lengthOf 3
    expect(combinations.layerNodes[3]).to.have.lengthOf 3
    
    expect(combinations.layerNodes[0].map (node) => node.attr.name)
      .to.have.members ['CyanBG', 'GreenBG', 'PurpleBG', 'RedBG']
    expect(combinations.layerNodes[1].map (node) => node.attr.name)
      .to.have.members ['BlueOrb', 'GreenOrb', 'PurpleOrb', 'RedOrb']
    expect(combinations.layerNodes[2].map (node) => node.attr.name)
      .to.have.members ['GreenShine', 'RedShine', 'WhiteShine']
    expect(combinations.layerNodes[3].map (node) => node.attr.name)
      .to.have.members ['Lighters', 'Spirits', 'Wisps']
    
    expect(combinations.root.has 'Wisps').to.be.true
    expect(combinations.root.has ['CyanBG', 'Wisps']).to.be.true
    expect(combinations.root.has ['Wisps', 'CyanBG']).to.be.false # order matters
    expect(combinations.root.has ['RedBG', 'RedOrb', 'RedShine', 'Spirits']).to.be.true
  
  it 'removes', ->
    combinations = new Combinations config, gen.layers
    
    getWeight = (path) => first(combinations.root.find(path)).weight
    
    weightRoot = combinations.root.weight
    weightCyanBG = getWeight 'CyanBG'
    weightRedBG = getWeight 'RedBG'
    
    combinations.root.remove ['CyanBG', 'Wisps']
    expect(combinations.root.has ['CyanBG', 'Wisps']).to.be.false
    expect(combinations.root.has ['CyanBG', 'BlueOrb', 'Wisps']).to.be.false
    expect(combinations.root.has ['CyanBG', 'BlueOrb', 'GreenShine', 'Wisps']).to.be.false
    expect(combinations.root.has ['RedBG', 'Wisps']).to.be.true
    expect(combinations.root.has 'Wisps').to.be.true
    
    # removed weight is -1 * 3 * 4 = -12
    # weight of 1 is subtracted from each previous nodes (3) and their previous nodes (3x4)
    # such that it is removed 12 times from the 'CyanBG' node and all nodes above (only root)
    expect(combinations.root.weight).to.equal weightRoot - 12
    expect(getWeight 'CyanBG').to.equal weightCyanBG - 12
    expect(getWeight 'RedBG').to.equal weightRedBG
  
  it 'picks', ->
    combinations = new Combinations config, gen.layers
    [combo] = combinations.pick 1
    expect(combinations.root.has combo).to.be.false
    expect(combinations.root.has combo[combo.length-1]).to.be.true
    
    # assert it still has paths to the other last layer attributes
    popped = combo.pop()
    remainingAttrs = Object.values(gen.layers[3]).filter (attr) => attr.name is not popped
    for attr in remainingAttrs
      expect(combinations.root.has [combo..., attr]).to.be.true
