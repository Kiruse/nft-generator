nodefs = require 'node:fs/promises'
path = require 'node:path'

helia = undefined
heliafs = undefined

module.exports = api = {}
Object.defineProperty api, 'helia',
  get: =>
    unless helia?
      throw Error 'must call `await ipfs.init()` first'
    helia
  configurable: false
  enumerable: true
Object.defineProperty api, 'fs',
  get: =>
    unless heliafs?
      throw Error 'must call `await ipfs.init()` first'
    heliafs
  configurable: false
  enumerable: true

api.init = ->
  {createHelia} = await import('helia')
  {unixfs} = await import('@helia/unixfs')
  helia = await createHelia()
  heliafs = unixfs(api.helia)
  return api

api.add = (filepath) ->
  stat = await nodefs.stat filepath
  switch
    when stat.isDirectory() then await api.addDirectory filepath
    when stat.isFile()      then await api.addFile filepath
    else
      console.warn "Unhandled file type: #{filepath}"
api.addDirectory = (dirpath) ->
  cid = await heliafs.addDirectory()
  for entry in await nodefs.readdir dirpath
    itemcid = await api.add path.join dirpath, entry
    cid = await heliafs.cp itemcid, cid, entry
  cid
api.addFile = (filepath) -> await heliafs.addBytes await nodefs.readFile filepath
