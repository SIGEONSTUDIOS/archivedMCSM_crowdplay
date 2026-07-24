require("CrowdPlay.lua")
require("CrowdPlayOverlay.lua")
require("MenuUtils.lua")
require("SaveLoad.lua")
require("UI_Legend.lua")
local mbCrowdPlayToggleActive = false
Menu_CrowdPlay_ToggleCrowdPlay = function()
  -- function num : 0_0 , upvalues : _ENV, mbCrowdPlayToggleActive
  if not CrowdPlay_IsConnected() then
    return 
  end
  mbCrowdPlayToggleActive = true
  if CrowdPlay_IsEnabled() then
    CrowdPlay_EndSession()
    mbCrowdPlayToggleActive = false
  else
    if IsPlatformWin10() then
      UI_Notify("popup_touchNotSupported_header", "popup_touchNotSupported_body", "Menu_CrowdPlay_Win10PostNotifyEngageCrowdPlay()")
    else
      Menu_CrowdPlay_EngageCrowdPlay()
    end
  end
  while Menu_CrowdPlay_ToggleActive() do
    WaitForNextFrame()
  end
  CrowdPlayOverlay_Update()
end

Menu_CrowdPlay_ToggleActive = function()
  -- function num : 0_1 , upvalues : mbCrowdPlayToggleActive
  return mbCrowdPlayToggleActive
end

Menu_CrowdPlay_Win10PostNotifyEngageCrowdPlay = function()
  -- function num : 0_2 , upvalues : _ENV, mbCrowdPlayToggleActive
  if not Input_UseCursor() or not InputHasTouch() then
    Menu_CrowdPlay_EngageCrowdPlay()
    CrowdPlayOverlay_Update()
  else
    mbCrowdPlayToggleActive = false
  end
end

Menu_CrowdPlay_EngageCrowdPlay = function()
  -- function num : 0_3 , upvalues : _ENV, mbCrowdPlayToggleActive
  local sessionCode, errCode = CrowdPlay_RequestSession()
  if errCode then
    Print("Crowd Play Session Request returned error (" .. errCode .. ")")
  else
    Print("Crowd Play Session Request succeeded with Room Code (" .. sessionCode .. ")")
  end
  mbCrowdPlayToggleActive = false
  CrowdPlayOverlay_Update()
end

Menu_CrowdPlay_DecisionAuthority = function()
  -- function num : 0_4 , upvalues : _ENV
  return (GetPreferences())["Crowd Play - Host Makes Choice"]
end

Menu_CrowdPlay_ToggleDecisionAuthority = function()
  -- function num : 0_5 , upvalues : _ENV
  local prefs = GetPreferences()
  prefs["Crowd Play - Host Makes Choice"] = not prefs["Crowd Play - Host Makes Choice"]
  SavePrefs()
  CreateEventLogEvent("CrowdPlay Decision Authority", prefs["Crowd Play - Host Makes Choice"] and "host" or "crowd", true)
end

Menu_CrowdPlay_OverlayInfo = function()
  -- function num : 0_6 , upvalues : _ENV
  return (GetPreferences())["Crowd Play - Enable Overlay Info"]
end

Menu_CrowdPlay_ToggleOverlayInfo = function()
  -- function num : 0_7 , upvalues : _ENV
  local prefs = GetPreferences()
  prefs["Crowd Play - Enable Overlay Info"] = not prefs["Crowd Play - Enable Overlay Info"]
  SavePrefs()
  CrowdPlayOverlay_Update()
end

local mbExitMessaging = false
local mbSkipChore = false
local mbBackgroundActive = false
local mbMessageFrameActive = false
local mbVideoFrameActive = false
local mCallbackArg = nil
local mbShowPostVideoTutorial = false
local mTutorialVideoController = nil
local mbTutorialVideoAborted = false
local mbTutorialOnly = false
local mbTutorialOnlyVideoShown = false
local mNumPlayers = 0
local CrowdPlayFrameActive = function()
  -- function num : 0_8 , upvalues : mbMessageFrameActive, mbVideoFrameActive
  return mbMessageFrameActive or mbVideoFrameActive
end

Callback_CrowdPlayMessaging_PreBeginPlayDone = Callback(true)
Callback_CrowdPlayMessaging_PreBeginPlayCancel = Callback(true)
Menu_CrowdPlayMessaging_SetDoneCallback = function(donefunction, argument)
  -- function num : 0_9 , upvalues : _ENV, mCallbackArg
  if not donefunction then
    donefunction = Menu_CrowdPlayMessaging_NoOp
  end
  Callback_CrowdPlayMessaging_PreBeginPlayDone:Add(donefunction)
  mCallbackArg = argument
end

Menu_CrowdPlayMessaging_RunDoneCallback = function()
  -- function num : 0_10 , upvalues : mbTutorialOnly, _ENV, mCallbackArg
  if not mbTutorialOnly then
    CreateEventLogEvent("CrowdPlay Session Started", "true", true)
  end
  mbTutorialOnly = false
  Callback_CrowdPlayMessaging_PreBeginPlayDone:Run(mCallbackArg)
end

Menu_CrowdPlayMessaging_SetCancelCallback = function(cancelfunction, argument)
  -- function num : 0_11 , upvalues : _ENV, mCallbackArg
  if not cancelfunction then
    cancelfunction = Menu_CrowdPlayMessaging_NoOp
  end
  Callback_CrowdPlayMessaging_PreBeginPlayCancel:Add(cancelfunction)
  mCallbackArg = argument
end

Menu_CrowdPlayMessaging_RunCancelCallback = function()
  -- function num : 0_12 , upvalues : mbTutorialOnly, _ENV, mCallbackArg
  if not mbTutorialOnly then
    CreateEventLogEvent("CrowdPlay Session Cancelled", "true", true)
  end
  mbTutorialOnly = false
  Callback_CrowdPlayMessaging_PreBeginPlayCancel:Run(mCallbackArg)
end

Menu_CrowdPlayMessaging_NoOp = function()
  -- function num : 0_13
end

Menu_CrowdPlayMessaging_LegendString = function()
  -- function num : 0_14 , upvalues : _ENV
  local legendtext = "<ui_legend_facebuttonDown.d3dtx:" .. kDefaultLegendButtonOffset .. "> " .. Menu_Text("legend_select") .. "  <ui_legend_facebuttonRight.d3dtx:" .. kDefaultLegendButtonOffset .. "> " .. Menu_Text("legend_cancel")
  return legendtext
end

Menu_CrowdPlayMessaging_LegendStringForProfileUser = function(pretext, alternativetext)
  -- function num : 0_15 , upvalues : _ENV
  local legendText = pretext or ""
  do
    if not PlatformGetUserName() then
      local username = not MenuUtils_PlatformIsUserSignedIn() or ""
    end
    username = (string.len)(username) >= 1 or PlatformGetUserName() or ""
    if (string.len)(username) > 0 then
      username = " [^color:#ffff99^" .. (username) .. "^color:#dfdfdf^]"
    end
    legendText = legendText .. username
    if not alternativetext then
      legendText = Menu_Text("legend_selectProfile")
    end
    return legendText
  end
end

Menu_CrowdPlayMessaging_WaitForDialogBox = function()
  -- function num : 0_16 , upvalues : _ENV
  while 1 do
    if DialogBox_IsActive() or AgentExists("ui_dialogBox.scene") then
      WaitForNextFrame()
      -- DECOMPILER ERROR at PC11: LeaveBlock: unexpected jumping out IF_THEN_STMT

      -- DECOMPILER ERROR at PC11: LeaveBlock: unexpected jumping out IF_STMT

    end
  end
end

Menu_CrowdPlayMessaging_PreBeginPlay = function(donecallback, episodeNum)
  -- function num : 0_17 , upvalues : _ENV, mbTutorialOnly
  Menu_CrowdPlayMessaging_SetDoneCallback(donecallback, episodeNum)
  mbTutorialOnly = false
  return Menu_CrowdPlayMessaging_ShowNextMessage()
end

Menu_CrowdPlayMessaging_Tutorial = function(donecallback, episodeNum)
  -- function num : 0_18 , upvalues : _ENV, mbTutorialOnly, mbTutorialOnlyVideoShown
  Menu_CrowdPlayMessaging_SetDoneCallback(donecallback, episodeNum)
  mbTutorialOnly = true
  mbTutorialOnlyVideoShown = false
  Menu_CrowdPlayMessaging_ShowNextMessage()
end

Menu_CrowdPlayMessaging_ShowNextMessage = function(bSkipShow)
  -- function num : 0_19 , upvalues : mbTutorialOnly, _ENV, mbExitMessaging, mbTutorialOnlyVideoShown, mbShowPostVideoTutorial
  if not bSkipShow then
    bSkipShow = false
  end
  if not mbTutorialOnly and (not CrowdPlay_IsSupported() or not CrowdPlay_IsConnected()) then
    mbExitMessaging = false
    return false
  end
  if mbExitMessaging and not bSkipShow then
    mbExitMessaging = false
    return false
  end
  local prefs = GetPreferences()
  local messageQueued = false
  if mbTutorialOnly or CrowdPlay_IsEnabled() then
    if (mbTutorialOnly and not mbTutorialOnlyVideoShown) or not prefs["Menu - Crowd Play Video Tutorial Shown"] then
      if not bSkipShow then
        mbShowPostVideoTutorial = true
        Menu_CrowdPlayMessaging_TutorialVideo()
      end
      messageQueued = true
    else
      if mbShowPostVideoTutorial then
        if not bSkipShow then
          mbShowPostVideoTutorial = false
          Menu_CrowdPlayMessaging_PostTutorial()
        end
        messageQueued = true
      else
        if not prefs["Menu - Crowd Play Decision Authority Tutorial Shown"] then
          if not bSkipShow then
            Menu_CrowdPlayMessaging_DecisionAuthority()
          end
          messageQueued = true
        else
          if not mbTutorialOnly and not prefs["Menu - Crowd Play Room Code Shown"] and not bSkipShow then
            Menu_CrowdPlayMessaging_JoinRoom()
          end
          messageQueued = true
        end
      end
    end
  end
  if mbExitMessaging then
    messageQueued = false
    mbExitMessaging = false
  end
  return messageQueued
end

Menu_CrowdPlayMessaging_IsMessagePending = function()
  -- function num : 0_20 , upvalues : _ENV
  return Menu_CrowdPlayMessaging_ShowNextMessage(true)
end

Menu_CrowdPlayMessaging_SetHeader = function()
  -- function num : 0_21 , upvalues : _ENV
  local isBetaTestEnabled = PropertyGet(GetPreferences(), "Beta Menu - Beta Test Crowd Play")
  if IsDebugBuild() and isBetaTestEnabled then
    AgentSetProperty("ui_telltaleCrowdPlay_textHeader", "Text String", "[ beta - ttg account req waived ]")
  else
    AgentSetProperty("ui_telltaleCrowdPlay_textHeader", "Text String", Menu_Text("crowdPlay_header"))
  end
end

Menu_CrowdPlayMessagingJoin_UpdateCrowdPlay = function(numServerPlayers, serverPlayers)
  -- function num : 0_22 , upvalues : _ENV, mbMessageFrameActive, mNumPlayers
  if not CrowdPlay_IsEnabled() then
    return 
  end
  local numHostPlayers = 1
  local numPlayers = numHostPlayers + tonumber(numServerPlayers)
  local maxPlayerDisplayIcons = 6
  local maxPlayerDecorator = 8
  local messagecontent = ""
  local messageformat = Menu_Text("crowdPlay_joinRoomMultiFormat")
  if not messageformat or messageformat == "" or messageformat == "crowdPlay_joinRoomMultiFormat" then
    messagecontent = messagecontent .. Menu_Text("crowdPlay_join") .. Menu_Text("crowdPlay_joinUrl")
    messagecontent = messagecontent .. "\n\n" .. Menu_Text("crowdPlay_joinRoomCode") .. CrowdPlay_GetSessionCode()
    messagecontent = messagecontent .. "\n\n" .. Menu_Text("crowdPlay_joinPeople") .. numPlayers .. "^^ <ui_telltaleCrowdPlay_crowdPlayRoomCount.d3dtx>"
  else
    messagecontent = (string.gsub)(messageformat, "{RoomCode}", CrowdPlay_GetSessionCode())
    messagecontent = (string.gsub)(messagecontent, "{RoomPopulation}", numPlayers)
  end
  AgentSetProperty("ui_telltaleCrowdPlay_textBody", "Text String", messagecontent)
  if not mbMessageFrameActive then
    ChoreGoToPauseAndKill("ui_telltaleCrowdPlay_playerIcons.chore", 0)
    return 
  end
  local playerTexturePrefix = "ui_telltaleCrowdPlay_player0"
  local playerDecorator = 0
  local playerTexture = playerTexturePrefix .. playerDecorator .. ".d3dtx"
  local playerIconPrefix = "ui_telltaleCrowdPlay_playerIcon0"
  local basePlayerTexture = "ui_telltaleCrowdPlay_player00.d3dtx"
  local mouseHostPlayerTexture = "ui_telltaleCrowdPlay_playerPC00.d3dtx"
  local playerIcon = 0
  for i = 1, numHostPlayers do
    playerTexture = playerTexturePrefix .. playerDecorator .. ".d3dtx"
    if playerDecorator == 0 and (IsPlatformPC() or IsPlatformMac()) and Input_UseCursor() then
      playerTexture = mouseHostPlayerTexture
    end
    ShaderOverrideTexture(playerIconPrefix .. playerIcon, basePlayerTexture, playerTexture)
    playerIcon = playerIcon + 1
  end
  if serverPlayers ~= nil then
    for id,player in pairs(serverPlayers) do
      if playerIcon < maxPlayerDisplayIcons then
        playerDecorator = tonumber(player.decorator)
        if playerDecorator < 1 or maxPlayerDecorator < playerDecorator then
          playerDecorator = 0
        end
        playerTexture = playerTexturePrefix .. playerDecorator .. ".d3dtx"
        if playerDecorator == 0 and (IsPlatformPC() or IsPlatformMac()) and Input_UseCursor() then
          playerTexture = mouseHostPlayerTexture
        end
        ShaderOverrideTexture(playerIconPrefix .. playerIcon, basePlayerTexture, playerTexture)
        AgentSetProperty(playerIconPrefix .. playerIcon, "Text String", player.name)
      end
      playerIcon = playerIcon + 1
    end
    if maxPlayerDisplayIcons < numPlayers then
      AgentSetProperty("ui_telltaleCrowdPlay_playerExtraText", "Text String", "+ " .. tostring(numPlayers - maxPlayerDisplayIcons))
    else
      if maxPlayerDisplayIcons < playerIcon then
        AgentSetProperty("ui_telltaleCrowdPlay_playerExtraText", "Text String", "+ " .. tostring(playerIcon - maxPlayerDisplayIcons))
      else
        AgentSetProperty("ui_telltaleCrowdPlay_playerExtraText", "Text String", "")
      end
    end
  end
  if maxPlayerDisplayIcons < numPlayers then
    ChoreGoToPauseAndKill("ui_telltaleCrowdPlay_playerIcons.chore", maxPlayerDisplayIcons + 1)
  else
    ChoreGoToPauseAndKill("ui_telltaleCrowdPlay_playerIcons.chore", numPlayers)
  end
  if numPlayers ~= mNumPlayers then
    SoundPlayEventByName("/Common/Menu/Main/CrowdPlay_JoinRoom")
    mNumPlayers = numPlayers
  end
end

Menu_CrowdPlayMessaging_JoinRoom = function()
  -- function num : 0_23 , upvalues : _ENV, mNumPlayers, mbBackgroundActive, mbMessageFrameActive, mbSkipChore
  print("Crowd Play Messaging - Room can be joined now")
  mNumPlayers = 0
  local connected = MenuUtils_PlatformIsConnectedToLicenseServer()
  local signed = MenuUtils_PlatformIsUserSignedIn()
  if MenuUtils_PlatformIsAgeRestricted() then
    Menu_CrowdPlayMessaging_WaitForDialogBox()
    UI_Notify("AgeRestrictedHeader", "AgeRestrictedMessage")
    Menu_CrowdPlayMessaging_JoinRoom_Retreat(true)
    return 
  end
  if not connected or not signed then
    Menu_CrowdPlayMessaging_WaitForDialogBox()
    UI_Notify("ConnectedHeader", "ConnectedMessage")
    Menu_CrowdPlayMessaging_JoinRoom_Retreat(true)
    return 
  end
  if not AgentExists("ui_telltaleCrowdPlay.scene") then
    MenuUtils_AddScene("ui_telltaleCrowdPlay.scene")
  else
    SceneHide("ui_telltaleCrowdPlay.scene", false)
  end
  Menu_CrowdPlayMessagingJoin_UpdateCrowdPlay(0, nil)
  Callback_CrowdPlayNumPlayers:Add(Menu_CrowdPlayMessagingJoin_UpdateCrowdPlay)
  AgentSetProperty("ui_telltaleCrowdPlay_textButton1", "Text String", Menu_Text("crowdPlay_startEpisode"))
  AgentSetProperty("ui_telltaleCrowdPlay_textButton1", "Button - Command", "Menu_CrowdPlayMessaging_JoinRoom_Advance()")
  AgentSetProperty("ui_telltaleCrowdPlay_textButton2", "Text String", Menu_Text("label_returnToEpisodes"))
  AgentSetProperty("ui_telltaleCrowdPlay_textButton2", "Button - Command", "Menu_CrowdPlayMessaging_JoinRoom_Retreat()")
  AgentSetProperty("ui_telltaleCrowdPlay_exitButton", "Button - Command", "Menu_CrowdPlayMessaging_JoinRoom_Retreat()")
  Menu_CrowdPlayMessaging_SetHeader()
  local menu = Menu_Create(Menu, "ui_telltaleCrowdPlay_parent")
  menu.modal = true
  menu.OnB = function(self, button, event)
    -- function num : 0_23_0 , upvalues : _ENV
    ChorePlayOnAgent("sfx_back.chore", self.agent, nil, false)
    Menu_CrowdPlayMessaging_JoinRoom_Retreat()
  end

  menu.OnWidgetInputChange = function(self, bUseCursor)
    -- function num : 0_23_1 , upvalues : _ENV
    if bUseCursor then
      AgentHide("ui_telltaleCrowdPlay_exitButton", false)
      AgentHide("ui_telltaleCrowdPlay_legend", true)
    else
      AgentHide("ui_telltaleCrowdPlay_exitButton", true)
      AgentHide("ui_telltaleCrowdPlay_legend", false)
      AgentSetProperty("ui_telltaleCrowdPlay_legend", "Text String", Menu_CrowdPlayMessaging_LegendString())
    end
  end

  menu.Show = function(self)
    -- function num : 0_23_2 , upvalues : _ENV, mbBackgroundActive, mbMessageFrameActive
    SceneHide("ui_telltaleCrowdPlay.scene", false)
    WidgetInputHandler_EnableInput(false)
    if not mbBackgroundActive then
      ChorePlayAndWait("ui_telltaleCrowdPlay_show.chore")
    end
    mbBackgroundActive = true
    if not mbMessageFrameActive then
      ChorePlayAndWait("ui_telltaleCrowdPlay_popupWindowShow.chore")
    end
    mbMessageFrameActive = true
    ChorePlayAndWait("ui_telltaleCrowdPlay_textShow.chore")
    Menu_CrowdPlayMessagingJoin_UpdateCrowdPlay(CrowdPlay_GetNumServerPlayers(), CrowdPlay_GetServerPlayers())
    WidgetInputHandler_EnableInput(true)
    if Input_UseCursor() then
      AgentHide("ui_telltaleCrowdPlay_exitButton", false)
      AgentHide("ui_telltaleCrowdPlay_legend", true)
    else
      AgentHide("ui_telltaleCrowdPlay_exitButton", true)
      AgentHide("ui_telltaleCrowdPlay_legend", false)
      AgentSetProperty("ui_telltaleCrowdPlay_legend", "Text String", Menu_CrowdPlayMessaging_LegendString())
    end
    local prefs = GetPreferences()
    prefs["Menu - Crowd Play Room Code Shown"] = true
    SavePrefs()
  end

  menu.Hide = function(self)
    -- function num : 0_23_3 , upvalues : _ENV, mbMessageFrameActive, mbSkipChore, mbBackgroundActive
    ChorePlayAndWait("ui_telltaleCrowdPlay_textHide.chore")
    Callback_CrowdPlayNumPlayers:Remove(Menu_CrowdPlayMessagingJoin_UpdateCrowdPlay)
    ChoreGoToPauseAndKill("ui_telltaleCrowdPlay_playerIcons.chore", 0)
    if not Menu_CrowdPlayMessaging_IsMessagePending() then
      ChorePlayAndWait("ui_telltaleCrowdPlay_popupWindowHide.chore")
      ChorePlayAndWait("ui_telltaleCrowdPlay_hide.chore")
      mbMessageFrameActive = false
      if not mbSkipChore then
        SceneHide("ui_telltaleCrowdPlay.scene", true)
        mbBackgroundActive = false
      else
        ThreadStart(function()
      -- function num : 0_23_3_0 , upvalues : _ENV, mbBackgroundActive
      SceneHide("ui_telltaleCrowdPlay.scene", true)
      mbBackgroundActive = false
    end
)
      end
    end
  end

  Menu_Push(menu)
end

Menu_CrowdPlayMessaging_JoinRoom_Advance = function()
  -- function num : 0_24 , upvalues : _ENV
  Menu_Pop()
  if not Menu_CrowdPlayMessaging_ShowNextMessage() then
    local prefs = GetPreferences()
    prefs["Crowd Play - Enable Overlay Info"] = true
    SavePrefs()
    Menu_CrowdPlayMessaging_RunDoneCallback()
  end
end

Menu_CrowdPlayMessaging_JoinRoom_Retreat = function(skipPop)
  -- function num : 0_25 , upvalues : mbExitMessaging, _ENV, mbMessageFrameActive
  mbExitMessaging = true
  if not skipPop then
    Menu_Pop()
  else
    if mbMessageFrameActive then
      ChorePlayAndWait("ui_telltaleCrowdPlay_popupWindowHide.chore")
      ChorePlayAndWait("ui_telltaleCrowdPlay_hide.chore")
      mbMessageFrameActive = false
    end
  end
  local prefs = GetPreferences()
  prefs["Menu - Crowd Play Room Code Shown"] = false
  SavePrefs()
  Menu_CrowdPlayMessaging_RunCancelCallback()
end

Menu_CrowdPlayMessaging_SecondChance = function()
  -- function num : 0_26 , upvalues : _ENV, mbBackgroundActive, mbMessageFrameActive, mbSkipChore
  print("Crowd Play Messaging - Second chance to enable crowd play")
  if not AgentExists("ui_telltaleCrowdPlay.scene") then
    MenuUtils_AddScene("ui_telltaleCrowdPlay.scene")
  else
    SceneHide("ui_telltaleCrowdPlay.scene", false)
  end
  local messagecontent = ""
  messagecontent = messagecontent .. Menu_Text("crowdPlay_Tutorial")
  AgentSetProperty("ui_telltaleCrowdPlay_textBody", "Text String", messagecontent)
  AgentSetProperty("ui_telltaleCrowdPlay_textButton1", "Text String", Menu_Text("label_yes"))
  AgentSetProperty("ui_telltaleCrowdPlay_textButton1", "Button - Command", "Menu_CrowdPlayMessaging_SecondChance_EnableAndAdvance()")
  AgentSetProperty("ui_telltaleCrowdPlay_textButton2", "Text String", Menu_Text("label_no"))
  AgentSetProperty("ui_telltaleCrowdPlay_textButton2", "Button - Command", "Menu_CrowdPlayMessaging_SecondChance_Advance()")
  AgentSetProperty("ui_telltaleCrowdPlay_exitButton", "Button - Command", "Menu_CrowdPlayMessaging_SecondChance_Retreat()")
  Menu_CrowdPlayMessaging_SetHeader()
  local menu = Menu_Create(Menu, "ui_telltaleCrowdPlay_parent")
  menu.modal = true
  menu.OnB = function(self, button, event)
    -- function num : 0_26_0 , upvalues : _ENV
    ChorePlayOnAgent("sfx_back.chore", self.agent, nil, false)
    Menu_CrowdPlayMessaging_SecondChance_Retreat()
  end

  menu.OnWidgetInputChange = function(self, bUseCursor)
    -- function num : 0_26_1 , upvalues : _ENV
    if bUseCursor then
      AgentHide("ui_telltaleCrowdPlay_exitButton", false)
      AgentHide("ui_telltaleCrowdPlay_legend", true)
    else
      AgentHide("ui_telltaleCrowdPlay_exitButton", true)
      AgentHide("ui_telltaleCrowdPlay_legend", false)
      AgentSetProperty("ui_telltaleCrowdPlay_legend", "Text String", Menu_CrowdPlayMessaging_LegendString())
    end
  end

  menu.Show = function(self)
    -- function num : 0_26_2 , upvalues : _ENV, mbBackgroundActive, mbMessageFrameActive
    SceneHide("ui_telltaleCrowdPlay.scene", false)
    WidgetInputHandler_EnableInput(false)
    if not mbBackgroundActive then
      ChorePlayAndWait("ui_telltaleCrowdPlay_show.chore")
    end
    mbBackgroundActive = true
    if not mbMessageFrameActive then
      ChorePlayAndWait("ui_telltaleCrowdPlay_popupWindowShow.chore")
    end
    mbMessageFrameActive = true
    ChorePlayAndWait("ui_telltaleCrowdPlay_textShow.chore")
    WidgetInputHandler_EnableInput(true)
    if Input_UseCursor() then
      AgentHide("ui_telltaleCrowdPlay_exitButton", false)
      AgentHide("ui_telltaleCrowdPlay_legend", true)
    else
      AgentHide("ui_telltaleCrowdPlay_exitButton", true)
      AgentHide("ui_telltaleCrowdPlay_legend", false)
      AgentSetProperty("ui_telltaleCrowdPlay_legend", "Text String", Menu_CrowdPlayMessaging_LegendString())
    end
    local prefs = GetPreferences()
    prefs["Menu - Crowd Play Tutorial Shown"] = true
    SavePrefs()
  end

  menu.Hide = function(self)
    -- function num : 0_26_3 , upvalues : _ENV, mbMessageFrameActive, mbSkipChore, mbBackgroundActive
    ChorePlayAndWait("ui_telltaleCrowdPlay_textHide.chore")
    if not Menu_CrowdPlayMessaging_IsMessagePending() then
      ChorePlayAndWait("ui_telltaleCrowdPlay_popupWindowHide.chore")
      ChorePlayAndWait("ui_telltaleCrowdPlay_hide.chore")
      mbMessageFrameActive = false
      if not mbSkipChore then
        SceneHide("ui_telltaleCrowdPlay.scene", true)
        mbBackgroundActive = false
      else
        ThreadStart(function()
      -- function num : 0_26_3_0 , upvalues : _ENV, mbBackgroundActive
      SceneHide("ui_telltaleCrowdPlay.scene", true)
      mbBackgroundActive = false
    end
)
      end
    end
  end

  Menu_Push(menu)
end

Menu_CrowdPlayMessaging_SecondChance_EnableAndAdvance = function()
  -- function num : 0_27 , upvalues : _ENV
  local wasEnabled = CrowdPlay_IsEnabled()
  local isEnabled = false
  if not wasEnabled then
    Menu_DLC("crowdPlayRequest")
    Menu_CrowdPlay_ToggleCrowdPlay()
    Menu_Pop()
    isEnabled = CrowdPlay_IsEnabled()
    if not isEnabled then
      UI_Notify("popup_crowdPlayRoomRequestError_header", "popup_crowdPlayRoomRequestError_message")
      return 
    else
      local prefs = GetPreferences()
      prefs["Menu - Crowd Play Room Code Shown"] = false
      SavePrefs()
      CrowdPlayOverlay_Update()
    end
  else
    do
      isEnabled = true
      if isEnabled then
        Menu_Pop()
        if not Menu_CrowdPlayMessaging_ShowNextMessage() then
          Menu_CrowdPlayMessaging_RunDoneCallback()
        end
      end
    end
  end
end

Menu_CrowdPlayMessaging_SecondChance_Advance = function()
  -- function num : 0_28 , upvalues : _ENV
  Menu_Pop()
  if not Menu_CrowdPlayMessaging_ShowNextMessage() then
    Menu_CrowdPlayMessaging_RunDoneCallback()
  end
end

Menu_CrowdPlayMessaging_SecondChance_Retreat = function()
  -- function num : 0_29 , upvalues : mbExitMessaging, _ENV
  mbExitMessaging = true
  Menu_Pop()
  Menu_CrowdPlayMessaging_RunCancelCallback()
end

Menu_CrowdPlayMessaging_DecisionAuthority = function()
  -- function num : 0_30 , upvalues : _ENV, mbBackgroundActive, mbMessageFrameActive, mbSkipChore
  print("Crowd Play Messaging - Who decides? choice")
  if not AgentExists("ui_telltaleCrowdPlay.scene") then
    MenuUtils_AddScene("ui_telltaleCrowdPlay.scene")
  else
    SceneHide("ui_telltaleCrowdPlay.scene", false)
  end
  local messagecontent = ""
  messagecontent = messagecontent .. Menu_Text("crowdPlay_hostDecides")
  AgentSetProperty("ui_telltaleCrowdPlay_textBody", "Text String", messagecontent)
  AgentSetProperty("ui_telltaleCrowdPlay_textButton1", "Text String", Menu_Text("label_crowdDecides"))
  AgentSetProperty("ui_telltaleCrowdPlay_textButton1", "Button - Command", "Menu_CrowdPlayMessaging_DecisionAuthority_CrowdAdvance()")
  AgentSetProperty("ui_telltaleCrowdPlay_textButton2", "Text String", Menu_Text("label_hostDecides"))
  AgentSetProperty("ui_telltaleCrowdPlay_textButton2", "Button - Command", "Menu_CrowdPlayMessaging_DecisionAuthority_HostAdvance()")
  AgentSetProperty("ui_telltaleCrowdPlay_exitButton", "Button - Command", "Menu_CrowdPlayMessaging_DecisionAuthority_Retreat()")
  Menu_CrowdPlayMessaging_SetHeader()
  local menu = Menu_Create(Menu, "ui_telltaleCrowdPlay_parent")
  menu.modal = true
  menu.OnB = function(self, button, event)
    -- function num : 0_30_0 , upvalues : _ENV
    ChorePlayOnAgent("sfx_back.chore", self.agent, nil, false)
    Menu_CrowdPlayMessaging_DecisionAuthority_Retreat()
  end

  menu.OnWidgetInputChange = function(self, bUseCursor)
    -- function num : 0_30_1 , upvalues : _ENV
    if bUseCursor then
      AgentHide("ui_telltaleCrowdPlay_exitButton", false)
      AgentHide("ui_telltaleCrowdPlay_legend", true)
    else
      AgentHide("ui_telltaleCrowdPlay_exitButton", true)
      AgentHide("ui_telltaleCrowdPlay_legend", false)
      AgentSetProperty("ui_telltaleCrowdPlay_legend", "Text String", Menu_CrowdPlayMessaging_LegendString())
    end
  end

  menu.Show = function(self)
    -- function num : 0_30_2 , upvalues : _ENV, mbBackgroundActive, mbMessageFrameActive
    SceneHide("ui_telltaleCrowdPlay.scene", false)
    WidgetInputHandler_EnableInput(false)
    if not mbBackgroundActive then
      ChorePlayAndWait("ui_telltaleCrowdPlay_show.chore")
    end
    mbBackgroundActive = true
    if not mbMessageFrameActive then
      ChorePlayAndWait("ui_telltaleCrowdPlay_popupWindowShow.chore")
    end
    mbMessageFrameActive = true
    ChorePlayAndWait("ui_telltaleCrowdPlay_logoShow.chore")
    ChorePlayAndWait("ui_telltaleCrowdPlay_textShow.chore")
    WidgetInputHandler_EnableInput(true)
    if Input_UseCursor() then
      AgentHide("ui_telltaleCrowdPlay_exitButton", false)
      AgentHide("ui_telltaleCrowdPlay_legend", true)
    else
      AgentHide("ui_telltaleCrowdPlay_exitButton", true)
      AgentHide("ui_telltaleCrowdPlay_legend", false)
      AgentSetProperty("ui_telltaleCrowdPlay_legend", "Text String", Menu_CrowdPlayMessaging_LegendString())
    end
    local prefs = GetPreferences()
    prefs["Menu - Crowd Play Decision Authority Tutorial Shown"] = true
    SavePrefs()
  end

  menu.Hide = function(self)
    -- function num : 0_30_3 , upvalues : _ENV, mbMessageFrameActive, mbSkipChore, mbBackgroundActive
    ChorePlayAndWait("ui_telltaleCrowdPlay_textHide.chore")
    ChorePlayAndWait("ui_telltaleCrowdPlay_logoHide.chore")
    if not Menu_CrowdPlayMessaging_IsMessagePending() then
      ChorePlayAndWait("ui_telltaleCrowdPlay_popupWindowHide.chore")
      ChorePlayAndWait("ui_telltaleCrowdPlay_hide.chore")
      mbMessageFrameActive = false
      if not mbSkipChore then
        SceneHide("ui_telltaleCrowdPlay.scene", true)
        mbBackgroundActive = false
      else
        ThreadStart(function()
      -- function num : 0_30_3_0 , upvalues : _ENV, mbBackgroundActive
      SceneHide("ui_telltaleCrowdPlay.scene", true)
      mbBackgroundActive = false
    end
)
      end
    end
  end

  Menu_Push(menu)
end

Menu_CrowdPlayMessaging_DecisionAuthority_HostAdvance = function()
  -- function num : 0_31 , upvalues : _ENV
  if Menu_CrowdPlay_DecisionAuthority() == false then
    Menu_CrowdPlay_ToggleDecisionAuthority()
  end
  CreateEventLogEvent("CrowdPlay Decision Authority", (GetPreferences())["Crowd Play - Host Makes Choice"] and "host" or "crowd", true)
  Menu_Pop()
  if not Menu_CrowdPlayMessaging_ShowNextMessage() then
    Menu_CrowdPlayMessaging_RunDoneCallback()
  end
end

Menu_CrowdPlayMessaging_DecisionAuthority_CrowdAdvance = function()
  -- function num : 0_32 , upvalues : _ENV
  if Menu_CrowdPlay_DecisionAuthority() == true then
    Menu_CrowdPlay_ToggleDecisionAuthority()
  end
  CreateEventLogEvent("CrowdPlay Decision Authority", (GetPreferences())["Crowd Play - Host Makes Choice"] and "host" or "crowd", true)
  Menu_Pop()
  if not Menu_CrowdPlayMessaging_ShowNextMessage() then
    Menu_CrowdPlayMessaging_RunDoneCallback()
  end
end

Menu_CrowdPlayMessaging_DecisionAuthority_Retreat = function()
  -- function num : 0_33 , upvalues : mbExitMessaging, _ENV
  mbExitMessaging = true
  Menu_Pop()
  Menu_CrowdPlayMessaging_RunCancelCallback()
end

Menu_CrowdPlayMessaging_TutorialVideo = function()
  -- function num : 0_34 , upvalues : _ENV, mTutorialVideoController, mbVideoFrameActive, mbBackgroundActive, mbMessageFrameActive, mbSkipChore, mbTutorialVideoAborted, mbTutorialOnly, mbTutorialOnlyVideoShown
  print("Crowd Play Messaging - Tutorial Video")
  if not AgentExists("ui_telltaleCrowdPlay.scene") then
    MenuUtils_AddScene("ui_telltaleCrowdPlay.scene")
  else
    SceneHide("ui_telltaleCrowdPlay.scene", false)
  end
  Menu_CrowdPlayMessaging_SetHeader()
  local menu = Menu_Create(Menu, "ui_telltaleCrowdPlay_parent")
  menu.modal = true
  menu.OnA = function(self, button, event)
    -- function num : 0_34_0 , upvalues : _ENV, mTutorialVideoController, mbVideoFrameActive
    ChorePlayOnAgent("sfx_press.chore", self.agent, nil, false)
    if ControllerIsPlaying(mTutorialVideoController) then
      mbVideoFrameActive = false
      ControllerKill(mTutorialVideoController)
      mTutorialVideoController = nil
      ChoreGoToPauseAndKill("ui_telltaleCrowdPlay_demonstration.chore", 0)
    end
  end

  menu.OnB = function(self, button, event)
    -- function num : 0_34_1
  end

  menu.OnWidgetInputChange = function(self, bUseCursor)
    -- function num : 0_34_2
  end

  menu.Show = function(self)
    -- function num : 0_34_3 , upvalues : _ENV, mbBackgroundActive, mbMessageFrameActive, mbVideoFrameActive, mTutorialVideoController
    SceneHide("ui_telltaleCrowdPlay.scene", false)
    WidgetInputHandler_EnableInput(false)
    if not mbBackgroundActive then
      ChorePlayAndWait("ui_telltaleCrowdPlay_show.chore")
    end
    mbBackgroundActive = true
    if mbMessageFrameActive then
      ChorePlayAndWait("ui_telltaleCrowdPlay_popupWindowHide.chore")
      mbMessageFrameActive = false
    end
    mbVideoFrameActive = true
    WidgetInputHandler_EnableInput(true)
    mTutorialVideoController = ChorePlay("ui_telltaleCrowdPlay_demonstration.chore")
    repeat
      WaitForNextFrame()
    until not mbVideoFrameActive or not ControllerIsPlaying(mTutorialVideoController)
    local prefs = GetPreferences()
    prefs["Menu - Crowd Play Video Tutorial Shown"] = true
    SavePrefs()
  end

  menu.Hide = function(self)
    -- function num : 0_34_4 , upvalues : mbVideoFrameActive, _ENV, mbSkipChore, mbBackgroundActive
    mbVideoFrameActive = false
    if not Menu_CrowdPlayMessaging_IsMessagePending() then
      ChorePlayAndWait("ui_telltaleCrowdPlay_hide.chore")
      if not mbSkipChore then
        SceneHide("ui_telltaleCrowdPlay.scene", true)
        mbBackgroundActive = false
      else
        ThreadStart(function()
      -- function num : 0_34_4_0 , upvalues : _ENV, mbBackgroundActive
      SceneHide("ui_telltaleCrowdPlay.scene", true)
      mbBackgroundActive = false
    end
)
      end
    end
  end

  mbTutorialVideoAborted = false
  Menu_Push(menu)
  if mbTutorialOnly then
    mbTutorialOnlyVideoShown = true
  end
  Menu_CrowdPlayMessaging_TutorialVideo_Advance()
end

Menu_CrowdPlayMessaging_TutorialVideo_Advance = function()
  -- function num : 0_35 , upvalues : mbTutorialVideoAborted, _ENV
  if not mbTutorialVideoAborted then
    mbTutorialVideoAborted = true
    Menu_Pop()
  end
  if not Menu_CrowdPlayMessaging_ShowNextMessage() then
    Menu_CrowdPlayMessaging_RunDoneCallback()
  end
end

Menu_CrowdPlayMessaging_PostTutorial = function()
  -- function num : 0_36 , upvalues : _ENV, mbTutorialOnly, mbBackgroundActive, mbMessageFrameActive, mbSkipChore
  print("Crowd Play Messaging - You may review the video tutorial.")
  if not AgentExists("ui_telltaleCrowdPlay.scene") then
    MenuUtils_AddScene("ui_telltaleCrowdPlay.scene")
  else
    SceneHide("ui_telltaleCrowdPlay.scene", false)
  end
  local messagecontent = ""
  if mbTutorialOnly then
    messagecontent = messagecontent .. Menu_Text("crowdPlay_introFinishGeneric")
  else
    messagecontent = messagecontent .. Menu_Text("crowdPlay_introFinish")
  end
  AgentSetProperty("ui_telltaleCrowdPlay_textBody", "Text String", messagecontent)
  if not mbTutorialOnly or not Menu_Text("label_returnToExtras") then
    AgentSetProperty("ui_telltaleCrowdPlay_textButton1", "Text String", Menu_Text("label_begin"))
    AgentSetProperty("ui_telltaleCrowdPlay_textButton1", "Button - Command", "Menu_CrowdPlayMessaging_PostTutorial_Advance()")
    AgentSetProperty("ui_telltaleCrowdPlay_textButton2", "Text String", Menu_Text("label_rewatchIntro"))
    AgentSetProperty("ui_telltaleCrowdPlay_textButton2", "Button - Command", "Menu_CrowdPlayMessaging_PostTutorial_Replay()")
    AgentSetProperty("ui_telltaleCrowdPlay_exitButton", "Button - Command", "Menu_CrowdPlayMessaging_PostTutorial_Retreat()")
    Menu_CrowdPlayMessaging_SetHeader()
    local menu = Menu_Create(Menu, "ui_telltaleCrowdPlay_parent")
    menu.modal = true
    menu.OnB = function(self, button, event)
    -- function num : 0_36_0 , upvalues : _ENV
    ChorePlayOnAgent("sfx_back.chore", self.agent, nil, false)
    Menu_CrowdPlayMessaging_PostTutorial_Retreat()
  end

    menu.OnWidgetInputChange = function(self, bUseCursor)
    -- function num : 0_36_1 , upvalues : _ENV
    if bUseCursor then
      AgentHide("ui_telltaleCrowdPlay_exitButton", false)
      AgentHide("ui_telltaleCrowdPlay_legend", true)
    else
      AgentHide("ui_telltaleCrowdPlay_exitButton", true)
      AgentHide("ui_telltaleCrowdPlay_legend", false)
      AgentSetProperty("ui_telltaleCrowdPlay_legend", "Text String", Menu_CrowdPlayMessaging_LegendString())
    end
  end

    menu.Show = function(self)
    -- function num : 0_36_2 , upvalues : _ENV, mbBackgroundActive, mbMessageFrameActive
    SceneHide("ui_telltaleCrowdPlay.scene", false)
    WidgetInputHandler_EnableInput(false)
    if not mbBackgroundActive then
      ChorePlayAndWait("ui_telltaleCrowdPlay_show.chore")
    end
    mbBackgroundActive = true
    if not mbMessageFrameActive then
      ChorePlayAndWait("ui_telltaleCrowdPlay_popupWindowShow.chore")
    end
    mbMessageFrameActive = true
    ChorePlayAndWait("ui_telltaleCrowdPlay_devicesImageShow.chore")
    ChorePlayAndWait("ui_telltaleCrowdPlay_textShow.chore")
    WidgetInputHandler_EnableInput(true)
    if Input_UseCursor() then
      AgentHide("ui_telltaleCrowdPlay_exitButton", false)
      AgentHide("ui_telltaleCrowdPlay_legend", true)
    else
      AgentHide("ui_telltaleCrowdPlay_exitButton", true)
      AgentHide("ui_telltaleCrowdPlay_legend", false)
      AgentSetProperty("ui_telltaleCrowdPlay_legend", "Text String", Menu_CrowdPlayMessaging_LegendString())
    end
  end

    menu.Hide = function(self)
    -- function num : 0_36_3 , upvalues : _ENV, mbMessageFrameActive, mbSkipChore, mbBackgroundActive
    ChorePlayAndWait("ui_telltaleCrowdPlay_textHide.chore")
    ChorePlayAndWait("ui_telltaleCrowdPlay_devicesImageHide.chore")
    if not Menu_CrowdPlayMessaging_IsMessagePending() then
      ChorePlayAndWait("ui_telltaleCrowdPlay_popupWindowHide.chore")
      ChorePlayAndWait("ui_telltaleCrowdPlay_hide.chore")
      mbMessageFrameActive = false
      if not mbSkipChore then
        SceneHide("ui_telltaleCrowdPlay.scene", true)
        mbBackgroundActive = false
      else
        ThreadStart(function()
      -- function num : 0_36_3_0 , upvalues : _ENV, mbBackgroundActive
      SceneHide("ui_telltaleCrowdPlay.scene", true)
      mbBackgroundActive = false
    end
)
      end
    end
  end

    Menu_Push(menu)
  end
end

Menu_CrowdPlayMessaging_PostTutorial_Advance = function()
  -- function num : 0_37 , upvalues : _ENV
  Menu_Pop()
  if not Menu_CrowdPlayMessaging_ShowNextMessage() then
    Menu_CrowdPlayMessaging_RunDoneCallback()
  end
end

Menu_CrowdPlayMessaging_PostTutorial_Replay = function()
  -- function num : 0_38 , upvalues : _ENV
  CreateEventLogEvent("CrowdPlay Rewatch Intro", "true", true)
  local prefs = GetPreferences()
  prefs["Menu - Crowd Play Video Tutorial Shown"] = false
  SavePrefs()
  Menu_Pop()
  if not Menu_CrowdPlayMessaging_ShowNextMessage() then
    Menu_CrowdPlayMessaging_RunDoneCallback()
  end
end

Menu_CrowdPlayMessaging_PostTutorial_Retreat = function()
  -- function num : 0_39 , upvalues : mbExitMessaging, _ENV
  mbExitMessaging = true
  Menu_Pop()
  Menu_CrowdPlayMessaging_RunCancelCallback()
end
