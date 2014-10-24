window.FB = do ->

  #events = [ {start: 30, end: 150}, {start: 540, end: 600}, {start: 560, end: 620}, {start: 610, end: 670} , {start: 570, end: 630},];
  events = [{"start":35,"end":86},{"start":31,"end":98},{"start":60,"end":127},{"start":93,"end":146},{"start":114,"end":165},{"start":127,"end":186},{"start":162,"end":221},{"start":209,"end":278},{"start":226,"end":284},{"start":269,"end":339},{"start":320,"end":408},{"start":380,"end":441},{"start":422,"end":485},{"start":455,"end":519},{"start":483,"end":550},{"start":512,"end":566},{"start":511,"end":578},{"start":560,"end":639},{"start":580,"end":634},{"start":614,"end":665},{"start":606,"end":693}]
  # events = [ {start: 30, end: 150}, {start: 540, end: 600}, {start: 560, end: 620}, {start: 610, end: 670} ];

  unpaintedEvents = []

  _init = ->
    _sortEvent()
    placeSlotSegs(events)
    _updateCols()

    _renderIt()

  _renderIt = ->
    segCols = groupSegCols(events)
    col = 0 # iterate each column grouping
    while col < segCols.length
      colSegs = segCols[col]
      containerEl = $('.schedule')
      i = 0
      while i < colSegs.length
        seg = colSegs[i]
        el = """
            <div class="event">
            </div>
          """
        seg.el = $(el)
        seg.el.css generateSegPositionCss(seg)
        containerEl.append seg.el
        i++
      col++

  _updateCols = ->
    i = 0
    while i < events.length
      events[i].col = 0
      i++

  _sortEvent = ->
    return _.chain(events).sortBy( (evt) -> evt.start ).value()

  # Generates an object with CSS properties/values that should be applied to an event segment element.
  # Contains important positioning-related properties that should be applied to any event element, customized or not.
  generateSegPositionCss = (seg) ->
    top: seg.start + 'px'
    height: seg.end - seg.start + 'px'
    left: seg.backwardCoord * 100 + "%"
    right: (1 - seg.forwardCoord) * 100 + "%"

  groupSegCols = (segs) ->
    segCols = [[]]
    i = 0
    while i < segs.length
      segCols[segs[i].col].push segs[i]
      i++
    segCols


  # Given an array of segments that are all in the same column, sets the backwardCoord and forwardCoord on each.
  # Also reorders the given array by date!
  placeSlotSegs = (segs) ->
    levels = buildSlotSegLevels(segs)
    computeForwardSlotSegs levels
    if level0 = levels[0]
      i = 0
      while i < level0.length
        computeSlotSegPressures level0[i]
        i++
      i = 0
      while i < level0.length
        computeSlotSegCoords level0[i], 0, 0
        i++
    return

  # Builds an array of segments "levels". The first level will be the leftmost tier of segments if the calendar is
  # left-to-right, or the rightmost if the calendar is right-to-left. Assumes the segments are already ordered by date.
  buildSlotSegLevels = (segs) ->
    levels = []
    i = 0
    while i < segs.length
      seg = segs[i]

      # go through all the levels and stop on the first level where there are no collisions
      j = 0
      while j < levels.length
        break  unless computeSlotSegCollisions(seg, levels[j]).length
        j++
      seg.level = j
      (levels[j] or (levels[j] = [])).push seg
      i++
    levels

  # For every segment, figure out the other segments that are in subsequent
  # levels that also occupy the same vertical space. Accumulate in seg.forwardSegs
  computeForwardSlotSegs = (levels) ->
    i = 0
    while i < levels.length
      level = levels[i]
      j = 0
      while j < level.length
        seg = level[j]
        seg.forwardSegs = []
        k = i + 1
        while k < levels.length
          computeSlotSegCollisions seg, levels[k], seg.forwardSegs
          k++
        j++
      i++
    return

  # Figure out which path forward (via seg.forwardSegs) results in the longest path until
  # the furthest edge is reached. The number of segments in this path will be seg.forwardPressure
  computeSlotSegPressures = (seg) ->
    forwardSegs = seg.forwardSegs
    forwardPressure = 0
    i = undefined
    forwardSeg = undefined
    if seg.forwardPressure is `undefined` # not already computed
      i = 0
      while i < forwardSegs.length
        forwardSeg = forwardSegs[i]

        # figure out the child's maximum forward path
        computeSlotSegPressures forwardSeg

        # either use the existing maximum, or use the child's forward pressure
        # plus one (for the forwardSeg itself)
        forwardPressure = Math.max(forwardPressure, 1 + forwardSeg.forwardPressure)
        i++
      seg.forwardPressure = forwardPressure
    return

  # Calculate seg.forwardCoord and seg.backwardCoord for the segment, where both values range
  # from 0 to 1. If the calendar is left-to-right, the seg.backwardCoord maps to "left" and
  # seg.forwardCoord maps to "right" (via percentage). Vice-versa if the calendar is right-to-left.
  #
  # The segment might be part of a "series", which means consecutive segments with the same pressure
  # who's width is unknown until an edge has been hit. `seriesBackwardPressure` is the number of
  # segments behind this one in the current series, and `seriesBackwardCoord` is the starting
  # coordinate of the first segment in the series.
  computeSlotSegCoords = (seg, seriesBackwardPressure, seriesBackwardCoord) ->
    forwardSegs = seg.forwardSegs
    i = undefined
    if seg.forwardCoord is `undefined` # not already computed
      unless forwardSegs.length

        # if there are no forward segments, this segment should butt up against the edge
        seg.forwardCoord = 1
      else

        # sort highest pressure first
        forwardSegs.sort compareForwardSlotSegs

        # this segment's forwardCoord will be calculated from the backwardCoord of the
        # highest-pressure forward segment.
        computeSlotSegCoords forwardSegs[0], seriesBackwardPressure + 1, seriesBackwardCoord
        seg.forwardCoord = forwardSegs[0].backwardCoord

      # calculate the backwardCoord from the forwardCoord. consider the series
      # available width for series
      seg.backwardCoord = seg.forwardCoord - (seg.forwardCoord - seriesBackwardCoord) / (seriesBackwardPressure + 1) # # of segments in the series

      # use this segment's coordinates to computed the coordinates of the less-pressurized
      # forward segments
      i = 0
      while i < forwardSegs.length
        computeSlotSegCoords forwardSegs[i], 0, seg.forwardCoord
        i++
    return

  # Find all the segments in `otherSegs` that vertically collide with `seg`.
  # Append into an optionally-supplied `results` array and return.
  computeSlotSegCollisions = (seg, otherSegs, results) ->
    results = results or []
    i = 0
    while i < otherSegs.length
      results.push otherSegs[i]  if isSlotSegCollision(seg, otherSegs[i])
      i++
    results

  # Do these segments occupy the same vertical space?
  isSlotSegCollision = (seg1, seg2) ->
    seg1.end > seg2.start and seg1.start < seg2.end

  # A cmp function for determining which forward segment to rely on more when computing coordinates.
  compareForwardSlotSegs = (seg1, seg2) ->
    seg2.forwardPressure - seg1.forwardPressure or (seg1.backwardCoord or 0) - (seg2.backwardCoord or 0) or compareSegs(seg1, seg2)

  paintSchedule: (newEvents) ->
    events = newEvents
    _renderSchedule()

  init: ->
    _init()

$(FB.init)

# Exposing only requried function
window.layOutDay = window.FB.paintSchedule
