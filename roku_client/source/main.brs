sub RunUserInterface()
    screen = CreateObject("roSGScreen")
    m.port = CreateObject("roMessagePort")
    screen.setMessagePort(m.port)
    scene = screen.CreateScene("ConnectionSetup")
    m.screen = screen
    m.scene = scene
    m.setupScene = scene
    m.switchingScreens = false
    m.inSetup = true
    screen.show()
    while(true)
        msg = wait(100, m.port)
        if m.inSetup and m.setupScene.connectionConfig <> invalid and not m.switchingScreens
            onConnectionConfig()
        else if not m.inSetup and m.scene.returnToSetup = true and not m.switchingScreens
            showSetupScreen(LCase(m.scene.connectionMode) = "propresenter")
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

sub showSetupScreen(autoDiscover)
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
    setupScreen.show()
    setupScene.setFocus(true)
    stageScreen.close()
    m.switchingScreens = false
end sub