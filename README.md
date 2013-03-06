# Delayed Events

Keeps and event queue and calls back after the requested delay. This module supports writing events to storage and refreshing them in case of a server outage.

## Usage

### Setup

To create a delayed event queue:

    var eventQueue = require('delayed-events')(options)

Where options can contain:
* *storage* - Optional, you can leave this as `undefined` or `null` if you don't want to use the save/resume feature.
* *tick_interval* - The number of milliseconds between ticks. Events will run on the closest tick to their specified time. Defaults to 1 second (1000).
* *callbacks* - An object containing your named callback functions. Each function takes one argument, which is the `data` field specified by `addEvent` or `addEventAtTime`.

Example (without save/resume):

    var model = {
        sendEmail: function (emailAddress) {
            console.log('Sent email to', emailAddress);
        }
    }
    
    var eventQueue = require('delayed-events')({callbacks: model, timeInterval: 500});
    
    eventQueue.addEvent(1000,"sendEmail","rob@example.com");

Note that if your event callback functions accept two arguments, the second is treated as a callback. This is only useful when you are using using save/resume and you want to make sure your function completes before removing it from the data store (see save/resume for details).

### eventQueue methods

#### addEvent

Add an event to the event queue given a time in milliseconds from now. Usage:

    eventQueue.addEvent(timeFromNow, functionName, data);

* *timeFromNow* - The time in milliseconds from now to execute the event. If it is in the past, it will execute on the next tick. Otherwise, it will execute on the first tick after timeFromNow has elapsed.
* *functionName* - A string that gives the name of the function in the `callbacks` object that was passed in when the queue was created.
* *data* - A value or object that gets passed back to `functionName`.

#### addEventAtTime

Add an event to the event queue given timestamp. Usage:

    eventQueue.addEvent(absoluteTime, functionName, data);

* *absoluteTime* - The time in milliseconds from epoch start. You can generate the current time with `new Date().getTime()`. If it is in the past, it will execute on the next tick. Otherwise, it will execute on the first tick after timeFromNow has elapsed.
* *functionName* - A string that gives the name of the function in the `callbacks` object that was passed in when the queue was created.
* *data* - A value or object that gets passed back to `functionName`.

#### getPendingEventCount

Return the number of pending events in the queue. Usage:

    eventQueue.getPendingEventCount()
    
#### restore

Load saved events from the datastore specified in `storage` when the queue was created. See the Save/Resume section.

#### close

To stop the queue and let node shutdown cleanly, call:

    eventQueue.close();
    
This invalidates any timers.


### Save/Resume

If you pass a `storage` option when creating the event queue, the queue will call save events to storage. This is useful if your server crashes or restarts for any reason. Your storage object should contain the following functions:

#### getDelayedEvents

Return any delayed events stored in the database as an array. Template:

    function getDelayedEvents(callback) {
        //access data store, returning an array in variable `events`
        callback(events);
    }
    
#### getDelayedEvents

Return any delayed events stored in the data store as an array. Uses a callback, which the user must call. Template:

    function getDelayedEvents(callback) {
        //access data store, returning an array in variable `events`
        callback(events);
    }

#### clearDelayedEvent

Delete the delayed event from the data store. The user can use the event.time and event.data properties to identify the event in the data store. No callbacks are used.

    function clearDelayedEvent(event) {
        //use event.data and/or event.time to remove event from your data store
    }

Note that if your event functions take a callback as a second parameter, this function will only get called if your event function calls back with `null` or `undefined`. This way a triggered event that fails will be marked but not cleared.

#### addDelayedEvent

Add a delayed event to the data store. The user can use the event.time and event.data properties to create a unique ID. No callbacks are used.

    function addDelayedEvent(event) {
        //use event.data and/or event.time to add event to your data store
    }

#### markDelayedEvent

Mark an event as started in the data store. This is called just before executing the event. This function is optional. It does use a callback, which the user must call. This is useful if you have events that may fail, or that you really don't want to execute twice.

    function markDelayedEvent(event, callback) {
        //use event.data and/or event.time to mark the event in your data store
        callback();
    }

#### Example

A mongoskin-like example:

    var eventStorage = {
        getDelayedEvents: function (cb) {
            database.events.find({marked:false,complete:false}).toArray(function (err,events) {
                cb(events);
            }
        },
        addDelayedEvent: function (event) {
            var record = {event:event, marked:false, complete:false, id:event.data.id};
            database.events.insert(record);
        },
        clearDelayedEvent: function (event) {
            database.update({id:event.data.id},{$set:{complete:true}});
        },
        markDelayedEvent: function (event, cb) {
            database.update({id:event.data.id},{$set:{marked:true}}, function (err) {
                cb();
            });
        },
    }
    
    var eventFunctions = {
        sendEmail: function (eventData, next) {
            console.log('Sent email to', eventData.emailAddress);
            next(); //could pass an error here as next(new Error()); to prevent calling of clearDelayedEvent
        }
    }
    
    var eventQueue = require('delayed-events')({callbacks: eventFunctions, storage: eventStorage, timeInterval: 500});
    
    eventQueue.restore(); //load any events in the database
    
    eventQueue.addEvent(1000,"sendEmail",{id:database.ObjectId(),emailAddress:"rob@example.com"});

    