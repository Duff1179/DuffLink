sub init()
    m.top.functionName = "executeTask"
end sub

sub executeTask()
    print "[NetworkTask] executeTask() thread successfully started!"
    
    udp = CreateObject("roDatagramSocket")
    msgPort = CreateObject("roMessagePort")
    udp.setMessagePort(msgPort)
    
    directMode = LCase(m.top.connectionMode) = "propresenter"
    if not directMode
        addr = CreateObject("roSocketAddress")
        addr.setPort(8766)
        bindSuccess = udp.setAddress(addr)
        if not bindSuccess then print "[NetworkTask] ERROR: Failed to bind UDP to port 8766!"
        udp.notifyReadable(true)
        print "[NetworkTask] Listening for UDP broadcasts on port 8766..."
    end if
    
    serverUrl = ""
    http = CreateObject("roUrlTransfer")
    http.SetCertificatesFile("common:/certs/ca-bundle.crt")
    http.InitClientCertificates()
    
    while true
        ' Override the serverUrl if a manual one was provided
        if m.top.manualUrl <> "" and serverUrl <> m.top.manualUrl
            serverUrl = m.top.manualUrl
            print "[NetworkTask] Manual URL overriding UDP: "; serverUrl
        end if
        
        if directMode
            serverUrl = "http://" + m.top.directIp + ":" + m.top.directPort
            updateDirectState(http, serverUrl)
            sleep(1000)
        else if serverUrl = ""
            msg = wait(1000, msgPort)
            
            ' Correct BrightScript socket event
            if type(msg) = "roSocketEvent" 
                ' Verify the event belongs to our UDP socket and it has data
                if msg.getSocketID() = udp.getID() and udp.isReadable()
                    
                    ' Read up to 4096 bytes directly from the socket
                    data = udp.receiveStr(4096)
                    print "[NetworkTask] RECEIVED UDP DATA: "; data
                    
                    json = ParseJSON(data)
                    
                    if json <> invalid and json.app = "DuffLink"
                        portStr = box(json.port).toStr()
                        serverUrl = "http://" + json.ip + ":" + portStr + "/api/state"
                        print "[NetworkTask] Server URL set to: "; serverUrl
                    else
                        print "[NetworkTask] Ignored packet (invalid JSON or app name mismatch)"
                    end if
                end if
            end if
        else
            http.SetUrl(serverUrl)
            response = http.GetToString()
            if response <> ""
                json = ParseJSON(response)
                if json <> invalid
                    m.top.serverState = json
                    m.top.isOnline = true
                else
                    m.top.isOnline = false
                end if
            else
                print "[NetworkTask] HTTP Failed! Server disconnected?"
                serverUrl = ""
                m.top.isOnline = false
            end if
            sleep(500)
        end if
    end while
end sub

sub updateDirectState(http as Object, baseUrl as String)
    presRes = getJson(http, baseUrl + "/v1/presentation/active")
    slideIndexRes = getJson(http, baseUrl + "/v1/presentation/slide_index")
    slideStatusRes = getJson(http, baseUrl + "/v1/status/slide")
    timersRes = getJson(http, baseUrl + "/v1/timers/current")
    if presRes = invalid and slideIndexRes = invalid and slideStatusRes = invalid and timersRes = invalid
        m.top.isOnline = false
        return
    end if

    state = { presentationName: "", currentSlideText: "", nextSlideText: "", slideIndex: 0, slideCount: 0, clocks: [], serviceStartISO: serviceStartFromTimes(m.top.serviceTimes) }
    if presRes <> invalid and presRes.presentation <> invalid
        if presRes.presentation.id <> invalid and presRes.presentation.id.name <> invalid then state.presentationName = presRes.presentation.id.name
        if presRes.presentation.groups <> invalid
            for each group in presRes.presentation.groups
                if group.slides <> invalid then state.slideCount = state.slideCount + group.slides.count()
            end for
        end if
    end if
    if slideIndexRes <> invalid
        if type(slideIndexRes.presentation_index) = "roAssociativeArray"
            if slideIndexRes.presentation_index.index <> invalid then state.slideIndex = slideIndexRes.presentation_index.index
        else if slideIndexRes.index <> invalid
            state.slideIndex = slideIndexRes.index
        end if
    end if
    if slideStatusRes <> invalid
        if slideStatusRes.current <> invalid and slideStatusRes.current.text <> invalid then state.currentSlideText = slideStatusRes.current.text
        if slideStatusRes.next <> invalid and slideStatusRes.next.text <> invalid then state.nextSlideText = slideStatusRes.next.text
    end if
    if type(timersRes) = "roArray"
        for each timer in timersRes
            item = { name: "Timer", time: "", state: "stopped" }
            if timer.id <> invalid and timer.id.name <> invalid then item.name = timer.id.name
            if timer.time <> invalid then item.time = timer.time
            if timer.state <> invalid then item.state = LCase(timer.state.toStr())
            state.clocks.push(item)
        end for
    end if
    m.top.serverState = state
    m.top.isOnline = true
end sub

function getJson(http as Object, url as String) as Object
    http.SetUrl(url)
    response = http.GetToString()
    if response = "" then return invalid
    return ParseJSON(response)
end function

function serviceStartFromTimes(times as Object) as Object
    if times = invalid or times.count() = 0 then return invalid
    now = CreateObject("roDateTime")
    nowSeconds = now.AsSeconds()
    best = invalid
    bestDiff = 2147483647
    for each timeValue in times
        dateObj = CreateObject("roDateTime")
        dateObj.FromISO8601String(timeValue)
        diff = nowSeconds - dateObj.AsSeconds()
        if diff >= 0 and diff < bestDiff then best = timeValue : bestDiff = diff
    end for
    if best <> invalid then return best
    return times[0]
end function