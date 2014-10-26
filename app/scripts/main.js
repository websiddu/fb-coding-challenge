(function() {
  'use strict';
  window.FB = (function() {
    var EVENT_TEMPLATE, container, endTime, events, startTime, timeAixs, _buildEvtLevels, _compareAfterEvts, _compareEvts, _computeAfterEvts, _computeEvtCollisions, _computeEvtCoords, _computeEvtPressures, _emptyContainer, _evtCssStyles, _formatDate, _getAxisPointHTML, _init, _isEvtCollision, _render, _renderAxis, _renderSchedule, _setEvtsCoord;
    EVENT_TEMPLATE = "<span class=\"ellipsis event-title\">Sample Item</span>\n<span class=\"ellipsis small\">Sample Location</span>";
    events = [];
    container = document.querySelector('.schedule');
    timeAixs = document.querySelector('.times');
    startTime = new Date().setHours(9, 0, 0, 0);
    endTime = new Date().setHours(21, 0, 0, 0);
    _init = function() {
      return _renderAxis();
    };
    _renderAxis = function() {
      var axis, axisPoint, formatter, now, _results;
      _results = [];
      while (startTime <= endTime) {
        now = new Date(startTime);
        formatter = _formatDate(now);
        axis = _getAxisPointHTML(formatter);
        axisPoint = document.createElement('div');
        axisPoint.className = 'hour';
        axisPoint.innerHTML = axis;
        timeAixs.appendChild(axisPoint);
        _results.push(startTime += 3600000);
      }
      return _results;
    };
    _getAxisPointHTML = function(formatter) {
      var axisPointTemplate, halfHourTemplate, nextHalfHour, now;
      now = new Date(startTime);
      nextHalfHour = new Date(startTime + 1800000);
      halfHourTemplate = "<time class='small hour-half' datetime='" + (nextHalfHour.toString()) + "'>\n  " + formatter.hourHalf + "\n</time>";
      if (startTime === endTime) {
        halfHourTemplate = '';
      }
      axisPointTemplate = "<time datetime=\"" + (now.toString()) + "\">\n  " + formatter.time + " <small class=\"small\">" + formatter.ampm + "</small>\n</time>\n" + halfHourTemplate;
      return axisPointTemplate;
    };
    _renderSchedule = function() {
      events.sort(_compareEvts);
      _emptyContainer();
      _setEvtsCoord(events);
      return _render();
    };
    _emptyContainer = function() {
      return container.innerHTML = '';
    };
    _render = function() {
      var el, evt, i, _results;
      i = 0;
      _results = [];
      while (i < events.length) {
        evt = events[i];
        el = document.createElement('div');
        el.className = 'event animated fadeIn';
        el.innerHTML = EVENT_TEMPLATE;
        evt.el = el;
        el.setAttribute("style", _evtCssStyles(evt));
        container.appendChild(evt.el);
        _results.push(i++);
      }
      return _results;
    };
    _evtCssStyles = function(evt) {
      var height, left, top, width;
      top = "" + evt.start + "px";
      height = "" + (evt.end - evt.start) + "px";
      left = "" + (evt.leftCoord * 100) + "%";
      width = "" + ((evt.rightCoord - evt.leftCoord) * 100) + "%";
      if (evt.afterEvts.length !== 0) {
        width = (evt.afterEvts[0].rightCoord - evt.afterEvts[0].leftCoord) * 100 + "%";
      }
      return "top: " + top + "; left: " + left + "; width: " + width + "; height: " + height;
    };
    _setEvtsCoord = function(evts) {
      var evt, firstLevel, levels, _i, _j, _len, _len1;
      levels = _buildEvtLevels(evts);
      _computeAfterEvts(levels);
      firstLevel = levels[0];
      for (_i = 0, _len = firstLevel.length; _i < _len; _i++) {
        evt = firstLevel[_i];
        _computeEvtPressures(evt);
      }
      for (_j = 0, _len1 = firstLevel.length; _j < _len1; _j++) {
        evt = firstLevel[_j];
        _computeEvtCoords(evt, 0, 0);
      }
    };
    _buildEvtLevels = function(evts) {
      var evt, i, j, levels;
      levels = [];
      i = 0;
      while (i < evts.length) {
        evt = evts[i];
        j = 0;
        while (j < levels.length) {
          if (!_computeEvtCollisions(evt, levels[j]).length) {
            break;
          }
          j++;
        }
        evt.level = j;
        (levels[j] || (levels[j] = [])).push(evt);
        i++;
      }
      return levels;
    };
    _computeAfterEvts = function(levels) {
      var evt, i, j, k, level;
      i = 0;
      while (i < levels.length) {
        level = levels[i];
        j = 0;
        while (j < level.length) {
          evt = level[j];
          evt.afterEvts = [];
          k = i + 1;
          while (k < levels.length) {
            _computeEvtCollisions(evt, levels[k], evt.afterEvts);
            k++;
          }
          j++;
        }
        i++;
      }
    };
    _computeEvtPressures = function(evt) {
      var afterEvts, forwardEvt, i, pressure;
      afterEvts = evt.afterEvts;
      pressure = 0;
      if (evt.pressure === undefined) {
        i = 0;
        while (i < afterEvts.length) {
          forwardEvt = afterEvts[i];
          _computeEvtPressures(forwardEvt);
          pressure = Math.max(pressure, 1 + forwardEvt.pressure);
          i++;
        }
        evt.pressure = pressure;
      }
    };
    _computeEvtCoords = function(evt, seriesLeftPressure, seriesleftCoord) {
      var afterEvts, i;
      afterEvts = evt.afterEvts;
      if (evt.rightCoord === void 0) {
        if (!afterEvts.length) {
          evt.rightCoord = 1;
        } else {
          afterEvts.sort(_compareAfterEvts);
          _computeEvtCoords(afterEvts[0], seriesLeftPressure + 1, seriesleftCoord);
          evt.rightCoord = afterEvts[0].leftCoord;
        }
        evt.leftCoord = evt.rightCoord - (evt.rightCoord - seriesleftCoord) / (seriesLeftPressure + 1);
        i = 0;
        while (i < afterEvts.length) {
          _computeEvtCoords(afterEvts[i], 0, evt.rightCoord);
          i++;
        }
      }
    };
    _computeEvtCollisions = function(evt, otherEvts, results) {
      var i;
      results = results || [];
      i = 0;
      while (i < otherEvts.length) {
        if (_isEvtCollision(evt, otherEvts[i])) {
          results.push(otherEvts[i]);
        }
        i++;
      }
      return results;
    };
    _isEvtCollision = function(evt1, evt2) {
      return evt1.end > evt2.start && evt1.start < evt2.end;
    };
    _compareAfterEvts = function(evt1, evt2) {
      return evt2.pressure - evt1.pressure || (evt1.leftCoord || 0) - (evt2.leftCoord || 0);
    };
    _compareEvts = function(evt1, evt2) {
      return (evt1.start - evt2.start) || ((evt2.end - evt2.start) - (evt1.end - evt1.start));
    };
    _formatDate = function(date) {
      var ampm, hours, minutes;
      hours = date.getHours();
      minutes = date.getMinutes();
      ampm = (hours >= 12 ? "PM" : "AM");
      hours = hours % 12;
      hours = (hours ? hours : 12);
      minutes = (minutes < 10 ? "0" + minutes : minutes);
      return {
        ampm: ampm,
        time: "" + hours + ":" + minutes,
        hourHalf: "" + hours + ":" + (parseInt(minutes) + 30)
      };
    };
    return {
      paintSchedule: function(evts) {
        events = evts;
        _renderSchedule();
      },
      init: function() {
        return _init();
      }
    };
  })();

  FB.init();

  window.layOutDay = window.FB.paintSchedule;

  layOutDay([
    {
      start: 30,
      end: 150
    }, {
      start: 540,
      end: 600
    }, {
      start: 560,
      end: 620
    }, {
      start: 610,
      end: 670
    }
  ]);

}).call(this);
