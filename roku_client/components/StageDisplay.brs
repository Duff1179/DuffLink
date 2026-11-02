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
    m.offlineTitle = m.top.findNode("offlineTitle")
    m.offlineSource = m.top.findNode("offlineSource")
    m.offlineAction = m.top.findNode("offlineAction")
    m.autoServiceTimePicker = m.top.findNode("autoServiceTimePicker")
    m.autoServiceTimePicker.observeField("done", "onAutoServiceTimeDone")
    m.autoServiceTimePicker.observeField("dismissed", "onAutoServiceTimeDismissed")
    m.autoReconnectConfirmed = false
    m.autoReconnectFailureShown = false
    m.autoReconnectDialog = invalid
    
    m.serviceStartTime = ""
    m.serviceTimer = m.top.findNode("serviceTimer")
    m.serviceTimer.observeField("fire", "onServiceTick")
    m.connectionWatchTimer = m.top.findNode("connectionWatchTimer")
    m.connectionWatchTimer.observeField("fire", "onConnectionWatch")
    m.retryTimer = m.top.findNode("retryTimer")
    m.retryTimer.observeField("fire", "onRetryTimeout")
    m.connectionStartedAt = CreateObject("roDateTime").AsSeconds()
    m.lastOnlineAt = 0
    m.disconnectPromptVisible = false
    m.retryInProgress = false
    m.retrySecondsRemaining = 5
    m.connectionWatchTimer.control = "START"
    
    m.networkTask = m.top.findNode("networkTask")
    m.networkTask.observeField("serverState", "onStateUpdate")
    m.networkTask.observeField("isOnline", "onConnectionChange")
    m.networkTask.observeField("timedOut", "onTimeoutChange")
    m.networkTask.connectionMode = m.top.connectionMode
    m.networkTask.directIp = m.top.directIp
    m.networkTask.directPort = m.top.directPort
    if m.top.autoReconnect
        m.networkTask.serviceTimes = []
    else
        m.networkTask.serviceTimes = m.top.serviceTimes
    end if
    m.networkStarted = false
    m.top.ObserveField("connectionMode", "onConnectionModeChanged")
    m.top.ObserveField("autoStart", "onAutoStart")
    updateOfflineSource()
    if m.top.autoReconnect
        m.offlineOverlay.visible = true
        m.serviceElapsedValue.visible = false
        m.offlineTitle.text = "Automatically Reconnecting..."
        m.offlineSource.text = ""
        m.retryInProgress = true
        m.retrySecondsRemaining = 5
    else if m.top.autoStart and LCase(m.top.connectionMode) = "propresenter"
        m.offlineOverlay.visible = true
        m.serviceElapsedValue.visible = false
        m.offlineTitle.text = "Connecting to ProPresenter..."
        m.offlineSource.text = ""
    end if
    if m.top.autoStart then startNetworkTask()
    if m.top.autoReconnect then m.retryTimer.control = "START"
    
    ' Make sure the screen is listening for remote control presses
    m.top.setFocus(true) 
end sub

sub onConnectionModeChanged()
    m.networkTask.connectionMode = m.top.connectionMode
    updateOfflineSource()
end sub

sub updateOfflineSource()
    if LCase(m.top.connectionMode) = "propresenter"
        m.offlineSource.text = ""
        m.offlineAction.text = ""
    else
        m.offlineSource.text = "Make sure DuffLink is running on the host PC"
        m.offlineAction.text = "Press OK on your remote to enter IP manually"
    end if
end sub

sub onAutoStart()
    if m.top.autoStart then startNetworkTask()
end sub

sub startNetworkTask()
    if m.networkStarted then return
    m.networkTask.connectionMode = m.top.connectionMode
    m.networkTask.directIp = m.top.directIp
    m.networkTask.directPort = m.top.directPort
    if m.top.autoReconnect
        m.networkTask.serviceTimes = []
    else
        m.networkTask.serviceTimes = m.top.serviceTimes
    end if
    m.networkStarted = true
    print "[StageDisplay] Starting Network Task..."
    m.networkTask.control = "RUN"
end sub

sub onConnectionChange()
    if m.networkTask.isOnline = true
        m.lastOnlineAt = CreateObject("roDateTime").AsSeconds()
        m.offlineOverlay.visible = false
        if m.top.autoReconnect and not m.autoReconnectConfirmed
            m.serviceElapsedValue.visible = false
        else
            m.serviceElapsedValue.visible = true
        end if
        if m.retryInProgress
            m.retryInProgress = false
            m.retryTimer.control = "STOP"
        end if
        if m.disconnectPromptVisible
            if m.disconnectDialog <> invalid
                m.disconnectDialog.close = true
            end if
            m.top.dialog = invalid
            m.disconnectPromptVisible = false
        end if
        if m.top.autoReconnect and not m.autoReconnectConfirmed then showAutoReconnectedServiceTimes()
    else
        m.offlineOverlay.visible = true
        if LCase(m.top.connectionMode) = "propresenter"
            if m.retryInProgress
                m.serviceElapsedValue.visible = false
                m.offlineTitle.text = "Automatically Reconnecting..."
                m.offlineSource.text = ""
            else
                m.offlineTitle.text = ""
                m.offlineSource.text = ""
            end if
        end if
        if m.networkStarted and LCase(m.top.connectionMode) = "propresenter" and not m.retryInProgress then showDisconnectPrompt()
    end if
end sub

sub showAutoReconnectedServiceTimes()
    if m.autoServiceTimePicker.visible then return
    m.autoServiceTimePicker.savedServiceTimes = m.top.savedServiceTimeDisplay
    connectedIp = m.top.directIp
    if connectedIp = "" then connectedIp = m.networkTask.directIp
    m.autoServiceTimePicker.titleOverride = "Automatically Reconnected"
    m.autoServiceTimePicker.ipAddress = connectedIp
    m.autoServiceTimePicker.visible = true
    m.autoServiceTimePicker.setFocus(false)
    m.autoServiceTimePicker.setFocus(true)
end sub

sub onAutoServiceTimeDone()
    displayTimes = m.autoServiceTimePicker.serviceTimes
    isoTimes = []
    now = CreateObject("roDateTime")
    dateText = now.ToISOString().Left(10)
    for each timeValue in displayTimes
        parts = timeValue.Split(" ")
        clockParts = parts[0].Split(":")
        hourValue = clockParts[0].ToInt()
        if parts.count() > 1 and parts[1] = "PM" and hourValue < 12 then hourValue = hourValue + 12
        if parts.count() > 1 and parts[1] = "AM" and hourValue = 12 then hourValue = 0
        localTime = dateText + "T" + twoDigit(hourValue) + ":" + clockParts[1] + ":00"
        localDate = CreateObject("roDateTime")
        localDate.FromISO8601String(localTime)
        localDate.FromSeconds(localDate.AsSeconds() + now.GetTimeZoneOffset() * 60)
        isoTimes.push(localDate.ToISOString())
    end for

    registry = CreateObject("roRegistrySection", "DuffLink")
    registry.Write("connectionMode", "propresenter")
    registry.Write("connectionIp", m.top.directIp)
    registry.Write("connectionPort", m.top.directPort)
    registry.Write("serviceTimes", FormatJson(isoTimes))
    registry.Write("serviceTimeDisplay", FormatJson(displayTimes))
    registry.Flush()

    m.top.serviceTimes = isoTimes
    m.networkTask.serviceTimes = isoTimes
    m.autoReconnectConfirmed = true
    m.serviceElapsedValue.visible = true
    m.autoServiceTimePicker.visible = false
    m.autoServiceTimePicker.setFocus(false)
    m.top.setFocus(true)
end sub

sub onAutoServiceTimeDismissed()
    m.autoServiceTimePicker.visible = false
    m.autoServiceTimePicker.setFocus(false)
    m.top.setFocus(true)
end sub

function twoDigit(value as Integer) as String
    text = value.toStr()
    if text.Len() = 1 then text = "0" + text
    return text
end function

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
        
        if remaining < 5
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
        if LCase(key) = "back"
            m.top.returnToSetup = true
            return true
        end if
        ' If they press OK and the offline screen is currently visible
        if key = "OK" and m.offlineOverlay.visible = true
            if LCase(m.top.connectionMode) = "propresenter"
                if m.retryInProgress
                    m.retryInProgress = false
                    m.retryTimer.control = "STOP"
                end if
                showDisconnectPrompt()
            else
                showKeyboard()
            end if
            handled = true
        end if
    end if
    return handled
end function

sub showKeyboard()
    m.keyboardDialog = createObject("roSGNode", "KeyboardDialog")
    if m.networkTask.connectionMode = "propresenter"
        m.keyboardDialog.title = "Enter ProPresenter IP & Port (e.g. 192.168.1.1:1025)"
    else
        m.keyboardDialog.title = "Enter DuffLink IP & Port (e.g. 192.168.1.1:8765)"
    end if
    m.keyboardDialog.buttons = ["Connect", "Cancel"]
    m.keyboardDialog.ObserveField("buttonSelected", "onIpEntered")
    m.top.dialog = m.keyboardDialog
end sub

sub onIpEntered()
    if m.keyboardDialog.buttonSelected = 0 
        enteredIp = m.keyboardDialog.text
        m.keyboardDialog.close = true
        
        if enteredIp <> ""
            if m.networkTask.connectionMode = "propresenter"
                addressParts = enteredIp.Split(":")
                m.networkTask.directIp = addressParts[0]
                if addressParts.count() > 1 and addressParts[1] <> "" then m.networkTask.directPort = addressParts[1]
                m.top.directIp = m.networkTask.directIp
                m.top.directPort = m.networkTask.directPort
                registry = CreateObject("roRegistrySection", "DuffLink")
                registry.Write("connectionMode", "propresenter")
                registry.Write("connectionIp", m.top.directIp)
                registry.Write("connectionPort", m.top.directPort)
                registry.Flush()
            else
                m.networkTask.manualUrl = "http://" + enteredIp + "/api/state"
            end if
        end if
    else 
        ' They clicked Cancel
        m.keyboardDialog.close = true
    end if
    
    ' Give focus back to the main screen so the OK button still works
    m.top.setFocus(true)
end sub

sub onTimeoutChange()
    if m.networkTask.timedOut and LCase(m.top.connectionMode) = "propresenter"
        m.offlineOverlay.visible = true
        if m.retryInProgress
            m.serviceElapsedValue.visible = false
            m.offlineTitle.text = "Automatically Reconnecting..."
            m.offlineSource.text = ""
        else
            m.offlineTitle.text = ""
            m.offlineSource.text = ""
            showDisconnectPrompt()
        end if
    else
        if LCase(m.top.connectionMode) = "propresenter"
            if not m.retryInProgress
                m.offlineTitle.text = ""
                m.offlineSource.text = ""
            end if
        else
            m.offlineTitle.text = "Automatically Reconnecting..."
            m.offlineSource.text = ""
        end if
        if m.networkTask.isOnline then m.offlineOverlay.visible = false
    end if
end sub

sub showDisconnectPrompt()
    if LCase(m.top.connectionMode) <> "propresenter" then return
    if m.disconnectPromptVisible then return
    m.disconnectPromptVisible = true
    m.disconnectDialog = CreateObject("roSGNode", "Dialog")
    if m.top.autoReconnect and not m.autoReconnectConfirmed
        m.disconnectDialog.title = "Automatic Reconnect Failed"
        m.disconnectDialog.message = "Could not reconnect to the previously configured ProPresenter connection."
    else
        m.disconnectDialog.title = "Connection Disconnected"
        m.disconnectDialog.message = "The connection to the configured host was lost."
    end if
    m.disconnectDialog.buttons = ["Retry", "Reconfigure"]
    m.disconnectDialog.observeField("buttonSelected", "onDisconnectDialogButton")
    m.top.dialog = m.disconnectDialog
    m.disconnectDialog.setFocus(true)
end sub

sub onDisconnectDialogButton()
    if m.disconnectDialog = invalid then return
    if m.disconnectDialog.buttonSelected = 0
        m.disconnectDialog.close = true
        m.top.dialog = invalid
        m.disconnectPromptVisible = false
        m.disconnectDialog = invalid
        m.retryInProgress = true
        m.networkTask.timedOut = false
        m.networkTask.isOnline = false
        m.connectionStartedAt = CreateObject("roDateTime").AsSeconds()
        m.lastOnlineAt = 0
        m.offlineOverlay.visible = true
        m.serviceElapsedValue.visible = false
        m.offlineTitle.text = "Automatically Reconnecting..."
        m.retrySecondsRemaining = 5
        m.offlineSource.text = ""
        m.retryTimer.control = "START"
    else
        m.disconnectDialog.close = true
        m.top.dialog = invalid
        m.disconnectDialog = invalid
        m.disconnectPromptVisible = false
        m.retryInProgress = false
        m.retryTimer.control = "STOP"
        m.top.manualConfigure = true
        m.top.returnToSetup = true
    end if
end sub

sub onRetryTimeout()
    if m.retryInProgress
        if m.networkTask.isOnline
            m.retryInProgress = false
            m.retryTimer.control = "STOP"
            m.offlineOverlay.visible = false
        else
            m.retrySecondsRemaining = m.retrySecondsRemaining - 1
            if m.retrySecondsRemaining > 0
                m.offlineTitle.text = "Automatically Reconnecting..."
                m.offlineSource.text = ""
            else
                m.retryInProgress = false
                m.retryTimer.control = "STOP"
                showDisconnectPrompt()
            end if
        end if
    end if
end sub

sub showAutoReconnectFailure()
    if m.autoReconnectFailureShown then return
    m.autoReconnectFailureShown = true
    m.offlineTitle.text = "Automatic Reconnect Failed"
    m.offlineSource.text = "Could not reconnect to the previously configured ProPresenter connection."
    m.offlineAction.text = "Press OK to retry or manually configure the connection"
    m.offlineOverlay.visible = true
    m.autoReconnectDialog = CreateObject("roSGNode", "Dialog")
    m.autoReconnectDialog.title = "Automatic Reconnect Failed"
    m.autoReconnectDialog.message = "Could not reconnect to the previously configured ProPresenter connection."
    m.autoReconnectDialog.buttons = ["Retry", "Reconfigure"]
    m.autoReconnectDialog.observeField("buttonSelected", "onAutoReconnectDialogButton")
    m.top.dialog = m.autoReconnectDialog
    m.autoReconnectDialog.setFocus(true)
end sub

sub onAutoReconnectDialogButton()
    if m.autoReconnectDialog = invalid then return
    if m.autoReconnectDialog.buttonSelected = 0
        m.autoReconnectDialog.close = true
        m.top.dialog = invalid
        m.autoReconnectFailureShown = false
        m.autoReconnectDialog = invalid
        m.connectionStartedAt = CreateObject("roDateTime").AsSeconds()
        m.lastOnlineAt = 0
        m.networkTask.timedOut = false
        m.retryInProgress = true
        m.retrySecondsRemaining = 5
        m.offlineTitle.text = "Automatically Reconnecting..."
        m.offlineSource.text = ""
        m.offlineOverlay.visible = true
        m.retryTimer.control = "START"
        m.top.setFocus(true)
    else
        m.autoReconnectDialog.close = true
        m.top.dialog = invalid
        m.autoReconnectDialog = invalid
        m.top.manualConfigure = true
        m.top.returnToSetup = true
    end if
end sub

sub showManualReconnectKeyboard()
    m.manualReconnectDialog = CreateObject("roSGNode", "KeyboardDialog")
    m.manualReconnectDialog.title = "Review ProPresenter IP & Port"
    m.manualReconnectDialog.text = m.top.directIp + ":" + m.top.directPort
    m.manualReconnectDialog.buttons = ["Connect", "Cancel"]
    m.manualReconnectDialog.observeField("buttonSelected", "onManualReconnectEntered")
    m.top.dialog = m.manualReconnectDialog
    m.manualReconnectDialog.setFocus(true)
end sub

sub onManualReconnectEntered()
    if m.manualReconnectDialog.buttonSelected = 0
        address = m.manualReconnectDialog.text.Trim()
        if address <> ""
            addressParts = address.Split(":")
            m.top.directIp = addressParts[0]
            if addressParts.count() > 1 and addressParts[1] <> "" then m.top.directPort = addressParts[1]
            m.networkTask.directIp = m.top.directIp
            m.networkTask.directPort = m.top.directPort
            registry = CreateObject("roRegistrySection", "DuffLink")
            registry.Write("connectionMode", "propresenter")
            registry.Write("connectionIp", m.top.directIp)
            registry.Write("connectionPort", m.top.directPort)
            registry.Flush()
            m.top.autoReconnect = false
            m.autoReconnectFailureShown = false
            m.connectionStartedAt = CreateObject("roDateTime").AsSeconds()
            m.lastOnlineAt = 0
            m.networkTask.timedOut = false
            m.retryInProgress = true
            m.retrySecondsRemaining = 5
            m.offlineTitle.text = "Automatically Reconnecting..."
            m.offlineSource.text = ""
            m.offlineOverlay.visible = true
            m.retryTimer.control = "START"
        end if
    end if
    m.manualReconnectDialog.close = true
    m.top.dialog = invalid
    m.top.setFocus(true)
end sub

sub onConnectionWatch()
    if LCase(m.top.connectionMode) <> "propresenter" or m.networkTask.isOnline then return
    currentTime = CreateObject("roDateTime").AsSeconds()
    referenceTime = m.lastOnlineAt
    if referenceTime = 0 then referenceTime = m.connectionStartedAt
    if currentTime - referenceTime >= 5 and not m.retryInProgress
        m.offlineTitle.text = ""
        m.offlineSource.text = ""
        m.offlineOverlay.visible = true
        showDisconnectPrompt()
    end if
end sub