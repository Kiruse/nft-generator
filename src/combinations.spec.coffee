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
  
  getCombinations = => new Combinations config, gen.layers
  
  it 'initializes', ->
    combinations = getCombinations()
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
  
  it 'finds', ->
    combs = getCombinations()
    root = combs.root
    
    redOrb = first root.find ['RedOrb'] # Tree::find retruns a `Trees` wrapper! 
    expect(first(redOrb.find ['RedOrb']) is redOrb).to.be.true
    expect(first(redOrb.find ['RedShine']) is first(root.find ['RedShine'])).to.be.true
    
    expect(first(redOrb.find redOrb) is redOrb).to.be.true
  
  it 'removes', ->
    combs = getCombinations()
    
    getWeight = (path) => first(combs.root.find(path)).weight
    
    weightRoot = combs.root.weight
    weightCyanBG = getWeight 'CyanBG'
    weightRedBG = getWeight 'RedBG'
    
    combs.root.remove ['CyanBG', 'Wisps']
    expect(combs.root.has ['CyanBG', 'Wisps']).to.be.false
    expect(combs.root.has ['CyanBG', 'BlueOrb', 'Wisps']).to.be.false
    expect(combs.root.has ['CyanBG', 'BlueOrb', 'GreenShine', 'Wisps']).to.be.false
    expect(combs.root.has ['RedBG', 'Wisps']).to.be.true
    expect(combs.root.has 'Wisps').to.be.true
    
    # removed weight is -1 * 3 * 4 = -12
    # weight of 1 is subtracted from each previous nodes (3) and their previous nodes (3x4)
    # such that it is removed 12 times from the 'CyanBG' node and all nodes above (only root)
    expect(combs.root.weight).to.equal weightRoot - 12
    expect(getWeight 'CyanBG').to.equal weightCyanBG - 12
    expect(getWeight 'RedBG').to.equal weightRedBG
  
  it 'picks', ->
    combs = getCombinations()
    [combo] = combs.pick 1
    expect(combs.root.has combo).to.be.false
    expect(combs.root.has combo[combo.length-1]).to.be.true
    
    # assert it still has paths to the other last layer attributes
    popped = combo.pop()
    remainingAttrs = Object.values(gen.layers[3]).filter (attr) => attr.name is not popped
    for attr in remainingAttrs
      expect(combs.root.has [combo..., attr]).to.be.true
