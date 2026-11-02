sub RunUserInterface()
    screen = CreateObject("roSGScreen")
    m.port = CreateObject("roMessagePort")
    screen.setMessagePort(m.port)
    savedConfig = loadSavedConnectionConfig()
    m.screen = screen
    m.switchingScreens = false
    m.inSetup = true
    if savedConfig <> invalid and savedConfig.mode = "propresenter" and savedConfig.ip <> ""
        stageScreen = CreateObject("roSGScreen")
        stageScreen.setMessagePort(m.port)
        stageScene = stageScreen.CreateScene("ProStageDisplay")
        stageScene.connectionMode = "propresenter"
        stageScene.directIp = savedConfig.ip
        stageScene.directPort = savedConfig.port
        stageScene.savedServiceTimeDisplay = savedConfig.serviceTimeDisplay
        stageScene.autoReconnect = true
        stageScene.autoStart = true
        m.screen = stageScreen
        m.scene = stageScene
        m.inSetup = false
        stageScreen.show()
        stageScene.setFocus(true)
    else
        scene = screen.CreateScene("ConnectionSetup")
        m.scene = scene
        m.setupScene = scene
        screen.show()
    end if
    while(true)
        msg = wait(100, m.port)
        if m.inSetup and m.setupScene.connectionConfig <> invalid and not m.switchingScreens
            onConnectionConfig()
        else if not m.inSetup and m.scene.returnToSetup = true and not m.switchingScreens
            showSetupScreen(LCase(m.scene.connectionMode) = "propresenter" and m.scene.manualConfigure = false, m.scene.manualConfigure)
        end if
        msgType = type(msg)
        if msgType = "roSGScreenEvent"
            if msg.isScreenClosed()
                m.switchingScreens = false
            end if
        end if
    end while
end sub

sub onConnectionConfig()
    m.switchingScreens = true
    m.inSetup = false
    config = m.scene.connectionConfig
    saveConnectionConfig(config)
    setupScreen = m.screen
    stageScreen = CreateObject("roSGScreen")
    stageScreen.setMessagePort(m.port)
    sceneType = "StageDisplay"
    if config.mode = "propresenter" then sceneType = "ProStageDisplay"
    stageScene = stageScreen.CreateScene(sceneType)
    stageScene.connectionMode = config.mode
    if config.ip <> invalid then stageScene.directIp = config.ip
    if config.port <> invalid then stageScene.directPort = config.port
    if config.serviceTimes <> invalid then stageScene.serviceTimes = config.serviceTimes
    stageScene.autoStart = true
    m.screen = stageScreen
    m.scene = stageScene
    stageScreen.show()
    stageScene.setFocus(true)
    setupScreen.close()
    m.switchingScreens = false
end sub

function loadSavedConnectionConfig() as Object
    registry = CreateObject("roRegistrySection", "DuffLink")
    ip = registry.Read("connectionIp")
    port = registry.Read("connectionPort")
    mode = registry.Read("connectionMode")
    serviceTimesJSON = registry.Read("serviceTimes")
    displayTimesJSON = registry.Read("serviceTimeDisplay")
    if mode <> "propresenter" or ip = "" then return invalid
    if port = "" then port = "1025"
    serviceTimes = []
    if serviceTimesJSON <> "" then parsedTimes = ParseJSON(serviceTimesJSON) : if parsedTimes <> invalid then serviceTimes = parsedTimes
    displayTimes = []
    if displayTimesJSON <> "" then parsedDisplay = ParseJSON(displayTimesJSON) : if parsedDisplay <> invalid then displayTimes = parsedDisplay
    return { mode: mode, ip: ip, port: port, serviceTimes: serviceTimes, serviceTimeDisplay: displayTimes }
end function

sub saveConnectionConfig(config as Object)
    registry = CreateObject("roRegistrySection", "DuffLink")
    if config.mode <> invalid then registry.Write("connectionMode", config.mode)
    if config.ip <> invalid then registry.Write("connectionIp", config.ip)
    if config.port <> invalid then registry.Write("connectionPort", config.port)
    if config.serviceTimes <> invalid then registry.Write("serviceTimes", FormatJson(config.serviceTimes))
    if config.serviceTimeDisplay <> invalid
        registry.Write("serviceTimeDisplay", FormatJson(config.serviceTimeDisplay))
    end if
    registry.Flush()
end sub

sub showSetupScreen(autoDiscover, manualConfigure)
    stageScreen = m.screen
    setupScreen = CreateObject("roSGScreen")
    setupScreen.setMessagePort(m.port)
    setupScene = setupScreen.CreateScene("ConnectionSetup")
    m.switchingScreens = true
    m.inSetup = true
    m.screen = setupScreen
    m.scene = setupScene
    m.setupScene = setupScene
    setupScene.autoDiscover = autoDiscover
    setupScene.manualConfigure = manualConfigure
    savedConfig = loadSavedConnectionConfig()
    if savedConfig <> invalid
        setupScene.savedIp = savedConfig.ip
        setupScene.savedPort = savedConfig.port
        setupScene.savedServiceTimes = savedConfig.serviceTimeDisplay
        setupScene.savedServiceTimesISO = savedConfig.serviceTimes
    end if
    setupScreen.show()
    setupScene.setFocus(true)
    stageScreen.close()
    m.switchingScreens = false
end sub