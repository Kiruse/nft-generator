fs = require 'node:fs/promises'
path = require 'node:path'
YAML = require 'yaml'
jsonval = require 'jsonschema'

exports.loadConfig = ->
  configFile = await findConfig()
  ext = path.extname configFile
  contents = await fs.readFile path.join(process.cwd(), configFile), 'utf-8'
  switch ext.toLowerCase()
    when '.yaml', '.yml'
      config = YAML.parse contents
    when '.toml'
      config = TOML.parse contents
    when '.json'
      config = JSON.parse contents
    else
      throw Error "Unknown config file extension '#{ext}'."
  await validateConfig(config).then(normalizeConfig)

findConfig = ->
  exts = ['yaml', 'yml', 'toml', 'json']
  files = (await fs.readdir process.cwd(), {withFileTypes: true})
    .filter (file) => file.isFile() and file.name.match RegExp("^config\.(#{exts.join('|')})$", 'i')
    .map (file) => file.name
  for ext in exts
    if files.includes "config.#{ext}"
      return "config.#{ext}"
  throw Error "No config file found. Please create a config file named 'config.(#{exts.join('|')})' in the current directory."

validateConfig = (config) ->
  schema = YAML.parse await fs.readFile path.join(__dirname, '..', 'schemas', 'config.yaml'), 'utf-8'
  result = jsonval.validate config, schema
  if result.errors.length then throw result.errors[0]
  config
normalizeConfig = (config) ->
  config.imageSize ?= [350, 350]
  config
