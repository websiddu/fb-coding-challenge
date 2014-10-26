'use strict'

window.FB = do ->

  # Constants
  EVENT_TEMPLATE = """
      <span class="ellipsis event-title">Sample Item</span>
      <span class="ellipsis small">Sample Location</span>
    """

  events = []

  # Shared variables
  container = document.querySelector '.schedule'
  timeAixs = document.querySelector '.times'
  startTime = new Date().setHours(9, 0, 0, 0) # 9:00AM today
  endTime = new Date().setHours(21, 0, 0, 0) # 9:00PM today


  # ### _init
  #
  # Initialize the scheduler
  #
  _init = ->
    _renderAxis()

  # ### _renderAxis
  #
  # Render the time axis on the left
  #
  # Returns noting
  _renderAxis = ->
    while startTime <= endTime
      now = new Date(startTime)
      formatter = _formatDate(now)
      axis = _getAxisPointHTML formatter
      axisPoint = document.createElement('div')
      axisPoint.className = 'hour'
      axisPoint.innerHTML = axis
      timeAixs.appendChild(axisPoint)
      # Increment by one hour
      startTime+=3600000


  # ### _getAxisPointHTML
  # Construct the HTML for the time axis point on the left
  # 1. **fomatter** - The time formatter object
  #
  # Returns a html string with required markup
  _getAxisPointHTML = (formatter) ->
    now = new Date(startTime)
    nextHalfHour = new Date(startTime + 1800000)
    halfHourTemplate = """
      <time class='small hour-half' datetime='#{nextHalfHour.toString()}'>
        #{formatter.hourHalf}
      </time>
    """
    # Don't show 9:30
    halfHourTemplate = '' if startTime is endTime
    axisPointTemplate = """
      <time datetime="#{now.toString()}">
        #{formatter.time} <small class="small">#{formatter.ampm}</small>
      </time>
      #{halfHourTemplate}
    """
    return axisPointTemplate

  # ### _renderSchedule
  #
  # Renders the schedule on the container
  #
  # Returns noting
  _renderSchedule = ->
    events.sort _compareEvts
    _emptyContainer()
    _setEvtsCoord(events)
    _render()

  # ### _emptyContainer
  # Removes all the child elements in the container
  #
  # Returns noting
  _emptyContainer = -> container.innerHTML = ''

  # ### _render
  #
  # Updates the CSS and appends the events on to DOM
  #
  # Returns noting
  _render = ->
    i = 0
    while i < events.length
      evt = events[i]
      el = document.createElement('div')
      el.className = 'event animated fadeIn'
      el.innerHTML = EVENT_TEMPLATE
      evt.el = el
      el.setAttribute("style", _evtCssStyles(evt))
      container.appendChild evt.el
      i++

  # ### _evtCssStyles
  # Generates string with CSS properties that should be applied to an event
  # element.
  #
  # 1. **evt** - An event object
  #
  # Returns an object CSS properties
  _evtCssStyles = (evt) ->
    top = "#{evt.start}px"
    height = "#{evt.end - evt.start}px"
    left ="#{evt.leftCoord * 100}%"
    width = "#{(evt.rightCoord - evt.leftCoord) * 100}%"

    # Calculating width to make sure that the below is valid
    # 2) If two events collide in time, they must have the same width.
    unless evt.afterEvts.length is 0
      width = (evt.afterEvts[0].rightCoord - evt.afterEvts[0].leftCoord) * 100 + "%"

    # calculate the right position from right coordinate so that
    # event will occupy the width till it hits the next edge.
    # This will be cool!! Not using for now!!
    # right = "#{(1 - evt.rightCoord) * 100}%"

    "top: #{top}; left: #{left}; width: #{width}; height: #{height}"

  # ### _setEvtsCoord
  # Given an array of events sets the leftCoord and rightCoord on each.
  #
  # 1. **evts** - An array of event object
  #
  # Returns noting
  _setEvtsCoord = (evts) ->
    levels = _buildEvtLevels(evts)
    _computeAfterEvts levels
    firstLevel = levels[0]
    # Compute pressure and coordinates for the first level. recursion takes
    # care of other levels
    _computeEvtPressures evt for evt in firstLevel
    _computeEvtCoords evt, 0, 0 for evt in firstLevel
    return

  # ### _buildEvtLevels
  # Returns an array of events `levels` based on event collisions
  #
  # 1. **evts** - An array of events
  #
  # Returns an array of events
  _buildEvtLevels = (evts) ->
    levels = []
    i = 0
    while i < evts.length
      evt = evts[i]
      # Loop every level and stop on the first level where there are no
      # collisions
      j = 0
      while j < levels.length
        break unless _computeEvtCollisions(evt, levels[j]).length
        j++
      evt.level = j
      (levels[j] or (levels[j] = [])).push evt
      i++
    levels

  # ### _computeAfterEvts
  # For every event, figure out the other events that are in subsequent
  # levels that also occupy the same vertical space. Update in evt.afterEvts.
  #
  # 1. **levels** - An array of arrays of events
  #
  # Returns noting
  _computeAfterEvts = (levels) ->
    i = 0
    while i < levels.length
      level = levels[i]
      j = 0
      while j < level.length
        evt = level[j]
        evt.afterEvts = []
        k = i + 1
        while k < levels.length
          _computeEvtCollisions evt, levels[k], evt.afterEvts
          k++
        j++
      i++
    return

  # ### _computeEvtPressures
  # Find out which path forward (using evt.afterEvts) results in the longest
  # path until the furthest edge is reached. The number of events in this path
  # will be updated as evt.pressure
  #
  # 1. **evt** - An event object
  #
  # Returns noting
  _computeEvtPressures = (evt) ->
    afterEvts = evt.afterEvts
    pressure = 0
    if evt.pressure is `undefined` # not already computed
      i = 0
      while i < afterEvts.length
        forwardEvt = afterEvts[i]

        # Figure out the child's maximum forward path
        _computeEvtPressures forwardEvt

        # Either use the existing maximum, or use the child's forward pressure
        # plus one
        pressure = Math.max(pressure, 1 + forwardEvt.pressure)
        i++
      evt.pressure = pressure
    return

  # ### _computeEvtCoords
  #
  # Calculate rightCoord and leftCoord for the event, where both values range
  # from 0 to 1.
  #
  # 1. **evt** - The event object
  # 2. **seriesLeftPressure** - The number of events behind this event in the current series
  # 3. **seriesleftCoord** - The starting coordinate of the first event in the series.
  #
  # Returns noting
  _computeEvtCoords = (evt, seriesLeftPressure, seriesleftCoord) ->
    afterEvts = evt.afterEvts
    if evt.rightCoord is undefined
      if !afterEvts.length
        # If there are no after events, event should alight to extreme right
        evt.rightCoord = 1
      else
        # Sort highest pressure first
        afterEvts.sort _compareAfterEvts
        # This event's rightCoord will be calculated from the leftCoord of the
        # highest-pressure after event.
        _computeEvtCoords afterEvts[0], seriesLeftPressure + 1, seriesleftCoord
        evt.rightCoord = afterEvts[0].leftCoord

      # Calculate the leftCoord from the rightCoord.
      evt.leftCoord = evt.rightCoord - (evt.rightCoord - seriesleftCoord) / (seriesLeftPressure + 1)

      # Compute the coordinates of the less-pressurized after events
      i = 0
      while i < afterEvts.length
        _computeEvtCoords afterEvts[i], 0, evt.rightCoord
        i++
    return

  # ### _computeEvtCollisions
  # Find all the events in `otherEvts` that vertically collide with `evt`.
  # Append into an optionally-supplied `results` array and return.
  #
  # 1. **evt** - The event object
  # 2. **otherEvts** - An array of events
  # 3. **results** - Array of events
  #
  # returns an array of events
  _computeEvtCollisions = (evt, otherEvts, results) ->
    results = results or []
    i = 0
    while i < otherEvts.length
      results.push otherEvts[i]  if _isEvtCollision(evt, otherEvts[i])
      i++
    results

  # Check if the event's occupy the same vertical space or Overlap
  #
  # 1. **evt1** - First event object
  # 2. **evt2** - Second event object
  #
  # Returns a boolean
  _isEvtCollision = (evt1, evt2) ->
    evt1.end > evt2.start and evt1.start < evt2.end

  # A comparator function determining which after event to rely on more when
  # computing coordinates.
  #
  # 1. **evt1** - First event object
  # 2. **evt2** - Second event object
  #
  # Returns a boolean
  _compareAfterEvts = (evt1, evt2) ->
    evt2.pressure - evt1.pressure or (evt1.leftCoord or 0) - (evt2.leftCoord or 0)

  # ### _compareEvts
  # A comparator function to compare the event while sorting. Compare the start
  # time first if both are the same then, compare the duration.
  #
  # 1. **evt1** - First event object
  # 2. **evt2** - Second event object
  #
  # Returns a boolean
  _compareEvts = (evt1, evt2) ->
    (evt1.start - evt2.start) or ((evt2.end - evt2.start) - (evt1.end - evt1.start))

  # ### _formatDate
  # A Utility method which returns the AM or PM and other string
  # formats for a given 24 hours format date
  #
  # 1. **date** - A date object
  #
  # Returns an object with required string formats
  _formatDate = (date) ->
    hours = date.getHours()
    minutes = date.getMinutes()
    ampm = (if hours >= 12 then "PM" else "AM")
    hours = hours % 12
    hours = (if hours then hours else 12) # the hour '0' should be '12'
    # No need to check minutes in this case, keeping this for future
    minutes = (if minutes < 10 then "0" + minutes else minutes)

    ampm: ampm
    time: "#{hours}:#{minutes}"
    hourHalf: "#{hours}:#{parseInt(minutes) + 30}"

  # ## Public Methods

  # ### FB.paintSchedule
  # Public method to render the events on to the scheduler
  #
  # 1. **newEvents** - An array of events to be rendered
  #
  # returns noting
  paintSchedule: (evts) ->
    events = evts
    _renderSchedule()
    return

  # FB.init
  #
  # A public method to initialize the application
  #
  init: ->
    _init()

FB.init()

# Exposing only required function
window.layOutDay = window.FB.paintSchedule

layOutDay([{start: 30, end: 150}, {start: 540, end: 600}, {start: 560, end: 620}, {start: 610, end: 670}])
