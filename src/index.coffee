fs = require 'node:fs/promises'
{ValidationError} = require 'jsonschema'
hash = require 'object-hash'
{rimraf} = require 'rimraf'
Combinations = require './combinations'
{loadConfig} = require './config'
Generator = require './generator'
ipfs = require './ipfs'
{displayTraits, sleep} = require './utils'

INDEV = process.env.NODE_ENV is 'development'

run = ->
  chalk = (await import('chalk')).default
  await ipfs.init()
  
  [pwd] = process.argv.slice 2
  config = await loadConfig pwd
  await rimraf config.out
  await fs.mkdir config.out, {recursive: true}
  
  total = config.collectionSize
  gen = new Generator config
  await createSpinner 'Loading collection data...', => gen.init()
  
  combinations = await createSpinner 'Generating combinations...', => await gen.generateCollection()
  combos = combinations.pick 5050
  
  count = 0
  await createSpinner 'Checking for duplicates', (spinner) =>
    hashes = {}
    for combo in combos
      count++
      h = hash(combo)
      spinner.text = "Checking for duplicates [#{chalk.yellow count}/#{chalk.cyan total}] #{chalk.grey displayTraits combo}"
      if hashes[h]?
        throw Error "duplicates found: #{hashes[h]} and #{count}"
      hashes[h] = count
      await sleep 0
  
  count = 0
  await createSpinner '', (spinner) =>
    await collection.generateImages (tokenId, combo) =>
      count++
      spinner.text = "Generating images [#{chalk.yellow count}/#{chalk.cyan total}] #{chalk.grey displayTraits combo}"
  
  count = 0
  await createSpinner '', (spinner) =>
    await collection.generateMetadata (tokenId, combo) =>
      count++
      spinner.text = "Generating metadata [#{chalk.yellow count}/#{chalk.cyan total}] #{chalk.grey displayTraits combo}"
  
  await createSpinner 'Generating CSV', => collection.generateCSV gen.layers
  process.exit 0
run().catch (err) ->
  if INDEV
    console.error err
  else
    if err instanceof ValidationError
      console.error err.stack
    else
      console.error err.message
  process.exit 1

createSpinner = (label, cb) =>
  ora = (await import('ora')).default
  spinner = ora(label).start()
  try
    result = await cb spinner
    spinner.succeed()
    return result
  catch err
    spinner.fail()
    throw err
