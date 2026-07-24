local kScene = "ui_crowdPlay.scene"
local kOverlayAgents = {"ui_crowdPlay_overlayTextRoomCode", "ui_crowdPlay_overlayTextRoomCount", "ui_crowdPlay_overlayTextUrl", "ui_crowdPlay_overlayIcon"}
local kSpilloverPrefix = ""
local mScene, mGameScene = nil, nil
local mSuperScenes = {}
local mCrowdExpressions = {[1] = "thumbsup", [2] = "thumbsdown"}
local mCrowdExpressionQueues = {}
local mCrowdExpressionQueueLimits = {thumbsup = 0, thumbsdown = 0}
local mCrowdExpressionTimestamps = {}
local mNow = nil
local mExpressionTimeouts = {thumbsup = 5, thumbsdown = 5}
local mExpressionChoreStates = {thumbsup = "init", thumbsdown = "init"}
local mThumbsFrameShown = false
local mCrowdExpressionAdvanceChores = {}
local mNextThumbsUpPlayerIcon = 0
local mNextThumbsDownPlayerIcon = 0
local mPlayerIcons = 4
local mUpTotal = 0
local mDownTotal = 0
local mCrowdAgents = {"ui_crowdPlay_icon1", "ui_crowdPlay_icon2", "ui_crowdPlay_icon3", "ui_crowdPlay_icon4", "ui_crowdPlay_icon5", "ui_crowdPlay_icon6", "ui_crowdPlay_icon7", "ui_crowdPlay_icon8"}
local mDelayHealthChecks = false
local mConfirmRequestPending = false
local CreateAssets = function()
  -- function num : 0_0
end

local OnGameSceneOpen = function(scene)
  -- function num : 0_1 , upvalues : _ENV, mCrowdExpressionAdvanceChores, mExpressionChoreStates, mDelayHealthChecks, kScene, mCrowdExpressionQueues
  if not CrowdPlay_IsEnabled() then
    return 
  end
  mCrowdExpressionAdvanceChores.thumbsup = {[1] = "ui_crowdPlay_icon_upShow.chore", [2] = "ui_crowdPlay_icon_up1.chore", [3] = "ui_crowdPlay_icon_up2.chore", [4] = "ui_crowdPlay_icon_up3.chore"}
  mExpressionChoreStates.thumbsup = "ready"
  mCrowdExpressionAdvanceChores.thumbsdown = {[1] = "ui_crowdPlay_icon_downShow.chore", [2] = "ui_crowdPlay_icon_down1.chore", [3] = "ui_crowdPlay_icon_down2.chore", [4] = "ui_crowdPlay_icon_down3.chore"}
  mExpressionChoreStates.thumbsdown = "ready"
  mCrowdExpressionAdvanceChores.thumbsframe = {[1] = "ui_crowdPlay_thumbs_show.chore"}
  mExpressionChoreStates.thumbsframe = "ready"
  mDelayHealthChecks = true
  CrowdPlayOverlay_SetGameScene(scene)
  SceneAdd(kScene, "CrowdPlayOverlay_OnSceneAdd")
  CrowdPlayOverlay_ResetQueues(true)
  WaitForNextFrame()
  WaitForNextFrame()
  local bForceJustInTimeReset = false
  if mCrowdExpressionQueues.thumbsup ~= nil and (table.getn)(mCrowdExpressionQueues.thumbsup) > 0 then
    bForceJustInTimeReset = true
  end
  if mCrowdExpressionQueues.thumbsdown ~= nil and (table.getn)(mCrowdExpressionQueues.thumbsdown) > 0 then
    bForceJustInTimeReset = true
  end
  if bForceJustInTimeReset or CrowdPlayOverlay_CrowdAgentsVisible() then
    CrowdPlayOverlay_ResetQueues(true)
  end
  ThreadStart(CrowdPlayOverlay_DelayHealthChecks)
end

CrowdPlayOverlay_DelayHealthChecks = function()
  -- function num : 0_2 , upvalues : _ENV, mDelayHealthChecks
  Sleep(2)
  mDelayHealthChecks = false
  CrowdPlayOverlay_OnNewServerHealth()
end

local Init = function()
  -- function num : 0_3 , upvalues : _ENV, OnGameSceneOpen
  Callback_OnGameSceneOpen:Add(OnGameSceneOpen)
end

CrowdPlayOverlay_OnSceneAdd = function()
  -- function num : 0_4 , upvalues : mScene, _ENV, kScene
  mScene = SceneFind(kScene)
  local sceneAgent = SceneGetSceneAgent(kScene)
  CrowdPlayOverlay_Update()
end

CrowdPlayOverlay_Update = function()
  -- function num : 0_5 , upvalues : mScene, _ENV
  if mScene ~= nil then
    if CrowdPlay_IsEnabled() and (GetPreferences())["Crowd Play - Enable Overlay Info"] then
      local overlayVisible = not CrowdPlayOverlay_Superceded()
    end
    CrowdPlayOverlay_SetOverlayVisible(overlayVisible)
    if CrowdPlay_IsEnabled() then
      CrowdPlayOverlay_OnNewRoomCode()
      CrowdPlayOverlay_OnNewPlayerCount(CrowdPlay_GetNumServerPlayers())
      AgentSetProperty("ui_crowdPlay_overlayTextUrl", "Text Dialog 2.0 Node Name", "crowdPlay_joinURL")
      Callback_CrowdPlayRefresh:Remove(CrowdPlayOverlay_Refresh)
      Callback_CrowdPlayRefresh:Add(CrowdPlayOverlay_Refresh)
      Callback_CrowdPlayNumPlayers:Remove(CrowdPlayOverlay_OnNewPlayerCount)
      Callback_CrowdPlayNumPlayers:Add(CrowdPlayOverlay_OnNewPlayerCount)
      Callback_CrowdPlayServerHealth:Remove(CrowdPlayOverlay_OnNewServerHealth)
      Callback_CrowdPlayServerHealth:Add(CrowdPlayOverlay_OnNewServerHealth)
    end
  end
end

CrowdPlayOverlay_Superceded = function()
  -- function num : 0_6 , upvalues : _ENV, mSuperScenes
  for i,superScene in ipairs(mSuperScenes) do
    if SceneIsActive(superScene) and not SceneIsHidden(superScene) then
      return true
    end
  end
  return false
end

CrowdPlayOverlay_SetSuperScene = function(scene)
  -- function num : 0_7 , upvalues : mSuperScenes, _ENV
  if scene == nil then
    mSuperScenes = {}
    return 
  end
  for i,superScene in ipairs(mSuperScenes) do
    if superScene == scene then
      return 
    end
  end
  ;
  (table.insert)(mSuperScenes, scene)
end

CrowdPlayOverlay_SetOverlayVisible = function(bShow)
  -- function num : 0_8 , upvalues : _ENV, kOverlayAgents
  for i,agent in ipairs(kOverlayAgents) do
    if AgentExists(agent) then
      AgentHide(agent, not bShow)
    end
  end
end

CrowdPlayOverlay_Refresh = function()
  -- function num : 0_9 , upvalues : _ENV
  if not CrowdPlay_IsExpressionAllowed() then
    CrowdPlayOverlay_ResetQueues()
  end
end

CrowdPlayOverlay_OnNewServerHealth = function()
  -- function num : 0_10 , upvalues : _ENV
  CrowdPlayOverlay_OnNewRoomCode()
end

CrowdPlayOverlay_OnNewRoomCode = function()
  -- function num : 0_11 , upvalues : mConfirmRequestPending, _ENV, mDelayHealthChecks
  if mConfirmRequestPending then
    return 
  end
  local roomText = CrowdPlay_GetSessionCode()
  if not mDelayHealthChecks and not CrowdPlay_GetServerHealthy() then
    if IsDebugBuild() then
      roomText = "^color:red^^glyphScale:0.4^[X]^^ " .. roomText
    end
    CrowdPlayOverlay_CheckForAbort()
  end
  AgentSetProperty("ui_crowdPlay_overlayTextRoomCode", kText, roomText)
end

CrowdPlayOverlay_OnNewPlayerCount = function(numPlayers, players, useTotals, totals)
  -- function num : 0_12 , upvalues : mConfirmRequestPending, _ENV, mNow, mCrowdExpressionQueueLimits, kSpilloverPrefix
  if mConfirmRequestPending then
    return 
  end
  local crowdSize = numPlayers + CrowdPlay_GetNumHostPlayers()
  AgentSetProperty("ui_crowdPlay_overlayTextRoomCount", kText, tostring(crowdSize))
  CrowdPlay_ReportCrowdSize(crowdSize)
  if not CrowdPlay_IsExpressionAllowed() then
    CrowdPlayOverlay_ResetQueues()
    return 
  end
  mNow = GetTotalTime()
  if CrowdPlay_GetVersion() == nil or CrowdPlay_GetVersion() == "" then
    mCrowdExpressionQueueLimits.thumbsup = 4
    mCrowdExpressionQueueLimits.thumbsdown = 4
    kSpilloverPrefix = "+ "
  end
  if useTotals then
    CrowdPlayOverlay_OnNewTotalsCount(numPlayers, totals)
  else
    CrowdPlayOverlay_OnNewIndividualsCount(numPlayers, players)
  end
end

CrowdPlayOverlay_OnNewTotalsCount = function(numPlayers, totals)
  -- function num : 0_13 , upvalues : mUpTotal, mDownTotal, mThumbsFrameShown, _ENV, kSpilloverPrefix, mExpressionChoreStates
  mUpTotal = totals.thumbsup or 0
  mDownTotal = totals.thumbsdown or 0
  if mThumbsFrameShown then
    if mUpTotal > 0 then
      AgentSetProperty("ui_crowdPlay_extraTextUp", "Text String", kSpilloverPrefix .. mUpTotal)
    else
      AgentSetProperty("ui_crowdPlay_extraTextUp", "Text String", "")
    end
    if mDownTotal > 0 then
      AgentSetProperty("ui_crowdPlay_extraTextDown", "Text String", kSpilloverPrefix .. mDownTotal)
    else
      AgentSetProperty("ui_crowdPlay_extraTextDown", "Text String", "")
    end
  end
  -- DECOMPILER ERROR at PC56: Unhandled construct in 'MakeBoolean' P1

  if mExpressionChoreStates.thumbsframe == "ready" and mThumbsFrameShown and mUpTotal + mDownTotal < 1 then
    mExpressionChoreStates.thumbsframe = "hiding"
    ThreadStart(function()
    -- function num : 0_13_0 , upvalues : _ENV, mThumbsFrameShown, mExpressionChoreStates
    ChorePlay("ui_crowdPlay_extraText_hide.chore")
    ChorePlayAndWait("ui_crowdPlay_thumbs_hide.chore")
    mThumbsFrameShown = false
    mExpressionChoreStates.thumbsframe = "ready"
  end
)
  end
  if mUpTotal + mDownTotal > 0 then
    mThumbsFrameShown = true
    mExpressionChoreStates.thumbsframe = "showing"
    ThreadStart(function()
    -- function num : 0_13_1 , upvalues : _ENV, mExpressionChoreStates
    ChorePlay("ui_crowdPlay_extraText_show.chore")
    ChorePlayAndWait("ui_crowdPlay_thumbs_show.chore")
    if mExpressionChoreStates.thumbsframe ~= "resetting" then
      AgentSetProperty("ui_crowdPlay_ratingsThumbs", "Render Constant Alpha", 1)
      AgentHide("ui_crowdPlay_ratingsThumbs", false)
      AgentHide("ui_crowdPlay_extraTextUp", false)
      AgentHide("ui_crowdPlay_extraTextDown", false)
      mExpressionChoreStates.thumbsframe = "ready"
    end
  end
)
  end
end

CrowdPlayOverlay_OnNewIndividualsCount = function(numPlayers, players)
  -- function num : 0_14 , upvalues : _ENV, mCrowdExpressions, mCrowdExpressionQueues, mNow
  local queueExpressor = nil
  if players == nil then
    players = {}
  end
  for i,expression in ipairs(mCrowdExpressions) do
    for id,player in pairs(players) do
      queueExpressor = true
      if not player[expression] or player[expression] < 1 then
        queueExpressor = false
      else
        if not mCrowdExpressionQueues[expression] then
          mCrowdExpressionQueues[expression] = {}
        else
          for j,expressor in ipairs(mCrowdExpressionQueues[expression]) do
            if expressor.name == player.name and expressor.decorator == player.decorator then
              queueExpressor = false
              if expressor.buried then
                expressor.qid = 0
                expressor.timestamp = mNow
                expressor.buried = nil
              end
              break
            end
          end
        end
      end
      do
        do
          if queueExpressor then
            local newExpressor = {}
            newExpressor.name = player.name
            newExpressor.decorator = player.decorator
            newExpressor.qid = 0
            newExpressor.timestamp = mNow
            ;
            (table.insert)(mCrowdExpressionQueues[expression], newExpressor)
          end
          -- DECOMPILER ERROR at PC66: LeaveBlock: unexpected jumping out DO_STMT

        end
      end
    end
    CrowdPlayOverlay_UpdateExpressionQueue(expression)
  end
end

CrowdPlayOverlay_UpdateExpressionQueue = function(expression)
  -- function num : 0_15 , upvalues : _ENV
  if expression == "thumbsup" then
    CrowdPlayOverlay_UpdateExpressionQueueThumbsUp()
  else
    if expression == "thumbsdown" then
      CrowdPlayOverlay_UpdateExpressionQueueThumbsDown()
    end
  end
end

CrowdPlayOverlay_UpdateExpressionQueueThumbsUp = function()
  -- function num : 0_16 , upvalues : mCrowdExpressionQueues, _ENV, mExpressionChoreStates, mNow, mExpressionTimeouts, mNextThumbsUpPlayerIcon, mPlayerIcons, mCrowdExpressionQueueLimits, mThumbsFrameShown, kSpilloverPrefix, mCrowdExpressionAdvanceChores, mCrowdExpressionTimestamps
  if not mCrowdExpressionQueues.thumbsup or (table.getn)(mCrowdExpressionQueues.thumbsup) < 1 then
    return 
  end
  if mExpressionChoreStates.thumbsup ~= "ready" then
    return 
  end
  local newExpressorPromoted = nil
  for i,expressor in ipairs(mCrowdExpressionQueues.thumbsup) do
    if not expressor.buried then
      if not expressor.qid or expressor.qid < 1 then
        if mExpressionTimeouts.thumbsup < mNow - expressor.timestamp then
          expressor.buried = true
        else
          expressor.qid = 0
          if not newExpressorPromoted then
            newExpressorPromoted = expressor
            local nextIcon = mNextThumbsUpPlayerIcon + 1
            local iconAgent = AgentFind("ui_crowdPlay_icon" .. nextIcon)
            AgentSetProperty(iconAgent, "Text String", expressor.name)
            ShaderOverrideTexture(iconAgent, "ui_telltaleCrowdPlay_player00.d3dtx", "ui_telltaleCrowdPlay_player0" .. expressor.decorator)
            expressor.qagent = iconAgent
            expressor.new = true
            mNextThumbsUpPlayerIcon = (mNextThumbsUpPlayerIcon + 1) % mPlayerIcons
          end
        end
      else
        do
          do
            if mCrowdExpressionQueueLimits.thumbsup <= expressor.qid and mExpressionTimeouts.thumbsup < mNow - expressor.timestamp then
              expressor.buried = true
            end
            -- DECOMPILER ERROR at PC78: LeaveBlock: unexpected jumping out DO_STMT

            -- DECOMPILER ERROR at PC78: LeaveBlock: unexpected jumping out IF_ELSE_STMT

            -- DECOMPILER ERROR at PC78: LeaveBlock: unexpected jumping out IF_STMT

            -- DECOMPILER ERROR at PC78: LeaveBlock: unexpected jumping out IF_THEN_STMT

            -- DECOMPILER ERROR at PC78: LeaveBlock: unexpected jumping out IF_STMT

          end
        end
      end
    end
  end
  if newExpressorPromoted ~= nil then
    CrowdPlayOverlay_LogNewExpression("thumbsup", newExpressorPromoted)
    mExpressionChoreStates.thumbsup = "advancing"
    for i,expressor in ipairs(mCrowdExpressionQueues.thumbsup) do
      if not expressor.buried and (expressor.qid > 0 or expressor.new) then
        expressor.qid = expressor.qid + 1
        expressor.new = nil
      end
    end
    ThreadStart(function()
    -- function num : 0_16_0 , upvalues : _ENV, mCrowdExpressionQueues, mCrowdExpressionQueueLimits, mThumbsFrameShown, mExpressionChoreStates, kSpilloverPrefix, mCrowdExpressionAdvanceChores, mCrowdExpressionTimestamps, mNow
    local queueHeight = 0
    local spilloverCount = 0
    for i,expressor in ipairs(mCrowdExpressionQueues.thumbsup) do
      if not expressor.buried then
        if expressor.qid == 0 or mCrowdExpressionQueueLimits.thumbsup <= expressor.qid then
          spilloverCount = spilloverCount + 1
        end
        if expressor.qid <= mCrowdExpressionQueueLimits.thumbsup and queueHeight < expressor.qid then
          queueHeight = expressor.qid
        end
      end
    end
    if not mThumbsFrameShown and mExpressionChoreStates.thumbsframe ~= "showing" then
      mExpressionChoreStates.thumbsframe = "showing"
      ChorePlay("ui_crowdPlay_thumbs_show.chore")
      ChorePlay("ui_crowdPlay_extraText_show.chore")
    end
    if spilloverCount > 0 then
      AgentSetProperty("ui_crowdPlay_extraTextUp", kText, kSpilloverPrefix .. spilloverCount)
    else
      AgentSetProperty("ui_crowdPlay_extraTextUp", kText, "")
    end
    for i = 1, queueHeight do
      for j,expressor in ipairs(mCrowdExpressionQueues.thumbsup) do
        if not expressor.buried and expressor.qid == i then
          if i == queueHeight then
            ChorePlayAndWait((mCrowdExpressionAdvanceChores.thumbsup)[i], nil, "default", AgentGetName(expressor.qagent))
            break
          end
          ChorePlay((mCrowdExpressionAdvanceChores.thumbsup)[i], nil, "default", AgentGetName(expressor.qagent))
          break
        end
      end
    end
    mExpressionChoreStates.thumbsframe = "ready"
    mThumbsFrameShown = true
    mExpressionChoreStates.thumbsup = "ready"
    mCrowdExpressionTimestamps.thumbsup = mNow
    AgentSetProperty("ui_crowdPlay_ratingsThumbs", "Render Constant Alpha", 1)
    AgentHide("ui_crowdPlay_ratingsThumbs", false)
    AgentHide("ui_crowdPlay_extraTextUp", false)
  end
)
  else
    if mCrowdExpressionTimestamps.thumbsup and mExpressionTimeouts.thumbsup < mNow - mCrowdExpressionTimestamps.thumbsup then
      mExpressionChoreStates.thumbsup = "hiding"
      ThreadStart(function()
    -- function num : 0_16_1 , upvalues : _ENV, mCrowdExpressionQueues, mCrowdExpressionQueueLimits, mThumbsFrameShown, mExpressionChoreStates
    local queueHeight = 0
    local spilloverCount = 0
    for i,expressor in ipairs(mCrowdExpressionQueues.thumbsup) do
      if not expressor.buried then
        if expressor.qid == 0 or mCrowdExpressionQueueLimits.thumbsup <= expressor.qid then
          spilloverCount = spilloverCount + 1
        end
        if expressor.qid <= mCrowdExpressionQueueLimits.thumbsup and queueHeight < expressor.qid then
          queueHeight = expressor.qid
        end
      end
    end
    do
      if mThumbsFrameShown and (mExpressionChoreStates.thumbsdown == "hiding" or not mCrowdExpressionQueues.thumbsdown or (table.getn)(mCrowdExpressionQueues.thumbsdown) < 1) and mExpressionChoreStates.thumbsframe ~= "hiding" then
        mExpressionChoreStates.thumbsframe = "hiding"
        ChorePlay("ui_crowdPlay_thumbs_hide.chore")
      end
      if spilloverCount > 1 then
        ChorePlay("ui_crowdPlay_extraText_hide.chore")
      end
      for i = 1, queueHeight do
        for j,expressor in ipairs(mCrowdExpressionQueues.thumbsup) do
          if not expressor.buried and expressor.qid == i then
            if i == queueHeight then
              ChorePlayAndWait("ui_crowdPlay_icon_hide.chore", nil, "default", AgentGetName(expressor.qagent))
              break
            end
            ChorePlay("ui_crowdPlay_icon_hide.chore", nil, "default", AgentGetName(expressor.qagent))
            break
          end
        end
      end
      AgentSetProperty("ui_crowdPlay_extraTextUp", kText, "")
      if mExpressionChoreStates.thumbsframe == "hiding" then
        mThumbsFrameShown = false
        mExpressionChoreStates.thumbsframe = "ready"
      end
      mCrowdExpressionQueues.thumbsup = {}
      mExpressionChoreStates.thumbsup = "ready"
    end
  end
)
    end
  end
end

CrowdPlayOverlay_UpdateExpressionQueueThumbsDown = function()
  -- function num : 0_17 , upvalues : mCrowdExpressionQueues, _ENV, mExpressionChoreStates, mNow, mExpressionTimeouts, mNextThumbsDownPlayerIcon, mPlayerIcons, mCrowdExpressionQueueLimits, mThumbsFrameShown, kSpilloverPrefix, mCrowdExpressionAdvanceChores, mCrowdExpressionTimestamps
  if not mCrowdExpressionQueues.thumbsdown or (table.getn)(mCrowdExpressionQueues.thumbsdown) < 1 then
    return 
  end
  if mExpressionChoreStates.thumbsdown ~= "ready" then
    return 
  end
  local newExpressorPromoted = nil
  for i,expressor in ipairs(mCrowdExpressionQueues.thumbsdown) do
    if not expressor.buried then
      if expressor.qid < 1 then
        if mExpressionTimeouts.thumbsdown < mNow - expressor.timestamp then
          expressor.buried = true
        else
          expressor.qid = 0
          if not newExpressorPromoted then
            newExpressorPromoted = expressor
            local nextIcon = mNextThumbsDownPlayerIcon + 5
            local iconAgent = AgentFind("ui_crowdPlay_icon" .. nextIcon)
            AgentSetProperty(iconAgent, kText, expressor.name)
            ShaderOverrideTexture(iconAgent, "ui_telltaleCrowdPlay_player00.d3dtx", "ui_telltaleCrowdPlay_player0" .. expressor.decorator)
            expressor.qagent = iconAgent
            expressor.new = true
            mNextThumbsDownPlayerIcon = (mNextThumbsDownPlayerIcon + 1) % mPlayerIcons
          end
        end
      else
        do
          do
            if mCrowdExpressionQueueLimits.thumbsdown <= expressor.qid and mExpressionTimeouts.thumbsdown < mNow - expressor.timestamp then
              expressor.buried = true
            end
            -- DECOMPILER ERROR at PC75: LeaveBlock: unexpected jumping out DO_STMT

            -- DECOMPILER ERROR at PC75: LeaveBlock: unexpected jumping out IF_ELSE_STMT

            -- DECOMPILER ERROR at PC75: LeaveBlock: unexpected jumping out IF_STMT

            -- DECOMPILER ERROR at PC75: LeaveBlock: unexpected jumping out IF_THEN_STMT

            -- DECOMPILER ERROR at PC75: LeaveBlock: unexpected jumping out IF_STMT

          end
        end
      end
    end
  end
  if newExpressorPromoted ~= nil then
    CrowdPlayOverlay_LogNewExpression("thumbsdown", newExpressorPromoted)
    mExpressionChoreStates.thumbsdown = "advancing"
    for i,expressor in ipairs(mCrowdExpressionQueues.thumbsdown) do
      if not expressor.buried and (expressor.qid > 0 or expressor.new) then
        expressor.qid = expressor.qid + 1
        expressor.new = nil
      end
    end
    ThreadStart(function()
    -- function num : 0_17_0 , upvalues : _ENV, mCrowdExpressionQueues, mCrowdExpressionQueueLimits, mThumbsFrameShown, mExpressionChoreStates, kSpilloverPrefix, mCrowdExpressionAdvanceChores, mCrowdExpressionTimestamps, mNow
    local queueHeight = 0
    local spilloverCount = 0
    for i,expressor in ipairs(mCrowdExpressionQueues.thumbsdown) do
      if not expressor.buried then
        if expressor.qid == 0 or mCrowdExpressionQueueLimits.thumbsdown <= expressor.qid then
          spilloverCount = spilloverCount + 1
        end
        if expressor.qid <= mCrowdExpressionQueueLimits.thumbsdown and queueHeight < expressor.qid then
          queueHeight = expressor.qid
        end
      end
    end
    if not mThumbsFrameShown and mExpressionChoreStates.thumbsframe ~= "showing" then
      mExpressionChoreStates.thumbsframe = "showing"
      ChorePlay("ui_crowdPlay_thumbs_show.chore")
      ChorePlay("ui_crowdPlay_extraText_show.chore")
    end
    if spilloverCount > 0 then
      AgentSetProperty("ui_crowdPlay_extraTextDown", kText, kSpilloverPrefix .. spilloverCount)
    else
      AgentSetProperty("ui_crowdPlay_extraTextDown", kText, "")
    end
    for i = 1, queueHeight do
      for j,expressor in ipairs(mCrowdExpressionQueues.thumbsdown) do
        if not expressor.buried and expressor.qid == i then
          if i == queueHeight then
            ChorePlayAndWait((mCrowdExpressionAdvanceChores.thumbsdown)[i], nil, "default", AgentGetName(expressor.qagent))
            break
          end
          ChorePlay((mCrowdExpressionAdvanceChores.thumbsdown)[i], nil, "default", AgentGetName(expressor.qagent))
          break
        end
      end
    end
    mExpressionChoreStates.thumbsframe = "ready"
    mThumbsFrameShown = true
    mExpressionChoreStates.thumbsdown = "ready"
    mCrowdExpressionTimestamps.thumbsdown = mNow
    AgentSetProperty("ui_crowdPlay_ratingsThumbs", "Render Constant Alpha", 1)
    AgentHide("ui_crowdPlay_ratingsThumbs", false)
    AgentHide("ui_crowdPlay_extraTextDown", false)
  end
)
  else
    if mCrowdExpressionTimestamps.thumbsdown and mExpressionTimeouts.thumbsdown < mNow - mCrowdExpressionTimestamps.thumbsdown then
      mExpressionChoreStates.thumbsdown = "hiding"
      ThreadStart(function()
    -- function num : 0_17_1 , upvalues : _ENV, mCrowdExpressionQueues, mCrowdExpressionQueueLimits, mThumbsFrameShown, mExpressionChoreStates
    local queueHeight = 0
    local spilloverCount = 0
    for i,expressor in ipairs(mCrowdExpressionQueues.thumbsdown) do
      if not expressor.buried then
        if expressor.qid == 0 or mCrowdExpressionQueueLimits.thumbsdown <= expressor.qid then
          spilloverCount = spilloverCount + 1
        end
        if expressor.qid <= mCrowdExpressionQueueLimits.thumbsdown and queueHeight < expressor.qid then
          queueHeight = expressor.qid
        end
      end
    end
    do
      if mThumbsFrameShown and (mExpressionChoreStates.thumbsup == "hiding" or not mCrowdExpressionQueues.thumbsup or (table.getn)(mCrowdExpressionQueues.thumbsup) < 1) and mExpressionChoreStates.thumbsframe ~= "hiding" then
        mExpressionChoreStates.thumbsframe = "hiding"
        ChorePlay("ui_crowdPlay_thumbs_hide.chore")
      end
      if spilloverCount > 1 then
        ChorePlay("ui_crowdPlay_extraText_hide.chore")
      end
      for i = 1, queueHeight do
        for j,expressor in ipairs(mCrowdExpressionQueues.thumbsdown) do
          if not expressor.buried and expressor.qid == i then
            if i == queueHeight then
              ChorePlayAndWait("ui_crowdPlay_icon_hide.chore", nil, "default", AgentGetName(expressor.qagent))
              break
            end
            ChorePlay("ui_crowdPlay_icon_hide.chore", nil, "default", AgentGetName(expressor.qagent))
            break
          end
        end
      end
      AgentSetProperty("ui_crowdPlay_extraTextDown", kText, "")
      if mExpressionChoreStates.thumbsframe == "hiding" then
        mThumbsFrameShown = false
        mExpressionChoreStates.thumbsframe = "ready"
      end
      mCrowdExpressionQueues.thumbsdown = {}
      mExpressionChoreStates.thumbsdown = "ready"
    end
  end
)
    end
  end
end

CrowdPlayOverlay_LogNewExpression = function(expression, expressor)
  -- function num : 0_18 , upvalues : _ENV
  local currentDialogId, currentNodeId, currentNodeSymbol, playerName = nil, nil, nil, nil
  if SubProject_IsEpisode() then
    currentDialogId = Dialog_GetCurrentID()
    if currentDialogId then
      currentNodeId = DlgGetCurrentNode(currentDialogId)
    end
    if currentNodeId then
      currentNodeSymbol = (string.sub)(currentNodeId, 9)
    end
  end
  if not expression then
    expression = "unknown expression"
  end
  playerName = expressor.name or "unknown player"
  if not currentNodeSymbol then
    currentNodeSymbol = "undeterminable"
  end
  CreateEventLogEvent("CrowdPlay Expression", expression .. " by " .. (playerName) .. " near node " .. currentNodeSymbol)
end

CrowdPlayOverlay_CrowdAgentsExist = function()
  -- function num : 0_19 , upvalues : _ENV, mCrowdAgents
  for i,agent in ipairs(mCrowdAgents) do
    if not AgentExists(agent) then
      return false
    end
  end
  return true
end

CrowdPlayOverlay_CrowdAgentsVisible = function()
  -- function num : 0_20 , upvalues : _ENV, mCrowdAgents
  for i,agent in ipairs(mCrowdAgents) do
    if AgentExists(agent) and AgentGetProperty(agent, "Runtime: Visible") and AgentGetProperty(agent, "Render Constant Alpha") > 0 then
      return true
    end
  end
  return false
end

CrowdPlayOverlay_ResetQueues = function(doReset)
  -- function num : 0_21 , upvalues : mThumbsFrameShown, _ENV, mCrowdExpressions, mCrowdExpressionQueues, mExpressionChoreStates, kScene, mCrowdAgents
  if not doReset then
    if mThumbsFrameShown then
      doReset = true
    else
      for i,expression in ipairs(mCrowdExpressions) do
        if mCrowdExpressionQueues[expression] ~= nil and (table.getn)(mCrowdExpressionQueues[expression]) > 0 then
          doReset = true
          break
        end
      end
    end
  end
  do
    if doReset then
      for i,expression in ipairs(mCrowdExpressions) do
        mExpressionChoreStates[expression] = "resetting"
      end
      do
        while 1 do
          if not SceneIsActive(kScene) or not CrowdPlayOverlay_CrowdAgentsExist() then
            WaitForNextFrame()
            -- DECOMPILER ERROR at PC44: LeaveBlock: unexpected jumping out IF_THEN_STMT

            -- DECOMPILER ERROR at PC44: LeaveBlock: unexpected jumping out IF_STMT

          end
        end
        ChorePlayAndWait("ui_crowdPlay_ratingsReset.chore")
        for i,expression in ipairs(mCrowdExpressions) do
          mCrowdExpressionQueues[expression] = {}
          mExpressionChoreStates[expression] = "ready"
        end
        for i,agent in ipairs(mCrowdAgents) do
          AgentHide(agent, true)
        end
        AgentHide("ui_crowdPlay_ratingsThumbs", true)
        mThumbsFrameShown = false
      end
    end
  end
end

CrowdPlayOverlay_CheckForAbort = function()
  -- function num : 0_22 , upvalues : _ENV, mConfirmRequestPending
  local bAllowedToContinue, bRetryAllowed, errHeader, errMessage = CrowdPlay_IsActivityAllowed()
  if bAllowedToContinue then
    return 
  end
  if not errHeader then
    errHeader = "popup_crowdPlayNetworkDisconnect_header"
  end
  if not errMessage then
    errMessage = "popup_crowdPlayNetworkDisconnect_message"
  end
  mConfirmRequestPending = true
  if bRetryAllowed then
    local legendString = ""
    if ResourceExists("ui_legend_faceButtonDown.d3dtx") then
      local data = DlgEvaluateToNode("ui_text.dlog", "button_select", "text", false)
      local selectString = data and data:GetText() or "button_select"
      legendString = "^shadowHeight:0^<ui_legend_faceButtonDown.d3dtx:-6>^^ " .. selectString
    end
    do
      do
        DialogBox(errMessage, errHeader, "button_continueWithoutCrowdplay", "CrowdPlayOverlay_AbortDowngrade()", "button_retry", "CrowdPlayOverlay_AbortContinue()", "ui_text.dlog", legendString)
        local legendString = ""
        if ResourceExists("ui_legend_faceButtonDown.d3dtx") then
          local data = DlgEvaluateToNode("ui_text.dlog", "button_select", "text", false)
          local selectString = data and data:GetText() or "button_select"
          legendString = "^shadowHeight:0^<ui_legend_faceButtonDown.d3dtx:-6>^^ " .. selectString
        end
        do
          DialogBox(errMessage, errHeader, "button_continueWithoutCrowdplay", "CrowdPlayOverlay_AbortDowngrade()", nil, nil, "ui_text.dlog", legendString)
        end
      end
    end
  end
end

CrowdPlayOverlay_AbortContinue = function()
  -- function num : 0_23 , upvalues : mConfirmRequestPending
  mConfirmRequestPending = false
end

CrowdPlayOverlay_AbortDowngrade = function()
  -- function num : 0_24 , upvalues : _ENV
  CrowdPlay_EndSession()
  CrowdPlayOverlay_ResetQueues(true)
  CrowdPlayOverlay_Update()
  CrowdPlayOverlay_AbortContinue()
end

CrowdPlayOverlay_SetGameScene = function(scene)
  -- function num : 0_25 , upvalues : _ENV, mGameScene
  if scene and IsString(scene) then
    mGameScene = SceneFind(scene)
  else
    mGameScene = scene
  end
end

CrowdPlayOverlay_GetGameScene = function()
  -- function num : 0_26 , upvalues : mGameScene
  return mGameScene
end

CrowdPlayOverlay_OnGamePaused = function(bPause)
  -- function num : 0_27 , upvalues : _ENV
  local res = TellNetSetPauseState(bPause)
  if not bPause and CrowdPlay_IsVoteActive() then
    CrowdPlay_ReBeginChoice()
  end
end

Init()
