require("ChoiceStats.lua")
require("SocialData.lua")
local kScene = "ui_statsEndCrowdplay.scene"
local kDefaultStatImage = "ui_stat_default.d3dtx"
local kDefaultIconImage = "ui_telltaleCrowdPlay_player00.d3dtx"
local kEnforceBiggestFirst = true
StatPageCrowd = Class(Widget)
local CreateAssets = function()
  -- function num : 0_0 , upvalues : _ENV, kScene
  local fileName = "ui_statsEndCrowdplay_reference.prop"
  if CreateResource(fileName, kDirProperties, "Menu") then
    PropertyAddGlobal(fileName, kPropsUIParent)
    PropertyAddGlobal(fileName, "ui_widgetChores.prop")
    PropertySet(fileName, kExtentsMax, Vector(6.5, 3.5, 0))
    PropertySet(fileName, kExtentsMin, Vector(-6.5, -4.0500001907349, 0))
    Save(fileName)
  end
  fileName = "ui_statsEndCrowdplay_image.prop"
  if CreateResource(fileName, kDirProperties, "Menu") then
    PropertyAddGlobal(fileName, kModuleRenderable)
    Save(fileName)
  end
  fileName = "ui_statsEndCrowdplay_bar.prop"
  if CreateResource(fileName, kDirProperties, "Menu") then
    PropertyAddGlobal(fileName, kModuleRenderable)
    PropertyAddGlobal(fileName, "ui_textMenu.prop")
    PropertySet(fileName, "Text Alignment Horizontal", "Left Justified")
    Save(fileName)
  end
  fileName = "ui_statsEndCrowdplay_label.prop"
  if CreateResource(fileName, kDirProperties, "Menu") then
    PropertyAddGlobal(fileName, "ui_textMenu.prop")
    PropertySet(fileName, "Text Alignment Horizontal", "Left Justified")
    PropertySet(fileName, "Text Alignment Vertical", "Top")
    Save(fileName)
  end
  fileName = "ui_statsEndCrowdplay_question.prop"
  if CreateResource(fileName, kDirProperties, "Menu") then
    PropertyAddGlobal(fileName, "ui_textMenu.prop")
    PropertySet(fileName, "Text Alignment Horizontal", "Left Justified")
    PropertySet(fileName, "Text Alignment Vertical", "Top")
    Save(fileName)
  end
  fileName = "ui_statEndCrowdplay_playerIcon.prop"
  if CreateResource(fileName, kDirProperties, "Menu") then
    PropertyAddGlobal(fileName, kModuleRenderable)
    PropertyAddGlobal(fileName, "ui_textMenu.prop")
    Save(fileName)
  end
  fileName = "ui_stats_line.prop"
  if CreateResource(fileName, kDirProperties, "Menu") then
    PropertyAddGlobal(fileName, kModuleRenderable)
    Save(fileName)
  end
  if CreateUIScene(kScene, 0, false, "Menu") then
    local referenceAgent = AgentCreate("ui_statsEndCrowdplay_reference", "ui_statsEndCrowdplay_reference.prop", nil, nil, kScene, false, false)
    do
      local imageAgent = AgentCreate("ui_statsEndCrowdplay_image", "ui_statsEndCrowdplay_image.prop", nil, nil, kScene, false, false)
      AttachAgent(imageAgent, referenceAgent)
      local labelAgent = AgentCreate("ui_statsEndCrowdplay_label", "ui_statsEndCrowdplay_label.prop", (Vector(-6.3000001907349, -0.75, 0)), nil, kScene, false, false)
      AttachAgent(labelAgent, referenceAgent)
      local questionAgent = AgentCreate("ui_statsEndCrowdplay_question", "ui_statsEndCrowdplay_question.prop", (Vector(-6.3000001907349, -0.15000000596046, 0)), nil, kScene, false, false)
      AttachAgent(questionAgent, referenceAgent)
      local lineAgent = AgentCreate("ui_stats_line", "ui_stats_line.prop", nil, nil, kScene, false, false)
      AttachAgent(imageAgent, referenceAgent)
      local CreateCrowdplayPlayerIconAgent = function(agentNumber, pos)
    -- function num : 0_0_0 , upvalues : _ENV, kScene, referenceAgent
    local playerIconAgent = AgentCreate("ui_statsEndCrowdplay_playerIcon" .. agentNumber, "ui_statsEndCrowdplay_playerIcon.prop", pos, nil, kScene, false, false)
    AttachAgent(playerIconAgent, referenceAgent)
    local playerIconBarAgent = AgentCreate("ui_statsEndCrowdplay_bar" .. agentNumber, "ui_statsEndCrowdplay_bar.prop", pos, nil, kScene, false, false)
    AttachAgent(playerIconBarAgent, playerIconAgent)
  end

      CreateCrowdplayPlayerIconAgent("01", Vector(-3.0499999523163, -0.25, 0))
      CreateCrowdplayPlayerIconAgent("02", Vector(-1.9500000476837, -0.25, 0))
      CreateCrowdplayPlayerIconAgent("03", Vector(-0.85000002384186, -0.25, 0))
      CreateCrowdplayPlayerIconAgent("04", Vector(0.25, -0.25, 0))
      CreateCrowdplayPlayerIconAgent("05", Vector(1.3500000238419, -0.25, 0))
      Save(kScene)
    end
  end
end

StatPageCrowd_Share = function(statNum, bCrowdplayChoice)
  -- function num : 0_1 , upvalues : _ENV
  local logKey = "Crowdplay Summary Stat Share Attempt"
  CreateEventLogEvent(logKey, statNum, true)
  local challengePassed = MenuUtils_ChallengeAccountLink("popupSplash_linkingSharing_body", "ui_imageTelltaleSharing.d3dtx", "Sharing")
  if not challengePassed or not IsTTUser() then
    return 
  end
  local socialData = SocialData_GetStatSocialData(statNum, bCrowdplayChoice)
  Menu_SocialSharePreview(socialData.shareid, Menu_SocialShare_GetDataForMoment(socialData.shareid, socialData), "facebook")
end

-- DECOMPILER ERROR at PC19: Confused about usage of register: R5 in 'UnsetPending'

StatPageCrowd.CanShare = function(self)
  -- function num : 0_2 , upvalues : _ENV
  do return not PlatformSupportsSocialSharing() or not self.choice or SocialData_GetStatSocialData((self.choice).episode .. "0" .. (self.choice).order, true) ~= nil end
  -- DECOMPILER ERROR: 2 unprocessed JMP targets
end

-- DECOMPILER ERROR at PC22: Confused about usage of register: R5 in 'UnsetPending'

StatPageCrowd.DoShare = function(self)
  -- function num : 0_3 , upvalues : _ENV
  StatPageCrowd_Share((self.choice).episode .. "0" .. (self.choice).order, true)
end

-- DECOMPILER ERROR at PC25: Confused about usage of register: R5 in 'UnsetPending'

StatPageCrowd.SetShareButton = function(self, buttonAgent)
  -- function num : 0_4 , upvalues : _ENV
  self.shareButton = buttonAgent
  self:UpdateShareButton(Input_UseCursor())
end

-- DECOMPILER ERROR at PC28: Confused about usage of register: R5 in 'UnsetPending'

StatPageCrowd.UpdateShareButton = function(self, bUseCursor)
  -- function num : 0_5 , upvalues : _ENV
  if self.shareButton then
    local buttonLabel = ""
    if not bUseCursor then
      buttonLabel = "<ui_legend_facebuttonUp.d3dtx:" .. kDefaultLegendButtonOffset .. "> "
    end
    buttonLabel = buttonLabel .. Menu_Text("stats_shareThisChoice")
    AgentSetProperty(self.shareButton, "Text Dialog 2.0 Node Name", "")
    AgentSetProperty(self.shareButton, "Text String", buttonLabel)
  end
end

-- DECOMPILER ERROR at PC31: Confused about usage of register: R5 in 'UnsetPending'

StatPageCrowd.CreateAgent = function(self, name, scene)
  -- function num : 0_6 , upvalues : _ENV, kScene
  return Clone(name, "ui_statsEndCrowdplay_reference", kScene, scene)
end

-- DECOMPILER ERROR at PC34: Confused about usage of register: R5 in 'UnsetPending'

StatPageCrowd.Show = function(self, ...)
  -- function num : 0_7 , upvalues : _ENV, kDefaultStatImage
  (Widget.Show)(self, ...)
  ShaderOverrideTexture(Clone_Find(self.agent, "_image"), kDefaultStatImage, self.texture)
  self:UpdateLayout(true, true, false)
end

-- DECOMPILER ERROR at PC37: Confused about usage of register: R5 in 'UnsetPending'

StatPageCrowd.Hide = function(self, ...)
  -- function num : 0_8 , upvalues : _ENV
  (Widget.Hide)(self, ...)
  ChorePlayAndWait("ui_statsEndCrowdplay_fadeOut.chore", nil, unpack(Clone_GetChoreRemapping("ui_statsEndCrowdplay_fadeOut.chore", self.agent)))
end

-- DECOMPILER ERROR at PC40: Confused about usage of register: R5 in 'UnsetPending'

StatPageCrowd.OnWidgetInputChange = function(self, bUseCursor)
  -- function num : 0_9
  self:UpdateShareButton(bUseCursor)
end

-- DECOMPILER ERROR at PC43: Confused about usage of register: R5 in 'UnsetPending'

StatPageCrowd.OnY = function(self)
  -- function num : 0_10 , upvalues : _ENV
  if self.shareButton and not AgentIsHidden(self.shareButton) then
    shareButton:OnPress()
  end
end

-- DECOMPILER ERROR at PC46: Confused about usage of register: R5 in 'UnsetPending'

StatPageCrowd.GatherStatAgents = function(self)
  -- function num : 0_11 , upvalues : _ENV
  self.statAgents = {}
  -- DECOMPILER ERROR at PC4: Confused about usage of register: R1 in 'UnsetPending'

  ;
  (self.statAgents).bars = {}
  -- DECOMPILER ERROR at PC13: Confused about usage of register: R1 in 'UnsetPending'

  ;
  ((self.statAgents).bars)[1] = AgentGetName(Clone_Find(self.agent, "_bar01"))
  -- DECOMPILER ERROR at PC22: Confused about usage of register: R1 in 'UnsetPending'

  ;
  ((self.statAgents).bars)[2] = AgentGetName(Clone_Find(self.agent, "_bar02"))
  -- DECOMPILER ERROR at PC31: Confused about usage of register: R1 in 'UnsetPending'

  ;
  ((self.statAgents).bars)[3] = AgentGetName(Clone_Find(self.agent, "_bar03"))
  -- DECOMPILER ERROR at PC40: Confused about usage of register: R1 in 'UnsetPending'

  ;
  ((self.statAgents).bars)[4] = AgentGetName(Clone_Find(self.agent, "_bar04"))
  -- DECOMPILER ERROR at PC49: Confused about usage of register: R1 in 'UnsetPending'

  ;
  ((self.statAgents).bars)[5] = AgentGetName(Clone_Find(self.agent, "_bar05"))
  -- DECOMPILER ERROR at PC52: Confused about usage of register: R1 in 'UnsetPending'

  ;
  (self.statAgents).icons = {}
  -- DECOMPILER ERROR at PC61: Confused about usage of register: R1 in 'UnsetPending'

  ;
  ((self.statAgents).icons)[1] = AgentGetName(Clone_Find(self.agent, "_playerIcon01"))
  -- DECOMPILER ERROR at PC70: Confused about usage of register: R1 in 'UnsetPending'

  ;
  ((self.statAgents).icons)[2] = AgentGetName(Clone_Find(self.agent, "_playerIcon02"))
  -- DECOMPILER ERROR at PC79: Confused about usage of register: R1 in 'UnsetPending'

  ;
  ((self.statAgents).icons)[3] = AgentGetName(Clone_Find(self.agent, "_playerIcon03"))
  -- DECOMPILER ERROR at PC88: Confused about usage of register: R1 in 'UnsetPending'

  ;
  ((self.statAgents).icons)[4] = AgentGetName(Clone_Find(self.agent, "_playerIcon04"))
  -- DECOMPILER ERROR at PC97: Confused about usage of register: R1 in 'UnsetPending'

  ;
  ((self.statAgents).icons)[5] = AgentGetName(Clone_Find(self.agent, "_playerIcon05"))
  -- DECOMPILER ERROR at PC105: Confused about usage of register: R1 in 'UnsetPending'

  ;
  (self.statAgents).question = AgentGetName(Clone_Find(self.agent, "_question"))
  -- DECOMPILER ERROR at PC113: Confused about usage of register: R1 in 'UnsetPending'

  ;
  (self.statAgents).label = AgentGetName(Clone_Find(self.agent, "_label"))
  -- DECOMPILER ERROR at PC121: Confused about usage of register: R1 in 'UnsetPending'

  ;
  (self.statAgents).line = AgentGetName(Clone_Find(self.agent, "_line"))
end

-- DECOMPILER ERROR at PC49: Confused about usage of register: R5 in 'UnsetPending'

StatPageCrowd.ClearAgents = function(self)
  -- function num : 0_12 , upvalues : _ENV
  if not self.statAgents then
    self:GatherStatAgents()
  end
  AgentSetProperty((self.statAgents).question, "Text String", "")
  AgentSetProperty((self.statAgents).label, "Text String", "")
  AgentHide((self.statAgents).question, true)
  AgentHide((self.statAgents).label, true)
  for i = 1, 5 do
    AgentSetProperty(((self.statAgents).bars)[i], "Text String", "")
    AgentSetProperty(((self.statAgents).icons)[i], "Text String", "")
    AgentHide(((self.statAgents).bars)[i], true)
    AgentHide(((self.statAgents).icons)[i], true)
  end
  AgentHide((self.statAgents).image, true)
end

-- DECOMPILER ERROR at PC52: Confused about usage of register: R5 in 'UnsetPending'

StatPageCrowd.SetChoice = function(self, choice)
  -- function num : 0_13
  self:SetCrowdChoice(choice)
end

-- DECOMPILER ERROR at PC55: Confused about usage of register: R5 in 'UnsetPending'

StatPageCrowd.SetCrowdChoice = function(self, choice)
  -- function num : 0_14 , upvalues : kDefaultStatImage, _ENV, kEnforceBiggestFirst
  if not self.crowdChoice and not self.choice then
    do return  end
    self.mode = "crowd"
    self.choice = choice
    self.crowdChoice = choice
    local texture = ""
    if texture == nil or texture == "" then
      texture = (self.crowdChoice).image
    end
    if texture == nil or texture == "" then
      texture = kDefaultStatImage
    end
    self.crowdTexture = texture
    ShaderOverrideTexture(Clone_Find(self.agent, "_image"), kDefaultStatImage, self.crowdTexture)
    self.choiceDesc = choice.title
    self.numOptions = choice.subgroupcount or 0
    self.optionLabels = {}
    for i,subgroup in ipairs(choice.subgroups) do
      -- DECOMPILER ERROR at PC47: Confused about usage of register: R8 in 'UnsetPending'

      (self.optionLabels)[i] = {}
      -- DECOMPILER ERROR at PC64: Confused about usage of register: R8 in 'UnsetPending'

      if kEnforceBiggestFirst and i > 1 and ((self.optionLabels)[1]).quantity < subgroup.quantity then
        ((self.optionLabels)[i]).quantity = ((self.optionLabels)[1]).quantity
        -- DECOMPILER ERROR at PC70: Confused about usage of register: R8 in 'UnsetPending'

        ;
        ((self.optionLabels)[i]).label = ((self.optionLabels)[1]).label
        -- DECOMPILER ERROR at PC74: Confused about usage of register: R8 in 'UnsetPending'

        ;
        ((self.optionLabels)[1]).quantity = subgroup.quantity
        -- DECOMPILER ERROR at PC78: Confused about usage of register: R8 in 'UnsetPending'

        ;
        ((self.optionLabels)[1]).label = subgroup.title
      else
        -- DECOMPILER ERROR at PC83: Confused about usage of register: R8 in 'UnsetPending'

        ;
        ((self.optionLabels)[i]).quantity = subgroup.quantity
        -- DECOMPILER ERROR at PC87: Confused about usage of register: R8 in 'UnsetPending'

        ;
        ((self.optionLabels)[i]).label = subgroup.title
      end
    end
    for i = 1, self.numOptions do
      -- DECOMPILER ERROR at PC98: Confused about usage of register: R7 in 'UnsetPending'

      if i == 1 then
        ((self.optionLabels)[1]).percent = 1
      else
        -- DECOMPILER ERROR at PC109: Confused about usage of register: R7 in 'UnsetPending'

        ;
        ((self.optionLabels)[i]).percent = ((self.optionLabels)[i]).quantity / ((self.optionLabels)[1]).quantity
      end
    end
  end
end

-- DECOMPILER ERROR at PC58: Confused about usage of register: R5 in 'UnsetPending'

StatPageCrowd.HasCrowdChoice = function(self)
  -- function num : 0_15
  if not self.choice then
    return false
  end
  return true
end

-- DECOMPILER ERROR at PC61: Confused about usage of register: R5 in 'UnsetPending'

StatPageCrowd.UpdateWorldLayout = function(self)
  -- function num : 0_16
  self:UpdateLayout()
end

-- DECOMPILER ERROR at PC64: Confused about usage of register: R5 in 'UnsetPending'

StatPageCrowd.UpdateCrowdLayout = function(self)
  -- function num : 0_17
  self:UpdateLayout()
end

-- DECOMPILER ERROR at PC67: Confused about usage of register: R5 in 'UnsetPending'

StatPageCrowd.UpdateLayout = function(self, refresh, showing, hiding)
  -- function num : 0_18 , upvalues : _ENV, kDefaultIconImage
  local bFullTransition = not refresh
  if not self.statAgents then
    self:GatherStatAgents()
  end
  if bFullTransition then
    ChorePlayAndWait("ui_statsEndCrowdplay_fadeOut.chore", nil, unpack(Clone_GetChoreRemapping("ui_statsEndCrowdplay_fadeOut.chore", self.agent)))
  end
  ChorePlayAndWait("ui_statsEndCrowdplay_person1.chore", nil, unpack(Clone_GetChoreRemapping("ui_statsEndCrowdplay_person1.chore", self.agent)))
  AgentSetProperty((self.statAgents).question, "Text String", self.choiceDesc or "")
  AgentHide((self.statAgents).question, false)
  AgentSetProperty((self.statAgents).label, "Text String", self.choiceSubtitle or "")
  AgentHide((self.statAgents).label, true)
  AgentHide((self.statAgents).image, false)
  AgentHide((self.statAgents).line, false)
  for i = 1, self.numOptions do
    AgentSetProperty(((self.statAgents).bars)[i], "Text String", ((self.optionLabels)[i]).label or "")
    AgentHide(((self.statAgents).bars)[i], false)
    ChorePlayToTime("ui_statsEndCrowdplay_barScale.chore", 0, nil, nil, "default", ((self.statAgents).bars)[i])
  end
  local choice = self.choice
  local voteIndices = {}
  for i = 1, self.numOptions do
    voteIndices[i] = 0
  end
  local iconAgent, iconTexture, subgroupid = nil, nil, nil
  local mouseHostPlayerTexture = "ui_telltaleCrowdPlay_playerPC00.d3dtx"
  local controllerHostPlayerTexture = "ui_telltaleCrowdPlay_player00.d3dtx"
  for voteIndex,voter in ipairs(choice.votes) do
    subgroupid = voter.subgroup or 1
    if subgroupid ~= nil and (not voteIndices[subgroupid] or voteIndices[subgroupid] < 1) then
      voteIndices[subgroupid] = 1
      iconAgent = ((self.statAgents).icons)[subgroupid]
      if voter.decorator == "0" then
        if (IsPlatformPC() or IsPlatformMac()) and Input_UseCursor() then
          iconTexture = mouseHostPlayerTexture
        else
          iconTexture = controllerHostPlayerTexture
        end
        voter.name = ""
      else
        iconTexture = "ui_telltaleCrowdPlay_player0" .. voter.decorator .. ".d3dtx"
      end
      AgentSetProperty(iconAgent, "Text String", voter.name)
      ShaderOverrideTexture(iconAgent, kDefaultIconImage, iconTexture)
    end
  end
  if self.numOptions == 2 then
    ChorePlayAndWait("ui_statsEndCrowdplay_person2.chore", nil, unpack(Clone_GetChoreRemapping("ui_statsEndCrowdplay_person2.chore", self.agent)))
  else
    if self.numOptions == 3 then
      ChorePlayAndWait("ui_statsEndCrowdplay_person3.chore", nil, unpack(Clone_GetChoreRemapping("ui_statsEndCrowdplay_person3.chore", self.agent)))
    else
      if self.numOptions == 4 then
        ChorePlayAndWait("ui_statsEndCrowdplay_person4.chore", nil, unpack(Clone_GetChoreRemapping("ui_statsEndCrowdplay_person4.chore", self.agent)))
      else
        if self.numOptions == 5 then
          ChorePlayAndWait("ui_statsEndCrowdplay_person5.chore", nil, unpack(Clone_GetChoreRemapping("ui_statsEndCrowdplay_person5.chore", self.agent)))
        else
          ChorePlayAndWait("ui_statsEndCrowdplay_person1.chore", nil, unpack(Clone_GetChoreRemapping("ui_statsEndCrowdplay_person1.chore", self.agent)))
        end
      end
    end
  end
  if bFullTransition then
    ChorePlayAndWait("ui_statsEndCrowdplay_fadeIn.chore", nil, unpack(Clone_GetChoreRemapping("ui_statsEndCrowdplay_fadeIn.chore", self.agent)))
  end
  local choreName = "ui_statsEndCrowdplay_barScale.chore"
  local choreLength = ChoreGetLength(choreName)
  if not self.barControllers then
    self.barControllers = {}
  end
  for i = 1, self.numOptions do
    local percent = ((self.optionLabels)[i]).percent or 0
    if (self.barControllers)[i] then
      ControllerKill((self.barControllers)[i])
    end
    -- DECOMPILER ERROR at PC280: Confused about usage of register: R19 in 'UnsetPending'

    ;
    (self.barControllers)[i] = ChorePlayToTime(choreName, percent * choreLength, nil, nil, "default", ((self.statAgents).bars)[i])
  end
end

if IsToolBuild() then
  CreateAssets()
end
