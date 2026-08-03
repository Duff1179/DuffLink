sub init()
    m.presName = m.top.findNode("presName")
    m.slideCounter = m.top.findNode("slideCounter")
    m.liveDot = m.top.findNode("liveDot")
    
    m.currentText = m.top.findNode("currentText")
    m.nextText = m.top.findNode("nextText")
    
    m.slidesLeftValue = m.top.findNode("slidesLeftValue")
    m.timerValue = m.top.findNode("timerValue")
    m.timerName = m.top.findNode("timerName")
    m.serviceElapsedValue = m.top.findNode("serviceElapsedValue")
    
    m.offlineOverlay = m.top.findNode("offlineOverlay")
    
    ' Set up massive fonts (Mimics web CSS Clamps)
    fontMassive = CreateObject("roSGNode", "Font")
    fontMassive.uri = "font:LargeBoldSystemFont"
    fontMassive.size = 90
    m.currentText.font = fontMassive
    m.slidesLeftValue.font = fontMassive
    m.timerValue.font = fontMassive
    m.serviceElapsedValue.font = fontMassive
    
    fontLarge = CreateObject("roSGNode", "Font")
    fontLarge.uri = "font:MediumSystemFont"
    fontLarge.size = 65
    m.nextText.font = fontLarge

    m.serviceStartTime = ""
    m.serviceTimer = CreateObject("roSGNode", "Timer")
    m.serviceTimer.duration = 1
    m.serviceTimer.repeat = true
    m.serviceTimer.observeField("fire", "onServiceTick")
    
    m.networkTask = CreateObject("roSGNode", "NetworkTask")
    m.networkTask.observeField("serverState", "onStateUpdate")
    m.networkTask.observeField("isOnline", "onConnectionChange")
    m.networkTask.control = "RUN"
end sub

sub onConnectionChange()
    if m.networkTask.isOnline
        m.offlineOverlay.visible = false
        m.liveDot.color = "0x34D399FF" ' Green
    else
        m.offlineOverlay.visible = true
        m.liveDot.color = "0x7F1D1DFF" ' Red
    end if
end sub

sub onStateUpdate()
    s = m.networkTask.serverState
    
    if s.presentationName <> invalid and s.presentationName <> ""
        m.presName.text = UCase(s.presentationName)
    else
        m.presName.text = "NO PRESENTATION"
    end if

    total = 0
    idx = 0
    if s.slideCount <> invalid then total = s.slideCount
    if s.slideIndex <> invalid then idx = s.slideIndex
    
    if total > 0
        m.slideCounter.text = (idx + 1).toStr() + " / " + total.toStr()
        rem = total - idx - 1
        if rem < 0 then rem = 0
        m.slidesLeftValue.text = rem.toStr()
        if rem = 0 then m.slidesLeftValue.color = "0xFBBF24FF" else m.slidesLeftValue.color = "0x4F8EF7FF"
    else
        m.slideCounter.text = "— / —"
        m.slidesLeftValue.text = "—"
        m.slidesLeftValue.color = "0x4F8EF7FF"
    end if

    if s.currentSlideText <> invalid and s.currentSlideText <> ""
        m.currentText.text = s.currentSlideText
        m.currentText.color = "0xDDE1E7FF"
    else
        m.currentText.text = "Waiting for slides..."
        m.currentText.color = "0x374151FF"
    end if

    if s.nextSlideText <> invalid and s.nextSlideText <> ""
        m.nextText.text = s.nextSlideText
        m.nextText.color = "0x6B7280FF"
    else
        m.nextText.text = "—"
        m.nextText.color = "0x374151FF"
    end if

    ' RAW TIMER LOGIC
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
            m.timerValue.color = "0xF87171FF" ' RED 
        else
            m.timerValue.color = "0x34D399FF" ' GREEN
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
    if m_val < 10 then timeStr += "0" + m_val.toStr() else timeStr += m_val.toStr()
    timeStr += ":"
    if s_val < 10 then timeStr += "0" + s_val.toStr() else timeStr += s_val.toStr()
    
    m.serviceElapsedValue.text = timeStr
    
    if elapsed > 5400 ' 90 minutes
        m.serviceElapsedValue.color = "0xFBBF24FF" ' Yellow
    else
        m.serviceElapsedValue.color = "0xC9D1DBFF" ' White
    end if
end sub