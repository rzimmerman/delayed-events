#
## delayed-events.coffee
#
# a simple delayed event queue with fault recovery

module.exports = (callbacks, storage, tickInterval) ->
  queue = []
  
  bisect = (x) ->
    lo = 0
    hi = queue.length
    while lo < hi
      mid = Math.floor (lo + hi) / 2
      if x.time < queue[mid].time
        hi = mid
      else
        lo = mid + 1
    return lo
  
  insort = (x) ->
    queue.splice bisect(queue, x), 0, x
  
  processEvent = (event) ->
    if callbacks[event.functionName]?
      callbacks[event.functionName] event.data
    else
      console.log "delayed-events: could not find function #{event.functionName}"
    storage?.clearDelayedEvent? event
  
  tick = ->
    currentIndex = bisect time: new Date().getTime()
    index = 0
    while index < currentIndex
      storage?.markDelayedEvent? event
      processEvent queue[index]
      index += 1
    queue.splice 0, currentIndex
  
  addEventToQueue = (event) ->
    storage?.addDelayedEvent? event
    insort event
  
  instance =
    addEvent: (timeFromNow, functionName, data) ->
      addEventToQueue time:new Date().getTime() + timeFromNow, functionName: functionName, data: data
    addEventAtTime: (absoluteTime, functionName, data) ->
      addEventToQueue time:absoluteTime, functionName: functionName, data: data
    getPendingEventCount: ->
      return queue.length
    restore: ->
      storage?.getDelayedEvents? (events) ->
        queue = queue.concat events
        queue.sort (x, y) -> x.time > y.time
    close: ->
      clearInterval timer
  
  timer = setInterval tick, tickInterval or 10000
  
  return instance