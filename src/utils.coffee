exports.clone = (obj) => JSON.parse JSON.stringify obj
exports.collect = (iterable) => if Array.isArray iterable then iterable else [iterable...]
exports.enumerate = (iterable) ->
  i = 0
  yield [i++, value] for value in iterable
exports.isArraylike = (obj) => obj? and typeof obj is 'object' and typeof obj.length is 'number'
exports.isIterable = (obj) => obj? and typeof obj[Symbol.iterator] is 'function'
exports.repeat = (n, x) =>
  if typeof x is 'function'
    Array(n).fill(0).map (, i) => x(i)
  else
    Array(n).fill(x)
exports.shuffle = (array) => # shuffle array in-place
  unless Array.isArray array
    throw Error 'not an array'
  for i in [0...array.length]
    j = Math.floor Math.random() * array.length
    [array[i], array[j]] = [array[j], array[i]]
  array
exports.sleep = (timeout) => new Promise (resolve) => setTimeout resolve, timeout

exports.getCombinationWeight = (combo) ->
  total = 0
  total += attr.weight for attr in combo
  total

exports.pick = (obj, props...) => Object.fromEntries Object.entries(obj).filter(([key]) => key in props)
exports.omit = (obj, props...) => Object.fromEntries Object.entries(obj).filter(([key]) => key not in props)

exports.first = (iterable) ->
  for item from iterable
    return item

exports.displayTraits = (attrs) -> attrs.map((attr) => attr.name).join(', ')
