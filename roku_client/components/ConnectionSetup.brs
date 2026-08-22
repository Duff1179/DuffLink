sub init()
    m.dufflinkOption = m.top.findNode("dufflinkOption")
    m.proPresenterOption = m.top.findNode("proPresenterOption")
    m.proDiscoveryTask = m.top.findNode("proDiscoveryTask")
    m.proDiscoveryTask.ObserveField("results", "onDiscoveryResults")
    m.discoveryStarted = false
    m.serviceTimePicker = m.top.findNode("serviceTimePicker")
    m.serviceTimePicker.ObserveField("done", "onTimePickerDone")
    m.serviceTimePicker.ObserveField("dismissed", "onTimePickerDismissed")
    m.top.ObserveField("autoDiscover", "onAutoDiscover")
    m.selected = 0
    refreshSelection()
    m.top.setFocus(true)
end sub

sub onShow()
    m.top.setFocus(true)
    if m.top.autoDiscover then startProDiscovery()
end sub

sub onAutoDiscover()
    if m.top.autoDiscover then startProDiscovery()
end sub

function onKeyEvent(key as String, press as Boolean) as Boolean
    if not press then return false
    key = LCase(key)
    if key = "up" or key = "down"
        m.selected = 1 - m.selected
        refreshSelection()
        return true
    else if key = "ok"
        if m.selected = 0
            m.top.connectionConfig = { mode: "dufflink", ip: "", port: "8765", serviceTimes: [] }
        else
            startProDiscovery()
        end if
        return true
    end if
    return false
end function

sub refreshSelection()
    m.dufflinkOption.color = "0x6B7280FF"
    m.proPresenterOption.color = "0x6B7280FF"
    if m.selected = 0 then m.dufflinkOption.color = "0xFFFFFFFF" else m.proPresenterOption.color = "0xFFFFFFFF"
end sub

sub showIpDialog()
    m.dialog = CreateObject("roSGNode", "KeyboardDialog")
    m.dialog.title = "ProPresenter IP address"
    m.dialog.buttons = ["Next", "Cancel"]
    m.dialog.ObserveField("buttonSelected", "onIpEntered")
    m.top.dialog = m.dialog
    m.dialog.setFocus(true)
end sub

sub onIpEntered()
    if m.dialog.buttonSelected <> 0 then closeDialog() : return
    m.directIp = m.dialog.text
    m.dialog.close = true
    if m.directIp = "" then return
    m.dialog = CreateObject("roSGNode", "KeyboardDialog")
    m.dialog.title = "ProPresenter port (default 1025)"
    m.dialog.text = "1025"
    m.dialog.buttons = ["Next", "Cancel"]
    m.dialog.ObserveField("buttonSelected", "onPortEntered")
    m.top.dialog = m.dialog
    m.dialog.setFocus(true)
end sub

sub onPortEntered()
    if m.dialog.buttonSelected <> 0 then closeDialog() : return
    m.directPort = m.dialog.text
    m.dialog.close = true
    if m.directPort = "" then m.directPort = "1025"
    showTimePicker()
end sub

sub onTimesEntered()
    times = []
    if m.dialog.buttonSelected = 0 and m.dialog.text <> ""
        now = CreateObject("roDateTime")
        dateText = now.ToISOString().Left(10)
        for each part in m.dialog.text.Split(",")
            clean = part.Trim()
            if clean <> "" then times.push(dateText + "T" + clean + ":00")
        end for
    end if
    m.dialog.close = true
    m.top.connectionConfig = { mode: "propresenter", ip: m.directIp, port: m.directPort, serviceTimes: times }
end sub

sub closeDialog()
    m.dialog.close = true
    m.top.setFocus(true)
end sub

sub startProDiscovery()
    if m.discoveryStarted then return
    m.discoveryStarted = true
    m.discoveryOptions = []
    m.discoveryReady = false
    m.discoveryDialog = CreateObject("roSGNode", "Dialog")
    m.discoveryDialog.title = "ProPresenter Discovery"
    m.discoveryDialog.message = "Scanning this network for ProPresenter..."
    m.discoveryDialog.buttons = ["Cancel"]
    m.discoveryDialog.ObserveField("buttonSelected", "onDiscoveryButton")
    m.top.dialog = m.discoveryDialog
    m.discoveryDialog.setFocus(true)
    m.proDiscoveryTask.control = "RUN"
end sub

sub onDiscoveryResults()
    if m.discoveryDialog = invalid then return
    m.discoveryOptions = m.proDiscoveryTask.results
    m.discoveryReady = true
    buttons = []
    for each option in m.discoveryOptions
        buttons.push(option.label)
    end for
    buttons.push("Enter IP Manually")
    m.discoveryDialog.title = "Select ProPresenter Endpoint"
    if m.discoveryOptions.count() = 0
        m.discoveryDialog.message = "No ProPresenter endpoints found."
    else
        m.discoveryDialog.message = "Choose an endpoint to connect to below:"
    end if
    m.discoveryDialog.buttons = buttons
    m.discoveryDialog.setFocus(true)
end sub

sub onDiscoveryButton()
    if not m.discoveryReady
        m.discoveryStarted = false
        m.discoveryDialog.close = true
        m.discoveryDialog = invalid
        m.top.dialog = invalid
        m.top.setFocus(true)
        return
    end if
    index = m.discoveryDialog.buttonSelected
    if index < 0 then return
    m.discoveryDialog.close = true
    m.discoveryStarted = false
    m.top.dialog = invalid
    if index < m.discoveryOptions.count()
        option = m.discoveryOptions[index]
        beginServiceTimes(option.ip, option.port)
    else
        showIpDialog()
    end if
end sub

sub beginServiceTimes(ip as String, port as String)
    m.directIp = ip
    m.directPort = port
    showTimePicker()
end sub

sub showTimePicker()
    m.serviceTimePicker.visible = true
    m.serviceTimePicker.setFocus(true)
end sub

sub onTimePickerDone()
    times = []
    now = CreateObject("roDateTime")
    dateText = now.ToISOString().Left(10)
    for each timeValue in m.serviceTimePicker.serviceTimes
        parts = timeValue.Split(" ")
        clockParts = parts[0].Split(":")
        hourValue = clockParts[0].ToInt()
        if parts[1] = "PM" and hourValue < 12 then hourValue = hourValue + 12
        if parts[1] = "AM" and hourValue = 12 then hourValue = 0
        localTime = dateText + "T" + twoDigit(hourValue) + ":" + clockParts[1] + ":00"
        localDate = CreateObject("roDateTime")
        localDate.FromISO8601String(localTime)
        localDate.FromSeconds(localDate.AsSeconds() + now.GetTimeZoneOffset() * 60)
        times.push(localDate.ToISOString())
    end for
    m.serviceTimePicker.visible = false
    m.serviceTimePicker.setFocus(false)
    m.top.connectionConfig = { mode: "propresenter", ip: m.directIp, port: m.directPort, serviceTimes: times }
end sub

sub onTimePickerDismissed()
    m.discoveryStarted = false
    m.top.setFocus(true)
end sub

function twoDigit(value as Integer) as String
    text = value.toStr()
    if text.Len() = 1 then text = "0" + text
    return text
end function

sub beginServiceTimesLegacy(ip as String, port as String)
    m.directIp = ip
    m.directPort = port
    m.dialog = CreateObject("roSGNode", "KeyboardDialog")
    m.dialog.title = "Enter Your Service Times (optional, e.g. 09:00,11:00)"
    m.dialog.buttons = ["Connect", "Skip"]
    m.dialog.ObserveField("buttonSelected", "onTimesEntered")
    m.top.dialog = m.dialog
    m.dialog.setFocus(true)
end sub