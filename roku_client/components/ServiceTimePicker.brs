sub init()
    m.hours = ["", "1", "2", "3", "4", "5", "6", "7", "8", "9", "10", "11", "12"]
    m.minutes = ["00", "05", "10", "15", "20", "25", "30", "35", "40", "45", "50", "55"]
    m.ampm = ["AM", "PM"]
    m.hourIndex = [0, 0, 0]
    m.minuteIndex = [0, 0, 0]
    m.ampmIndex = [0, 0, 0]
    m.row = 0
    m.column = 0
    m.editing = false
    m.doneLabel = m.top.findNode("doneLabel")
    m.instructionsLabel = m.top.findNode("instructions")
    m.labels = []
    for row = 1 to 3
        m.labels.push({ hour: m.top.findNode("row" + row.toStr() + "Hour"), minute: m.top.findNode("row" + row.toStr() + "Minute"), ampm: m.top.findNode("row" + row.toStr() + "AmPm") })
    end for
    refresh()
    m.top.setFocus(true)
end sub

function onKeyEvent(key as String, press as Boolean) as Boolean
    if not press then return false
    key = LCase(key)
    if key = "up" or key = "down"
        if m.editing
            changeValue(key = "up")
        else
            moveRow(key = "up")
        end if
        refresh()
        return true
    else if key = "left" or key = "right"
        moveColumn(key = "right")
        refresh()
        return true
    else if key = "ok"
        if m.row = 3
            publishTimes()
        else
            m.editing = not m.editing
            refresh()
        end if
        return true
    else if key = "back"
        m.top.visible = false
        m.top.setFocus(false)
        return true
    end if
    return false
end function

sub moveRow(up)
    if up
        if m.row = 3 then m.row = 2 else if m.row > 0 then m.row = m.row - 1
    else
        if m.row < 3 then m.row = m.row + 1
    end if
    m.editing = false
end sub

sub moveColumn(right)
    if m.row = 3
        if not right then m.row = 2 : m.column = 2
        return
    end if
    m.editing = false
    if right
        if m.column < 2
            m.column = m.column + 1
        else if m.row < 2
            m.row = m.row + 1 : m.column = 0
        else
            m.row = 3 : m.column = 3
        end if
    else
        if m.column > 0
            m.column = m.column - 1
        else if m.row > 0
            m.row = m.row - 1 : m.column = 2
        end if
    end if
end sub

sub changeValue(increase)
    if m.column = 0
        m.hourIndex[m.row] = cycleIndex(m.hourIndex[m.row], m.hours.count(), increase)
    else if m.column = 1
        m.minuteIndex[m.row] = cycleIndex(m.minuteIndex[m.row], m.minutes.count(), increase)
    else
        m.ampmIndex[m.row] = 1 - m.ampmIndex[m.row]
    end if
end sub

function cycleIndex(current, size, increase) as Integer
    nextIndex = current
    if increase then nextIndex = nextIndex + 1 else nextIndex = nextIndex - 1
    if nextIndex < 0 then nextIndex = size - 1
    if nextIndex >= size then nextIndex = 0
    return nextIndex
end function

sub refresh()
    for index = 0 to 2
        if m.hourIndex[index] = 0
            m.labels[index].hour.text = "--"
            m.labels[index].minute.text = "--"
            m.labels[index].ampm.text = "--"
        else
            m.labels[index].hour.text = m.hours[m.hourIndex[index]]
            m.labels[index].minute.text = m.minutes[m.minuteIndex[index]]
            m.labels[index].ampm.text = m.ampm[m.ampmIndex[index]]
        end if
        m.labels[index].hour.color = fieldColor(index, 0)
        m.labels[index].minute.color = fieldColor(index, 1)
        m.labels[index].ampm.color = fieldColor(index, 2)
    end for
    if m.row = 3 then m.doneLabel.color = "0xFFFFFFFF" else m.doneLabel.color = "0x6B7280FF"
    if m.editing then m.instructionsLabel.text = "Press OK to confirm" else m.instructionsLabel.text = "Press OK to edit"
end sub

function fieldColor(index, column) as String
    if index <> m.row then return "0x6B7280FF"
    if column = m.column and m.editing then return "0xFFFF00FF"
    if column = m.column then return "0xFFFFFFFF"
    return "0x9CA3AFFF"
end function

sub publishTimes()
    times = []
    for index = 0 to 2
        if m.hourIndex[index] > 0
            times.push(m.hours[m.hourIndex[index]] + ":" + m.minutes[m.minuteIndex[index]] + " " + m.ampm[m.ampmIndex[index]])
        end if
    end for
    m.top.serviceTimes = times
    m.top.done = true
end sub
