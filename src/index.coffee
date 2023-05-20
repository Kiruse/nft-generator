fs = require 'node:fs/promises'
{ValidationError} = require 'jsonschema'
hash = require 'object-hash'
path = require 'node:path'
{rimraf} = require 'rimraf'
{loadConfig} = require './config'
Generator = require './generator'
ipfs = require './ipfs'
{sleep} = require './utils'

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
  
  count = 0
  collection = await createSpinner '', (spinner) => gen.generateCollection config.collectionSize, (tokenId, combo) =>
    count++
    spinner.text = "Generating collection [#{chalk.yellow count}/#{chalk.cyan total}] #{chalk.grey displayTraits combo}"
  
  count = 0
  await createSpinner '', (spinner) =>
    hashes = {}
    for combo in collection.collection
      count++
      h = hash(combo)
      spinner.text = "Checking for duplicates [#{chalk.yellow count}/#{chalk.cyan total}] #{chalk.grey displayTraits combo}"
      if hashes[h]
        throw Error 'duplicates found'
      hashes[h] = true
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
displayTraits = (combo) => combo.map((attr) => attr.name).join(', ')
