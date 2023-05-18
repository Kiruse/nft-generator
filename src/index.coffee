fs = require 'node:fs/promises'
{ValidationError} = require 'jsonschema'
path = require 'node:path'
{rimraf} = require 'rimraf'
{loadConfig} = require './config'
Generator = require './generator'

INDEV = process.env.NODE_ENV is 'development'

run = ->
  [pwd] = process.argv.slice 2
  config = await loadConfig pwd
  await rimraf config.out
  await fs.mkdir config.out, {recursive: true}
  
  gen = new Generator config
  await gen.init()
  
  # generate all combinations
  combos = gen.generateCollection()
  
  # images = gen.generateImages combos
  # metas  = gen.generateMetadata combos
  await fs.writeFile path.join(config.out, 'combinations.csv'), gen.generateCSV(combos)
  # TODO: write images & metadata
run().catch (err) ->
  if INDEV
    console.error err
  else
    if err instanceof ValidationError
      console.error err.stack
    else
      console.error err.message
  process.exit 1
