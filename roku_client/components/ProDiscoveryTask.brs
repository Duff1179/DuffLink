sub init()
    m.top.functionName = "scanNetwork"
end sub

sub scanNetwork()
    m.top.scanning = true
    found = []
    connection = CreateObject("roDeviceInfo").GetConnectionInfo()
    ip = ""
    if connection <> invalid and connection.ip <> invalid then ip = connection.ip
    if ip = ""
        addresses = CreateObject("roDeviceInfo").GetIPAddrs()
        if addresses <> invalid
            for each name in addresses
                ip = addresses[name]
                exit for
            end for
        end if
    end if

    parts = ip.Split(".")
    if parts.count() <> 4
        m.top.results = found
        m.top.scanning = false
        return
    end if

    prefix = parts[0] + "." + parts[1] + "." + parts[2] + "."
    port = "1025"
    messagePort = CreateObject("roMessagePort")
    pending = {}

    for host = 1 to 254
        candidate = prefix + host.toStr()
        transfer = CreateObject("roUrlTransfer")
        transfer.SetPort(messagePort)
        transfer.SetUrl("http://" + candidate + ":" + port + "/version")
        transfer.RetainBodyOnError(true)
        if transfer.AsyncGetToString()
            pending[transfer.GetIdentity().toStr()] = { transfer: transfer, ip: candidate }
        end if
    end for

    deadline = CreateObject("roDateTime").AsSeconds() + 3
    while pending.count() > 0 and CreateObject("roDateTime").AsSeconds() < deadline
        event = wait(250, messagePort)
        if type(event) = "roUrlEvent"
            requestId = event.GetSourceIdentity().toStr()
            request = pending[requestId]
            if request <> invalid
                response = event.GetString()
                versionInfo = ParseJSON(response)
                if event.GetResponseCode() = 200 and versionInfo <> invalid
                    hostName = request.ip
                    if versionInfo.name <> invalid and versionInfo.name <> "" then hostName = versionInfo.name
                    found.push({ ip: request.ip, port: port, label: hostName + " (" + request.ip + ")" })
                end if
                pending.delete(requestId)
            end if
        end if
    end while

    for each requestId in pending
        pending[requestId].transfer.AsyncCancel()
    end for

    m.top.results = found
    m.top.scanning = false
end sub
