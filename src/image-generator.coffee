{createCanvas, loadImage} = require 'canvas'
path = require 'node:path'
proc = require 'node:child_process'
{pick, repeat} = require './utils'

class Worker
  constructor: ->
    @worker = new proc.fork path.join(__dirname, 'image-generator-worker.js')
    @busy = false
    
    @worker.on 'exit', (code) => console.log "Worker exited with code #{code}"
  
  take: ->
    return if @busy
    return unless queue.length
    @handleTask queue.shift()
  
  handleTask: (task) ->
    throw Error "Already busy!" if @busy
    @busy = true
    
    @worker.send pick task, 'id', 'config', 'combo'
    @worker.on 'message', listener = (msg) =>
      unless msg.id is task.id
        console.warn "Unexpected ID #{msg.id}, expected #{task.id}"
        return
      
      @busy = false
      @worker.off 'message', listener
      
      if msg.error?
        error = new Error msg.error.msg
        error.stack = msg.error.stack
        task.reject error
      else
        task.resolve msg.filename
      @take()

class Task
  constructor: (@config, @id, combo) ->
    @combo = combo.map (attr) =>
      name: attr.name
      layer: pick attr.layer, 'name', 'index', 'position', 'size'
      path: attr.path
      image: attr.image.toString 'base64'
    @promise = new Promise (resolve, reject) =>
      @resolve = resolve
      @reject = reject
  then: (resolved, rejected) -> @promise.then resolved, rejected

queue = []
pool = repeat 4, => new Worker()

findFreeWorker = => pool.find (worker) => not worker.busy

exports.render = (config, id, combo) ->
  queue.push task = new Task config, id, combo
  if worker = findFreeWorker()
    worker.take()
  return task
