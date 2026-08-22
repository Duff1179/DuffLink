sub init()
    m.presName = m.top.findNode("presName")
    m.slideCounter = m.top.findNode("slideCounter")
    m.currentText = m.top.findNode("currentText")
    m.nextText = m.top.findNode("nextText")
    m.slidesLeftValue = m.top.findNode("slidesLeftValue")
    m.timerValue = m.top.findNode("timerValue")
    m.timerName = m.top.findNode("timerName")
    m.serviceElapsedValue = m.top.findNode("serviceElapsedValue")
    m.offlineOverlay = m.top.findNode("offlineOverlay")
    
    m.serviceStartTime = ""
    m.serviceTimer = m.top.findNode("serviceTimer")
    m.serviceTimer.observeField("fire", "onServiceTick")
    
    m.networkTask = m.top.findNode("networkTask")
    m.networkTask.observeField("serverState", "onStateUpdate")
    m.networkTask.observeField("isOnline", "onConnectionChange")
    
    ' Safely start the task AFTER it is fully bound
    print "[StageDisplay] Starting Network Task..."
    m.networkTask.control = "RUN"
    
    ' Make sure the screen is listening for remote control presses
    m.top.setFocus(true) 
end sub

sub onConnectionChange()
    if m.networkTask.isOnline = true
        m.offlineOverlay.visible = false
    else
        m.offlineOverlay.visible = true
    end if
end sub

sub onStateUpdate()
    s = m.networkTask.serverState
    
    if s.presentationName <> invalid and s.presentationName <> ""
        m.presName.text = UCase(s.presentationName)
    else
        m.presName.text = "No Presentation"
    end if

    total = 0
    idx = 0
    if s.slideCount <> invalid then total = s.slideCount
    if s.slideIndex <> invalid then idx = s.slideIndex
    
    if total > 0
        m.slideCounter.text = (idx + 1).toStr() + " / " + total.toStr()
        
        remaining = total - idx - 1
        if remaining < 0 then remaining = 0
        m.slidesLeftValue.text = remaining.toStr()
        
        if remaining = 0 
            m.slidesLeftValue.color = "0xFBBF24FF" 
        else 
            m.slidesLeftValue.color = "0x4F8EF7FF"
        end if
    else
        m.slideCounter.text = "— / —"
        m.slidesLeftValue.text = "—"
        m.slidesLeftValue.color = "0x4F8EF7FF"
    end if

    if s.currentSlideText <> invalid and s.currentSlideText <> ""
        m.currentText.text = s.currentSlideText
        m.currentText.color = "0xDDE1E7FF"
    else
        m.currentText.text = ""
        m.currentText.color = "0x374151FF"
    end if

    if s.nextSlideText <> invalid and s.nextSlideText <> ""
        m.nextText.text = s.nextSlideText
        m.nextText.color = "0x6B7280FF"
    else
        m.nextText.text = ""
        m.nextText.color = "0x374151FF"
    end if

    activeTimer = invalid
    if s.clocks <> invalid
        for each clock in s.clocks
            if clock.state = "running" or clock.state = "overrunning"
                activeTimer = clock
                exit for
            end if
        end for
    end if

    if activeTimer <> invalid
        m.timerValue.text = activeTimer.time
        if activeTimer.name <> invalid then m.timerName.text = activeTimer.name else m.timerName.text = ""
        
        if activeTimer.state = "overrunning"
            m.timerValue.color = "0xF87171FF" 
        else
            m.timerValue.color = "0x34D399FF"
        end if
    else
        m.timerValue.text = "—"
        m.timerName.text = ""
        m.timerValue.color = "0xC9D1DBFF"
    end if

    if s.serviceStartISO <> invalid and s.serviceStartISO <> m.serviceStartTime
        m.serviceStartTime = s.serviceStartISO
        m.serviceTimer.control = "START"
    end if
end sub

sub onServiceTick()
    if m.serviceStartTime = "" return
    
    dateObj = CreateObject("roDateTime")
    dateObj.FromISO8601String(m.serviceStartTime)
    
    now = CreateObject("roDateTime")
    elapsed = now.AsSeconds() - dateObj.AsSeconds()
    
    if elapsed < 0
        m.serviceElapsedValue.text = "—"
        m.serviceElapsedValue.color = "0xC9D1DBFF"
        return
    end if
    
    h = Int(elapsed / 3600)
    m_val = Int((elapsed mod 3600) / 60)
    s_val = elapsed mod 60
    
    timeStr = ""
    if h > 0 then timeStr = h.toStr() + ":"
    
    if m_val < 10 
        timeStr = timeStr + "0" + m_val.toStr() 
    else 
        timeStr = timeStr + m_val.toStr()
    end if
    
    timeStr = timeStr + ":"
    
    if s_val < 10 
        timeStr = timeStr + "0" + s_val.toStr() 
    else 
        timeStr = timeStr + s_val.toStr()
    end if
    
    m.serviceElapsedValue.text = timeStr
    
    if elapsed > 5400
        m.serviceElapsedValue.color = "0xFBBF24FF"
    else
        m.serviceElapsedValue.color = "0xC9D1DBFF"
    end if
end sub

' ==========================================
' NEW: Keyboard Handling Functions
' ==========================================

' Catches remote control button presses
function onKeyEvent(key as String, press as Boolean) as Boolean
    handled = false
    if press then
        ' If they press OK and the offline screen is currently visible
        if key = "OK" and m.offlineOverlay.visible = true
            showKeyboard()
            handled = true
        end if
    end if
    return handled
end function

sub showKeyboard()
    m.keyboardDialog = createObject("roSGNode", "KeyboardDialog")
    ' Prompting for the port as well in case your desktop app uses dynamic ports
    m.keyboardDialog.title = "Enter DuffLink IP & Port (e.g. 192.168.1.1:8765)"
    m.keyboardDialog.buttons = ["Connect", "Cancel"]
    m.keyboardDialog.ObserveField("buttonSelected", "onIpEntered")
    m.top.dialog = m.keyboardDialog
end sub

sub onIpEntered()
    if m.keyboardDialog.buttonSelected = 0 
        enteredIp = m.keyboardDialog.text
        m.keyboardDialog.close = true
        
        if enteredIp <> ""
            ' Pass the exact typed IP/Port down to the background task
            m.networkTask.manualUrl = "http://" + enteredIp + "/api/state"
        end if
    else 
        ' They clicked Cancel
        m.keyboardDialog.close = true
    end if
    
    ' Give focus back to the main screen so the OK button still works
    m.top.setFocus(true)
end sub