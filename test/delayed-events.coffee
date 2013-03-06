should = require 'should'


firstEventFired = 0
callbacks =
  complete: ->
  initial: (data, next) ->
    firstEventFired += 1
    next()
event_storage = 
  1:{data:1,functionName:'initial', time: new Date().getTime()}
  2:{data:2,functionName:'complete', time: new Date().getTime() + 1000000}
mock_storage =
  getDelayedEvents:  (next) ->
    events = (event_storage[event] for event of event_storage)
    next events
  markDelayedEvent:  (event, next) ->
    event_storage[event.data].marked = yes
    next()
  clearDelayedEvent: (event, next) ->
    event_storage[event.data] = undefined
  addDelayedEvent:   (event, next) ->
    event_storage[event.data] = event

de1 = null
de2 = null

describe 'Delayed Events Queue', ->
  before ->
    de1 = require('../src/delayed-events')(callbacks:callbacks, storage:mock_storage, tickInterval:10)
    de2 = require('../src/delayed-events')(callbacks:callbacks, tickInterval:10)
    
  after ->
    de1.close()
    de2.close()
    
  it 'should restore events that were saved if a storage queue is specified', (done) ->
    de1.restore()
    setTimeout (->
      firstEventFired.should.equal 1
      de1.getPendingEventCount().should.equal 1
      de2.getPendingEventCount().should.equal 0
      done()),20
      
  it 'should execute events after the specified timeout', (done) ->
    tick = new Date().getTime()
    de2.addEvent 50, 'complete', 3
    callbacks.complete = (data) ->
      tock = new Date().getTime()
      (tock-tick).should.be.within 35, 65
      data.should.equal 3
      done()
    
  it 'should save the events in the storage queue if one is specified', (done) ->
    tick = new Date().getTime()
    de1.addEvent 50, 'complete', 4
    should.exist event_storage[4]
    event_storage[4].data.should.equal 4
    event_storage[4].functionName.should.equal 'complete'
    callbacks.complete = (data) ->
      tock = new Date().getTime()
      (tock-tick).should.be.within 35, 65
      data.should.equal 4
      event_storage[4].should.have.property 'marked', yes
      setTimeout (->
        event_storage.should.not.have.property 4
        done()), 20
        
  it 'should support absolute times', (done) ->
    tick = new Date().getTime()
    de2.addEventAtTime tick+50, 'complete', 5
    callbacks.complete = (data) ->
      tock = new Date().getTime()
      (tock-tick).should.be.within 35, 65
      data.should.equal 5
      done()
      
  it 'should return the number of pending events', (done) ->
    de2.addEventAtTime new Date().getTime() + 12345667, 'complete', 6
    de2.addEventAtTime new Date().getTime() + 33333333, 'complete', 7
    de2.getPendingEventCount().should.equal 2
    done()