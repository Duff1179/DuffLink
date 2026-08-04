sub init()
    m.top.functionName = "executeTask"
end sub

sub executeTask()
    print "[NetworkTask] executeTask() thread successfully started!"
    
    udp = CreateObject("roDatagramSocket")
    msgPort = CreateObject("roMessagePort")
    udp.setMessagePort(msgPort)
    
    addr = CreateObject("roSocketAddress")
    addr.setPort(8766)
    
    bindSuccess = udp.setAddress(addr)
    if not bindSuccess
        print "[NetworkTask] ERROR: Failed to bind UDP to port 8766!"
    end if
    
    udp.notifyReadable(true)
    
    print "[NetworkTask] Listening for UDP broadcasts on port 8766..."
    
    serverUrl = ""
    http = CreateObject("roUrlTransfer")
    http.SetCertificatesFile("common:/certs/ca-bundle.crt")
    http.InitClientCertificates()
    
    while true
        if serverUrl = ""
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