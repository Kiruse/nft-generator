fs = require 'node:fs/promises'
{ValidationError} = require 'jsonschema'
path = require 'node:path'
{rimraf} = require 'rimraf'
{loadConfig} = require './config'
Generator = require './generator'
ipfs = require './ipfs'

INDEV = process.env.NODE_ENV is 'development'

run = ->
  chalk = (await import('chalk')).default
  await ipfs.init()
  
  [pwd] = process.argv.slice 2
  config = await loadConfig pwd
  await rimraf config.out
  await fs.mkdir config.out, {recursive: true}
  
  gen = new Generator config
  await gen.init()
  
  # generate all combinations
  collection = gen.generateCollection()
  
  totalImages = config.collectionSize
  currImages = 0
  await createSpinner '', (spinner) =>
    await collection.generateImages (tokenId, combo) =>
      currImages++
      traits = combo.map((attr) => attr.name).join(', ')
      spinner.text = "[#{chalk.yellow currImages}/#{chalk.cyan totalImages}] #{chalk.grey traits}"
  # metas  = gen.generateMetadata combos
  await fs.writeFile path.join(config.out, 'combinations.csv'), gen.generateCSV(collection.collection)
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
    await cb spinner
    spinner.succeed()
  catch err
    spinner.fail()
    throw err
