sub init()
    m.top.functionName = "executeTask"
end sub

sub executeTask()
    udp = CreateObject("roDatagramSocket")
    msgPort = CreateObject("roMessagePort")
    udp.setMessagePort(msgPort)
    udp.getSocketAddress().setPort(8766) ' Listen for DuffLink broadcasts
    
    serverUrl = ""
    http = CreateObject("roUrlTransfer")
    http.SetCertificatesFile("common:/certs/ca-bundle.crt")
    http.InitClientCertificates()

    while true
        if serverUrl = ""
            ' Search for server via UDP
            msg = wait(1000, msgPort)
            if type(msg) = "roDatagramSocketEvent"
                data = msg.getString()
                json = ParseJSON(data)
                if json <> invalid and json.app = "DuffLink"
                    serverUrl = "http://" + json.ip + ":" + json.port.toStr() + "/api/state"
                end if
            end if
        else
            ' Poll the HTTP endpoint
            http.SetUrl(serverUrl)
            response = http.GetToString()
            
            if response <> ""
                json = ParseJSON(response)
                if json <> invalid
                    m.top.serverState = json
                    m.top.isOnline = true
                end if
            else
                ' Server lost, go back to scanning
                serverUrl = ""
                m.top.isOnline = false
            end if
            sleep(500) ' Poll twice a second
        end if
    end while
end sub