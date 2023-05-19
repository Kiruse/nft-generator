fs = require 'node:fs/promises'
path = require 'node:path'
YAML = require 'yaml'
jsonval = require 'jsonschema'

exports.loadConfig = (pwd) ->
  pwd ?= process.cwd()
  configFile = await findConfig pwd
  ext = path.extname configFile
  contents = await fs.readFile path.join(pwd, configFile), 'utf-8'
  switch ext.toLowerCase()
    when '.yaml', '.yml'
      config = YAML.parse contents
    when '.toml'
      config = TOML.parse contents
    when '.json'
      config = JSON.parse contents
    else
      throw Error "Unknown config file extension '#{ext}'."
  
  config = await validateConfig config
  config = normalizeConfig config, pwd

findConfig = (pwd) ->
  exts = ['yaml', 'yml', 'toml', 'json']
  files = (await fs.readdir pwd, {withFileTypes: true})
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
normalizeConfig = (config, pwd) ->
  config.path = pwd
  config.in = path.join pwd, config.in ? 'layers'
  config.out = path.join pwd, config.out ? 'generated'
  config.imageSize ?= [350, 350]
  config.layout ?= {}
  config.filenameTemplate ?= '{}'
  
  if config.restrict?.limit?
    limits = config.restrict.limit
    for trait of limits
      if typeof limits[trait] is 'number'
        limits[trait] = { max: limits[trait] }
  
  config
