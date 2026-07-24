Callback_CrowdPlayEndSession = Callback(true)
Callback_CrowdPlayRefresh = Callback(true)
Callback_CrowdPlayServerHealth = Callback(true)
Callback_CrowdPlayNumPlayers = Callback(true)
Callback_CrowdPlayResponse = Callback(true)
Callback_CrowdPlayFinalResponse = Callback(true)
local kCrowdPlayVersion = "1611.1"
local kEnableExpressions = "Crowd Play - Enable Expressions"
local kEnableOverlay = "Crowd Play - Enable Overlay Info"
local kHostMakesChoice = "Crowd Play - Host Makes Choice"
local kNumControllers = "Crowd Play - Num Controllers"
local kPollingDelay = "Crowd Play - Polling Delay"
local kHostResponseOvertimeout = "Crowd Play - Host Response Overtimeout"
local kSessionCode = "Crowd Play - Session Code"
local kSessionServer = "Crowd Play - Session Server"
local kSessionPort = "Crowd Play - Session Port"
local kPlayerCount = "Crowd Play - Player Count"
local kHostPlayerCount = "Crowd Play - Host Player Count"
local kServerPlayerCount = "Crowd Play - Server Player Count"
local kSessionCrowdMax = "Crowd Play - Session Crowd Max"
local kSmallCrowdLimit = "Crowd Play - Small Crowd Limit"
local kCrowdPlayURL = "https://services.telltalegames.com/1/crowdplay"
local kDefaultMaxSmallCrowdCapacity = 50
local kMaxCrowdMemberDisplayCapacity = 10
local mPlayerCountThread, mResponseThread, mBallotID, mChoiceNodeID = nil, nil, nil, nil
local mChoiceOptionTable = {}
local mSubChoiceIDs = {}
local mServerResponses = {}
local mNumServerResponses = 0
local mHostResponses = {}
local mLocalPlayerResponse = nil
local mHostResponseOvertimer = 0
local mHostResponseOvertimeout = 10
local mHostResponseOvertimeThread = nil
local mServerPlayers = {}
local mCrowdExpressions = {}
local mVoteActive = false
local mVoteDenouement = false
local mServerHealthy = true
local mServerHealthStatusTimer = 0
local mServerHealthStatusTimeout = 2
local mServerHealthThread, mSimErr = nil, nil
local mDebugActions = 0
local CreateAssets = function()
  -- function num : 0_0 , upvalues : _ENV, kEnableExpressions, kEnableOverlay, kHostMakesChoice, kNumControllers, kPollingDelay, kHostResponseOvertimeout
  local builderProp = GetPropertySetBuilder()
  local fileName = "project_crowdPlay.prop"
  if builderProp then
    PropertyCreate(builderProp, kEnableExpressions, kBool, true)
    PropertyCreate(builderProp, kEnableOverlay, kBool, true)
    PropertyCreate(builderProp, kHostMakesChoice, kBool)
    PropertyCreate(builderProp, kNumControllers, kInt, 1)
    PropertyCreate(builderProp, kPollingDelay, kFloat, 0.5)
    PropertyCreate(builderProp, kHostResponseOvertimeout, kFloat, 10)
    if GeneratePropertySet(builderProp, fileName, kDirProperties) then
      PropertyAddGlobal(GetPreferences(), fileName)
    end
  end
end

local ParseSessionCode = function(parsedData)
  -- function num : 0_1 , upvalues : _ENV, kDefaultMaxSmallCrowdCapacity
  local sessionCode, sessionHost, sessionPort, sessionLimit, errorCode = nil, nil, nil, nil, nil
  if type(parsedData.roomcode) ~= "string" or parsedData.roomcode == "" then
    if IsDebugBuild() and (GetPreferences())["Beta Menu - Beta Test Crowd Play"] then
      CreateEventLogEvent("CrowdPlay Get Token Fail", "Bad Room Code returned from server", true)
      Print("Bad Room Code returned from server: " .. tostring(parsedData.roomcode) .. "but faking one for testing purposes")
      sessionCode = "BANANG"
    else
      CreateEventLogEvent("CrowdPlay Get Token Fail", "Bad Room Code returned from server", true)
      Print("Bad Room Code returned from server: " .. tostring(parsedData.roomcode))
      errorCode = "BadResponse"
    end
  else
    if type(parsedData.host) ~= "string" or parsedData.host == "" then
      Print("Bad Server Host returned from server: " .. tostring(parsedData.host))
      errorCode = "BadResponse"
    else
      if type(parsedData.port) ~= "string" or parsedData.port == "" then
        Print("Bad Server Port returned from server: " .. tostring(parsedData.port))
        errorCode = "BadResponse"
      else
        if not parsedData.maxvoter_count or type(parsedData.maxvoter_count) ~= "string" then
          parsedData.limit = kDefaultMaxSmallCrowdCapacity
        else
          parsedData.limit = tonumber(parsedData.maxvoter_count)
        end
      end
    end
  end
  if not errorCode then
    sessionCode = parsedData.roomcode
    sessionHost = parsedData.host
    sessionPort = parsedData.port
    sessionLimit = parsedData.limit
  end
  return sessionCode, sessionHost, sessionPort, sessionLimit, errorCode
end

local ParsePlayerCount = function(parsedData)
  -- function num : 0_2 , upvalues : _ENV
  local playerCount, players, errorCode, useTotals = nil, nil, nil, nil
  if parsedData.usetotals == nil then
    useTotals = false
  else
    if type(parsedData.usetotals) ~= "string" or parsedData.usetotals ~= "true" then
      useTotals = false
    else
      useTotals = true
    end
  end
  if type(parsedData.count) ~= "number" then
    Print("Bad Player Count returned from server: " .. tostring(parsedData.count))
    errorCode = "BadResponse"
  else
    if type(parsedData.players) ~= "table" then
      if parsedData.count == 0 then
        parsedData.players = {}
      else
        Print("Bad Responders Data returned from server: " .. tostring(parsedData.players))
        errorCode = "BadResponse"
      end
    end
  end
  if not errorCode then
    if not useTotals and (table.getn)(parsedData.players) ~= tonumber(parsedData.count) then
      Print("Bad Responders Data returned from server: " .. tostring(parsedData.players) .. " vs expected count " .. parsedData.count)
      errorCode = "BadResponse"
    else
      for i,player in ipairs(parsedData.players) do
        if type(player) ~= "table" then
          Print("Bad Player Data returned from server: " .. tostring(player))
          errorCode = "BadResponse"
          break
        else
          if type(player.uuid) ~= "string" or player.uuid == "" then
            Print("Bad Player uuid returned from server: " .. tostring(player.uuid))
            errorCode = "BadResponse"
            break
          else
            if type(player.decorator) ~= "string" or not CrowdPlay_IsValidPlayerDecorator(tostring(player.decorator)) then
              Print("Bad Player Decorator returned from server: " .. tostring(player.decorator))
              errorCode = "BadResponse"
              break
            else
              if type(player.nickname) ~= "string" or player.nickname == "" then
                Print("Bad Player Name returned from server: " .. tostring(player.nickname))
                errorCode = "BadResponse"
                break
              end
            end
          end
        end
      end
    end
  end
  do
    if (player.thumbsup == nil or type(player.thumbsup) ~= "string" or player.thumbsup == "" or player.thumbsup == nil or type(player.thumbsdown) ~= "string" or player.thumbsdown == "" or not errorCode) and useTotals then
      if type(parsedData.totals) ~= "table" then
        Print("Bad Totals Data returned from server: " .. tostring(parsedData.totals))
        errorCode = "BadResponse"
      else
        if (parsedData.totals).thumbsup ~= nil and (type((parsedData.totals).thumbsup) ~= "number" or (parsedData.totals).thumbsup < 0) then
          Print("Bad Totals thumbsup Data returned from server: " .. tostring((parsedData.totals).thumbsup))
          errorCode = "BadResponse"
        else
          if (parsedData.totals).thumbsdown ~= nil and (type((parsedData.totals).thumbsdown) ~= "number" or (parsedData.totals).thumbsdown < 0) then
            Print("Bad Totals thumbsdown Data returned from server: " .. tostring((parsedData.totals).thumbsdown))
            errorCode = "BadResponse"
          end
        end
      end
    end
    if not errorCode then
      playerCount = parsedData.count
      players = {}
      players.playercount = playerCount
      players.players = {}
      for i,player in ipairs(parsedData.players) do
        -- DECOMPILER ERROR at PC254: Confused about usage of register: R10 in 'UnsetPending'

        (players.players)[player.uuid] = {}
        -- DECOMPILER ERROR at PC259: Confused about usage of register: R10 in 'UnsetPending'

        ;
        ((players.players)[player.uuid]).id = player.uuid
        -- DECOMPILER ERROR at PC264: Confused about usage of register: R10 in 'UnsetPending'

        ;
        ((players.players)[player.uuid]).decorator = player.decorator
        -- DECOMPILER ERROR at PC269: Confused about usage of register: R10 in 'UnsetPending'

        ;
        ((players.players)[player.uuid]).name = player.nickname
        -- DECOMPILER ERROR at PC287: Confused about usage of register: R10 in 'UnsetPending'

        ;
        ((players.players)[player.uuid]).thumbsup = player.thumbsup ~= nil and type(player.thumbsup) == "string" and tonumber(player.thumbsup) or 0
        -- DECOMPILER ERROR at PC305: Confused about usage of register: R10 in 'UnsetPending'

        ;
        ((players.players)[player.uuid]).thumbsdown = player.thumbsup ~= nil and type(player.thumbsdown) == "string" and tonumber(player.thumbsdown) or 0
      end
      if useTotals then
        players.useTotals = true
        players.totals = {}
        -- DECOMPILER ERROR at PC319: Confused about usage of register: R5 in 'UnsetPending'

        ;
        (players.totals).thumbsup = (parsedData.totals).thumbsup or 0
        -- DECOMPILER ERROR at PC326: Confused about usage of register: R5 in 'UnsetPending'

        ;
        (players.totals).thumbsdown = (parsedData.totals).thumbsdown or 0
      end
    end
    return playerCount, players, errorCode
  end
end

local ParseChoiceID = function(parsedData)
  -- function num : 0_3 , upvalues : _ENV
  local ballotID, errorCode = nil, nil
  if type(parsedData.ballotid) ~= "string" or parsedData.ballotid == "" then
    if type(parsedData.choiceid) ~= "string" or parsedData.choiceid == "" then
      CreateEventLogEvent("CrowdPlay Choice Fail", "Bad Ballot ID returned from server", true)
      Print("Bad Ballot ID returned from server: " .. tostring(parsedData.ballotid))
      errorCode = "BadResponse"
    else
      parsedData.ballotid = parsedData.choiceid
    end
  end
  if not errorCode then
    ballotID = parsedData.ballotid
  end
  return ballotID, errorCode
end

local ParseChoiceData = function(parsedData)
  -- function num : 0_4 , upvalues : _ENV, mVoteActive, mBallotID, kMaxCrowdMemberDisplayCapacity
  local ballotID, numResponses, responses, errorCode = nil, nil, nil, nil
  if CrowdPlay_IsSocketsSupported() and (not mVoteActive or not mBallotID) then
    Print("Trying to parse vote results from server when we\'re not expecting a vote right now.")
    errorCode = "BadResponse"
  end
  if type(parsedData.ballotid) ~= "string" or parsedData.ballotid == "" then
    if type(parsedData.choiceid) ~= "string" or parsedData.choiceid == "" then
      Print("Bad Ballot ID returned from server: " .. tostring(parsedData.ballotid))
      errorCode = "BadResponse"
    else
      parsedData.ballotid = parsedData.choiceid
    end
  end
  if not errorCode then
    if type(parsedData.denominator) ~= "number" then
      Print("Bad Response Count returned from server: " .. tostring(parsedData.denominator))
      errorCode = "BadResponse"
    else
      if type(parsedData.roomplayers) ~= "table" then
        if parsedData.denominator == 0 then
          parsedData.roomplayers = {}
        else
          Print("Bad Responders Data returned from server: " .. tostring(parsedData.players))
          errorCode = "BadResponse"
        end
      end
    end
  end
  if not errorCode then
    for i,player in ipairs(parsedData.roomplayers) do
      if type(player) ~= "table" then
        Print("Bad Responder Data returned from server: " .. tostring(player))
        errorCode = "BadResponse"
        break
      else
        if type(player.uuid) ~= "string" or player.uuid == "" then
          Print("Bad Responder ID returned from server: " .. tostring(player.uuid))
          errorCode = "BadResponse"
          break
        else
          if type(player.decorator) ~= "string" or not CrowdPlay_IsValidPlayerDecorator(tostring(player.decorator)) then
            Print("Bad Responder Decorator returned from server: " .. tostring(player.decorator))
            errorCode = "BadResponse"
            break
          else
            if type(player.nickname) ~= "string" or player.nickname == "" then
              Print("Bad Responder Name returned from server: " .. tostring(player.name))
              errorCode = "BadResponse"
              break
            end
          end
        end
      end
    end
  end
  do
    if not errorCode then
      if type(parsedData.choices) ~= "table" or (table.getn)(parsedData.choices) == 0 then
        Print("Bad Choice Data returned from server: " .. tostring(parsedData.choices))
        errorCode = "BadResponse"
      else
        for i,choice in ipairs(parsedData.choices) do
          if type(choice) ~= "table" then
            Print("Bad Choice Option Data returned from server: " .. tostring(choice))
            errorCode = "BadResponse"
            break
          else
            if type(choice.id) ~= "string" or choice.id == "" or tonumber(choice.id) == nil then
              Print("Bad Choice Option ID returned from server: " .. tostring(choice.id))
              errorCode = "BadResponse"
              break
            else
              if type(choice.count) ~= "number" then
                Print("Bad Choice Option Count returned from server: " .. tostring(choice.count))
                errorCode = "BadResponse"
                break
              else
                if type(choice.players) ~= "table" then
                  Print("Bad Voters Data returned from server for choice " .. choice.id .. ": " .. tostring(choice.players))
                  errorCode = "BadResponse"
                  break
                else
                  if choice.count > 0 then
                    for j,voter in ipairs(choice.players) do
                      if type(voter) ~= "table" then
                        Print("Bad Voter Data returned from server for choice " .. choice.id .. ": " .. tostring(voter))
                        errorCode = "BadResponse"
                        break
                      else
                        if type(voter.uuid) ~= "string" or voter.uuid == "" then
                          Print("Bad Voter ID returned from server for choice " .. choice.id .. ": " .. tostring(voter.uuid))
                          errorCode = "BadResponse"
                          break
                        else
                          if type(voter.decorator) ~= "string" or not CrowdPlay_IsValidPlayerDecorator(tostring(voter.decorator)) then
                            Print("Bad Voter Decorator returned from server for choice " .. choice.id .. ": " .. tostring(voter.decorator))
                            errorCode = "BadResponse"
                            break
                          else
                            if type(voter.nickname) ~= "string" or voter.nickname == "" then
                              Print("Bad Voter Name returned from server for choice " .. choice.id .. ": " .. tostring(voter.name))
                              errorCode = "BadResponse"
                              break
                            end
                          end
                        end
                      end
                    end
                  end
                end
              end
            end
          end
        end
      end
    end
    do
      if not errorCode then
        if not mBallotID then
          ballotID = parsedData.ballotid
        end
        numResponses = parsedData.denominator
        responses = {}
        responses.playercount = numResponses
        responses.players = {}
        for i,player in ipairs(parsedData.roomplayers) do
          -- DECOMPILER ERROR at PC364: Confused about usage of register: R10 in 'UnsetPending'

          (responses.players)[player.uuid] = {}
          -- DECOMPILER ERROR at PC369: Confused about usage of register: R10 in 'UnsetPending'

          ;
          ((responses.players)[player.uuid]).id = player.uuid
          -- DECOMPILER ERROR at PC374: Confused about usage of register: R10 in 'UnsetPending'

          ;
          ((responses.players)[player.uuid]).decorator = player.decorator
          -- DECOMPILER ERROR at PC379: Confused about usage of register: R10 in 'UnsetPending'

          ;
          ((responses.players)[player.uuid]).name = player.nickname
          -- DECOMPILER ERROR at PC383: Confused about usage of register: R10 in 'UnsetPending'

          ;
          ((responses.players)[player.uuid]).votedfor = 0
        end
        for i,choice in ipairs(parsedData.choices) do
          local choiceid = tonumber(choice.id)
          responses[choiceid] = {}
          -- DECOMPILER ERROR at PC397: Confused about usage of register: R11 in 'UnsetPending'

          ;
          (responses[choiceid]).votecount = choice.count
          -- DECOMPILER ERROR at PC400: Confused about usage of register: R11 in 'UnsetPending'

          ;
          (responses[choiceid]).voters = {}
          for j,voter in ipairs(choice.players) do
            -- DECOMPILER ERROR at PC412: Confused about usage of register: R16 in 'UnsetPending'

            if j <= kMaxCrowdMemberDisplayCapacity then
              ((responses[choiceid]).voters)[voter.uuid] = {}
              -- DECOMPILER ERROR at PC418: Confused about usage of register: R16 in 'UnsetPending'

              ;
              (((responses[choiceid]).voters)[voter.uuid]).id = voter.uuid
              -- DECOMPILER ERROR at PC424: Confused about usage of register: R16 in 'UnsetPending'

              ;
              (((responses[choiceid]).voters)[voter.uuid]).decorator = voter.decorator
              -- DECOMPILER ERROR at PC430: Confused about usage of register: R16 in 'UnsetPending'

              ;
              (((responses[choiceid]).voters)[voter.uuid]).name = voter.nickname
            end
            -- DECOMPILER ERROR at PC439: Confused about usage of register: R16 in 'UnsetPending'

            if (responses.players)[voter.uuid] ~= nil then
              ((responses.players)[voter.uuid]).votedfor = choiceid
            end
          end
        end
      end
      do
        return ballotID, numResponses, responses, errorCode
      end
    end
  end
end

local ParseCrowdStats = function(parsedData)
  -- function num : 0_5 , upvalues : _ENV, kMaxCrowdMemberDisplayCapacity
  local crowdStats, statCount, errorCode, statType = nil, nil, nil, nil
  local language = LangGetCurLanguage()
  if language == nil or language == "" then
    language = "english"
  end
  if type(parsedData.count) ~= "number" then
    CreateEventLogEvent("CrowdPlay Stats Fail", "Bad Stats Count returned from server", true)
    Print("Bad Stats Count returned from server: " .. tostring(parsedData.count))
    errorCode = "BadResponse"
  else
    if type(parsedData.stats) ~= "table" or (table.getn)(parsedData.stats) ~= tonumber(parsedData.count) then
      CreateEventLogEvent("CrowdPlay Stats Fail", "Bad Stats Data returned from server", true)
      Print("Bad Stats Data returned from server: " .. tostring(parsedData.stats))
      errorCode = "BadResponse"
    else
      for i,stat in ipairs(parsedData.stats) do
        if type(stat) ~= "table" then
          CreateEventLogEvent("CrowdPlay Stats Fail", "Bad Stat Data returned from server", true)
          Print("Bad Stat Data returned from server: " .. tostring(stat))
          errorCode = "BadResponse"
          break
        else
          if type(stat.description) ~= "table" then
            CreateEventLogEvent("CrowdPlay Stats Fail", "Bad Stat Description table returned from server", true)
            Print("Bad Stat Description table returned from server: " .. tostring(stat.description))
            errorCode = "BadResponse"
            break
          else
            if type((stat.description)[language]) ~= "string" or (stat.description)[language] == nil or (stat.description)[language] == "" then
              CreateEventLogEvent("CrowdPlay Stats Fail", "Bad Stat Description for language " .. language .. " returned from server", true)
              Print("Bad Stat Description for language " .. language .. " returned from server: " .. tostring((stat.description)[language]))
              errorCode = "BadResponse"
              break
            else
              if type(stat.order) ~= "string" or not tonumber(stat.order) then
                CreateEventLogEvent("CrowdPlay Stats Fail", "Bad Stat Order returned from server", true)
                Print("Bad Stat Order returned from server: " .. tostring(stat.order))
                errorCode = "BadResponse"
                break
              else
                if type(stat.subgroupcount) ~= "number" then
                  CreateEventLogEvent("CrowdPlay Stats Fail", "Bad Stat Subgroups Count returned from server", true)
                  Print("Bad Stat Subgroups Count returned from server: " .. tostring(stat.subgroupcount))
                  errorCode = "BadResponse"
                  break
                else
                  if type(stat.subgroups) ~= "table" or (table.getn)(stat.subgroups) ~= tonumber(stat.subgroupcount) then
                    CreateEventLogEvent("CrowdPlay Stats Fail", "Bad Stat Subgroups Data returned from server", true)
                    Print("Bad Stat Subgroups Data returned from server: " .. tostring(stat.subgroups))
                    errorCode = "BadResponse"
                    break
                  else
                    for j,subgroup in ipairs(stat.subgroups) do
                      if not errorCode then
                        if type(subgroup.id) ~= "number" then
                          CreateEventLogEvent("CrowdPlay Stats Fail", "Bad Stat Subgroup id returned from server", true)
                          Print("Bad Stat Subgroup id returned from server: " .. tostring(subgroup.id))
                          errorCode = "BadResponse"
                          break
                        else
                          if type(subgroup.description) ~= "table" then
                            CreateEventLogEvent("CrowdPlay Stats Fail", "Bad Stat Subgroup Description table returned from server", true)
                            Print("Bad Stat Subgroup Description table returned from server: " .. tostring(subgroup.description))
                            errorCode = "BadResponse"
                            break
                          else
                            if type((subgroup.description)[language]) ~= "string" or (subgroup.description)[language] == nil or (subgroup.description)[language] == "" then
                              CreateEventLogEvent("CrowdPlay Stats Fail", "Bad Stat Subgroup Description for language " .. language .. " returned from server", true)
                              Print("Bad Stat Subgroup Description for language " .. language .. " returned from server: " .. tostring((subgroup.description)[language]))
                              errorCode = "BadResponse"
                              break
                            end
                          end
                        end
                        if not errorCode then
                          do
                            if not statType then
                              if type(subgroup.quantity) ~= "number" or subgroup.quantity == nil then
                                statType = "individual"
                              else
                                statType = "summary"
                              end
                            else
                              -- DECOMPILER ERROR at PC318: Unhandled construct in 'MakeBoolean' P1

                              if statType == "individual" and (type(subgroup.quantity) ~= "number" or subgroup.quantity == nil) then
                                CreateEventLogEvent("CrowdPlay Stats Fail", "Bad Stat Subgroup Stat Type returned from server", true)
                                Print("Bad Stat Subgroup Stat Type returned from server: " .. tostring(statType) .. " vs " .. tostring(subgroup.quantity))
                                errorCode = "BadResponse"
                              end
                            end
                            -- DECOMPILER ERROR at PC346: Unhandled construct in 'MakeBoolean' P1

                            if statType == "summary" and (type(subgroup.quantity) ~= "number" or subgroup.quantity == nil) then
                              CreateEventLogEvent("CrowdPlay Stats Fail", "Bad Stat Subgroup Stat Type returned from server", true)
                              Print("Bad Stat Subgroup Stat Type returned from server: " .. tostring(statType) .. " vs " .. tostring(subgroup.quantity))
                              errorCode = "BadResponse"
                            end
                            CreateEventLogEvent("CrowdPlay Stats Fail", "Bad Stat Subgroup Stat Type returned from server", true)
                            Print("Bad Stat Subgroup Stat Type returned from server: " .. tostring(statType) .. " vs " .. tostring(subgroup.quantity))
                            errorCode = "BadResponse"
                            -- DECOMPILER ERROR at PC377: LeaveBlock: unexpected jumping out IF_THEN_STMT

                            -- DECOMPILER ERROR at PC377: LeaveBlock: unexpected jumping out IF_STMT

                            -- DECOMPILER ERROR at PC377: LeaveBlock: unexpected jumping out IF_THEN_STMT

                            -- DECOMPILER ERROR at PC377: LeaveBlock: unexpected jumping out IF_STMT

                          end
                        end
                      end
                    end
                  end
                end
              end
            end
          end
        end
        if not errorCode then
          if type(stat.votecount) ~= "number" then
            CreateEventLogEvent("CrowdPlay Stats Fail", "Bad Stat Subgroups Count returned from server", true)
            Print("Bad Stat Subgroups Count returned from server: " .. tostring(stat.votecount))
            errorCode = "BadResponse"
            break
          else
            if type(stat.votes) ~= "table" or (table.getn)(stat.votes) ~= tonumber(stat.votecount) then
              CreateEventLogEvent("CrowdPlay Stats Fail", "Bad Stat Subgroups Data returned from server", true)
              Print("Bad Stat Subgroups Data returned from server: " .. tostring(stat.votes))
              errorCode = "BadResponse"
              break
            else
              for j,voter in ipairs(stat.votes) do
                if type(voter.name) ~= "string" or voter.name == "" then
                  CreateEventLogEvent("CrowdPlay Stats Fail", "Bad Stat Voter name returned from server", true)
                  Print("Bad Stat Voter name returned from server: " .. tostring(voter.title))
                  errorCode = "BadResponse"
                  break
                else
                  if type(voter.decorator) ~= "string" or not CrowdPlay_IsValidPlayerDecorator(voter.decorator) then
                    CreateEventLogEvent("CrowdPlay Stats Fail", "Bad Stat Voter Decorator returned from server", true)
                    Print("Bad Stat Voter Decorator returned from server: " .. tostring(voter.decorator))
                    errorCode = "BadResponse"
                    break
                  else
                    if type(voter.subgroup) ~= "number" or voter.subgroup < 1 or stat.subgroupcount < voter.subgroup then
                      CreateEventLogEvent("CrowdPlay Stats Fail", "Bad Stat Voter subgroup returned from server", true)
                      Print("Bad Stat Voter subgroup returned from server: " .. tostring(voter.subgroup))
                      errorCode = "BadResponse"
                      break
                    end
                  end
                end
              end
            end
          end
          do
            -- DECOMPILER ERROR at PC510: LeaveBlock: unexpected jumping out IF_THEN_STMT

            -- DECOMPILER ERROR at PC510: LeaveBlock: unexpected jumping out IF_STMT

          end
        end
      end
    end
  end
  if not errorCode then
    statCount = parsedData.count
    crowdStats = {}
    local stattallies = {}
    crowdStats.count = statCount
    for i,stat in ipairs(parsedData.stats) do
      crowdStats[i] = {}
      -- DECOMPILER ERROR at PC528: Confused about usage of register: R12 in 'UnsetPending'

      ;
      (crowdStats[i]).title = (stat.description)[language]
      -- DECOMPILER ERROR at PC533: Confused about usage of register: R12 in 'UnsetPending'

      ;
      (crowdStats[i]).order = tonumber(stat.order)
      -- DECOMPILER ERROR at PC538: Confused about usage of register: R12 in 'UnsetPending'

      ;
      (crowdStats[i]).type = statType or "individual"
      -- DECOMPILER ERROR at PC541: Confused about usage of register: R12 in 'UnsetPending'

      ;
      (crowdStats[i]).subgroupcount = stat.subgroupcount
      -- DECOMPILER ERROR at PC544: Confused about usage of register: R12 in 'UnsetPending'

      ;
      (crowdStats[i]).subgroups = {}
      for j,subgroup in ipairs(stat.subgroups) do
        -- DECOMPILER ERROR at PC552: Confused about usage of register: R17 in 'UnsetPending'

        ((crowdStats[i]).subgroups)[j] = {}
        -- DECOMPILER ERROR at PC557: Confused about usage of register: R17 in 'UnsetPending'

        ;
        (((crowdStats[i]).subgroups)[j]).id = subgroup.id
        -- DECOMPILER ERROR at PC563: Confused about usage of register: R17 in 'UnsetPending'

        ;
        (((crowdStats[i]).subgroups)[j]).title = (subgroup.description)[language]
        -- DECOMPILER ERROR at PC584: Confused about usage of register: R17 in 'UnsetPending'

        ;
        (((crowdStats[i]).subgroups)[j]).votecount = not subgroup.votecount or (type(subgroup.votecount) == "number" and subgroup.votecount) or tonumber(subgroup.votecount) or 0
        -- DECOMPILER ERROR at PC606: Confused about usage of register: R17 in 'UnsetPending'

        if (type(subgroup.quantity) ~= "number" or not subgroup.quantity) and not tonumber(subgroup.quantity) then
          do
            (((crowdStats[i]).subgroups)[j]).quantity = not statType or statType ~= "summary" or 0
            -- DECOMPILER ERROR at PC607: LeaveBlock: unexpected jumping out IF_THEN_STMT

            -- DECOMPILER ERROR at PC607: LeaveBlock: unexpected jumping out IF_STMT

          end
        end
      end
      -- DECOMPILER ERROR at PC611: Confused about usage of register: R12 in 'UnsetPending'

      ;
      (crowdStats[i]).votecount = stat.votecount
      -- DECOMPILER ERROR at PC614: Confused about usage of register: R12 in 'UnsetPending'

      ;
      (crowdStats[i]).votes = {}
      for j,voter in ipairs(stat.votes) do
        if stattallies[voter.subgroup] == nil then
          stattallies[voter.subgroup] = 0
        end
        if stattallies[voter.subgroup] <= kMaxCrowdMemberDisplayCapacity then
          stattallies[voter.subgroup] = stattallies[voter.subgroup] + 1
          -- DECOMPILER ERROR at PC638: Confused about usage of register: R17 in 'UnsetPending'

          ;
          ((crowdStats[i]).votes)[j] = {}
          -- DECOMPILER ERROR at PC643: Confused about usage of register: R17 in 'UnsetPending'

          ;
          (((crowdStats[i]).votes)[j]).name = voter.name
          -- DECOMPILER ERROR at PC648: Confused about usage of register: R17 in 'UnsetPending'

          ;
          (((crowdStats[i]).votes)[j]).decorator = voter.decorator
          -- DECOMPILER ERROR at PC653: Confused about usage of register: R17 in 'UnsetPending'

          ;
          (((crowdStats[i]).votes)[j]).subgroup = voter.subgroup
        end
      end
    end
  end
  do
    return statCount, crowdStats, errorCode
  end
end

local GetResponse = function(postData, requestType)
  -- function num : 0_6 , upvalues : _ENV, kCrowdPlayURL, ParseSessionCode, ParsePlayerCount, ParseChoiceID, ParseCrowdStats, ParseChoiceData, mDebugActions
  local errorCode, sessionCode, sessionHost, sessionPort, sessionLimit, playerCount, players, ballotID, numResponses, responses = nil, nil, nil, nil, nil, nil, nil, nil, nil, nil
  local timeout = 10
  local channel = "socket"
  local responseData, responseCode, responseErrorMsg = nil, nil, nil
  if requestType == "crowdplay_getplayercount" then
    if not TellNetIsConnected() then
      responseCode = "Socket Not Connected"
      responseErrorMsg = "Socket Not Connected"
    else
      responseData = TellNetGetWebClientList(true)
    end
  else
    if requestType == "crowdplay_postchoices" then
      if not TellNetIsConnected() then
        responseCode = "Socket Not Connected"
        responseErrorMsg = "Socket Not Connected"
      else
        if not TellNetPostBallot(postData) then
          responseCode = "Socket Rejected Vote Init"
          responseErrorMsg = "Socket Rejected Vote Init"
        else
          responseData = TellNetGetWebClientVotingResults(true)
        end
      end
    else
      if requestType == "crowdplay_getchoicedata" then
        if not TellNetIsConnected() then
          responseCode = "Socket Not Connected"
          responseErrorMsg = "Socket Not Connected"
        else
          if not TellNetIsVoting() then
            responseCode = "Socket Not Ready For Voting"
            responseErrorMsg = "Socket Not Ready For Voting"
          else
            responseData = TellNetGetWebClientVotingResults(false)
          end
        end
      else
        if requestType == "crowdplay_closevote" then
          if not TellNetIsConnected() then
            responseCode = "Socket Not Connected"
            responseErrorMsg = "Socket Not Connected"
          else
            if not TellNetIsVoting() then
              responseCode = "Socket Not Ready For Voting"
              responseErrorMsg = "Socket Not Ready For Voting"
            else
              if not TellNetEndVotingSession() then
                responseCode = "Socket Failed to Close Voting"
                responseErrorMsg = "Socket Failed to Close Voting"
              else
                responseData = "{}"
              end
            end
          end
        else
          if requestType == "crowdplay_enterpostepisode" then
            if not TellNetIsConnected() then
              responseCode = "Socket Not Connected"
              responseErrorMsg = "Socket Not Connected"
            else
              if not TellNetPostEpisode() then
                responseCode = "Socket Failed To Enter Post Episode"
                responseErrorMsg = "Socket Failed To Enter Post Episode"
              end
            end
            responseData = "{}"
          else
            channel = "webserver"
            responseData = HttpPostAndWait(kCrowdPlayURL, postData, timeout, {}, true)
          end
        end
      end
    end
  end
  if responseData and responseData ~= "" then
    local parsedResponseData = HttpParseJson(responseData)
    if parsedResponseData and type(parsedResponseData) == "table" then
      if channel ~= "webserver" or parsedResponseData.status == "success" then
        if requestType == "crowdplay_gettoken" then
          sessionCode = ParseSessionCode(parsedResponseData)
        else
          -- DECOMPILER ERROR at PC149: Overwrote pending register: R2 in 'AssignReg'

          if requestType == "crowdplay_getplayercount" then
            playerCount = ParsePlayerCount(parsedResponseData)
          else
            -- DECOMPILER ERROR at PC160: Overwrote pending register: R2 in 'AssignReg'

            -- DECOMPILER ERROR at PC161: Unhandled construct in 'MakeBoolean' P1

            if requestType == "crowdplay_postchoices" and channel == "webserver" then
              ballotID = ParseChoiceID(parsedResponseData)
            end
          end
        end
        -- DECOMPILER ERROR at PC168: Overwrote pending register: R2 in 'AssignReg'

        if requestType == "crowdplay_getstats" then
          playerCount = ParseCrowdStats(parsedResponseData)
        else
        end
        -- DECOMPILER ERROR at PC182: Overwrote pending register: R2 in 'AssignReg'

        -- DECOMPILER ERROR at PC183: Overwrote pending register: R11 in 'AssignReg'

        if requestType ~= "crowdplay_closevote" and requestType ~= "crowdplay_enterpostepisode" then
          if requestType == "crowdplay_postexpressions" then
            do
              ballotID = ParseChoiceData(parsedResponseData)
              -- DECOMPILER ERROR at PC201: Overwrote pending register: R2 in 'AssignReg'

              if requestType == "crowdplay_gettoken" and IsDebugBuild() and (GetPreferences())["Beta Menu - Beta Test Crowd Play"] then
                sessionCode = ParseSessionCode(parsedResponseData)
              else
                if parsedResponseData.status == "error" then
                  CreateEventLogEvent("CrowdPlay Fail", "Unknown error code for request " .. requestType .. " from server", true)
                  Print("Unknown error code for request " .. requestType .. " from server: " .. tostring(parsedResponseData.code))
                  -- DECOMPILER ERROR at PC224: Overwrote pending register: R2 in 'AssignReg'

                else
                  CreateEventLogEvent("CrowdPlay Fail", "Unknown status for request " .. requestType .. " from server", true)
                  Print("Unknown status for request " .. requestType .. " from server: " .. tostring(parsedResponseData.status))
                  -- DECOMPILER ERROR at PC243: Overwrote pending register: R2 in 'AssignReg'

                end
              end
              CreateEventLogEvent("CrowdPlay Fail", "Bad response for request " .. requestType .. " from server", true)
              Print("Bad response for request " .. requestType .. " from server: " .. tostring(responseData))
              -- DECOMPILER ERROR at PC262: Overwrote pending register: R2 in 'AssignReg'

              CreateEventLogEvent("CrowdPlay Fail", "Possible http error for request " .. requestType, true)
              Print("Possible http error for request " .. requestType .. ": " .. tostring(responseErrorMsg))
              -- DECOMPILER ERROR at PC280: Overwrote pending register: R2 in 'AssignReg'

              local success = errorCode == nil
              local retVal = nil
              if not success then
                CrowdPlay_SetServerHealthy(false)
              end
              -- DECOMPILER ERROR at PC300: Unhandled construct in 'MakeBoolean' P1

              if not IsDebugBuild() or mDebugActions > 0 then
                mDebugActions = mDebugActions - 1
                local debugContent = (string.format)("Crowd Play Debug Action (%d remaining)\n\n-request header: \n{\"%s\", \"%s\", \"%s\", \"%d\"}\n\n-request data:\n%s\n\n-response header:\n{\"%s\", \"%s\", \"%s\"}\n\n-response data:\n%s\n\n-endofaction\n\n", mDebugActions, requestType, channel, kCrowdPlayURL, timeout, postData, responseCode, responseErrorMsg, success and "true" or "false", responseData)
                Print(debugContent)
              end
              if requestType == "crowdplay_gettoken" then
                return success, sessionCode, sessionHost, sessionPort, sessionLimit, errorCode
              elseif requestType == "crowdplay_getplayercount" then
                return success, playerCount, players, errorCode
              elseif requestType == "crowdplay_postchoices" then
                retVal = ballotID
              elseif requestType == "crowdplay_getstats" then
                return success, responses, errorCode
              else
                return success, ballotID, numResponses, responses, errorCode
              end
              do return success, retVal, errorCode end
              -- DECOMPILER ERROR: 10 unprocessed JMP targets
            end
          end
        end
      end
    end
  end
end

local TrackPlayers = function()
  -- function num : 0_7 , upvalues : _ENV, mPlayerCountThread, kNumControllers, kHostPlayerCount, kPlayerCount, kPollingDelay, mResponseThread, GetResponse, kServerPlayerCount
  if not CrowdPlay_IsEnabled() or mPlayerCountThread then
    return 
  end
  local WaitForPlayers = function()
    -- function num : 0_7_0 , upvalues : _ENV, kNumControllers, kHostPlayerCount, kPlayerCount, kPollingDelay, mResponseThread, GetResponse, kServerPlayerCount, mPlayerCountThread
    local hostPlayerCount = IsDebugBuild() and (GetPreferences())[kNumControllers] or 0
    if hostPlayerCount < 1 then
      hostPlayerCount = 1
    end
    SessionProperties_Set(kHostPlayerCount, hostPlayerCount, "int")
    SessionProperties_Set(kPlayerCount, hostPlayerCount, "int")
    local pollTiming = 0
    local pollInterval = (GetPreferences())[kPollingDelay] or 0.5
    while 1 do
      if CrowdPlay_IsEnabled() then
        if not mResponseThread then
          local postData = (string.format)("\t\t\t\t{ \n\t\t\t\t\t\"crowdplay_getplayercount\":{ \n\t\t\t\t\t\t\"roomcode\": \"%s\"\n\t\t\t\t\t}\n\t\t\t\t}\n\t\t\t\t", CrowdPlay_GetSessionCode())
          local success, serverPlayerCount, serverPlayers, errorCode = GetResponse(postData, "crowdplay_getplayercount")
          if success then
            local playerSetChanged = CrowdPlay_SetServerPlayers(serverPlayers)
            SessionProperties_Set(kServerPlayerCount, serverPlayerCount, "int")
            SessionProperties_Set(kPlayerCount, serverPlayerCount + hostPlayerCount, "int")
            Callback_CrowdPlayNumPlayers:Run(serverPlayerCount, serverPlayers.players, serverPlayers.useTotals, serverPlayers.totals)
          end
        end
        do
          if pollTiming < pollInterval then
            pollTiming = pollTiming + GetFrameTime()
          else
            pollTiming = 0
            local bActivityAllowed, bRetryAllowed, errHeader, errMessage = CrowdPlay_IsActivityAllowed()
            if not bActivityAllowed then
              CrowdPlay_SetServerHealthy(false)
            end
          end
          do
            WaitForNextFrame()
            -- DECOMPILER ERROR at PC88: LeaveBlock: unexpected jumping out DO_STMT

            -- DECOMPILER ERROR at PC88: LeaveBlock: unexpected jumping out DO_STMT

            -- DECOMPILER ERROR at PC88: LeaveBlock: unexpected jumping out IF_THEN_STMT

            -- DECOMPILER ERROR at PC88: LeaveBlock: unexpected jumping out IF_STMT

          end
        end
      end
    end
    mPlayerCountThread = nil
  end

  local thread = ThreadStart(WaitForPlayers)
  if ThreadIsRunning(thread) then
    mPlayerCountThread = thread
  end
end

local GetBestResponse = function()
  -- function num : 0_8 , upvalues : _ENV, mServerResponses
  local maxNum = 0
  local maxIndex = nil
  for i,_ in ipairs(mServerResponses) do
    local num = CrowdPlay_GetNumResponses(i)
    if maxNum < num then
      maxIndex = i
      maxNum = num
    end
  end
  return maxIndex
end

local ExpireServerUnhealthy = function()
  -- function num : 0_9 , upvalues : mServerHealthy, mServerHealthStatusTimer, mServerHealthStatusTimeout, _ENV, mServerHealthThread
  while not mServerHealthy and mServerHealthStatusTimer < mServerHealthStatusTimeout do
    WaitForNextFrame()
    mServerHealthStatusTimer = mServerHealthStatusTimer + GetFrameTime()
    if PlatformIsConnectedToInternet() or CrowdPlay_IsEnabled() then
      mServerHealthStatusTimer = 0
      Callback_CrowdPlayServerHealth:Run(mServerHealthy)
    end
  end
  mServerHealthy = true
  mServerHealthThread = nil
  Callback_CrowdPlayServerHealth:Run(mServerHealthy)
end

local OnGameSceneOpen = function()
  -- function num : 0_10 , upvalues : _ENV, TrackPlayers
  if not CrowdPlay_IsEnabled() then
    return 
  end
  TrackPlayers()
end

CrowdPlay_GetVersion = function()
  -- function num : 0_11 , upvalues : kCrowdPlayVersion
  return kCrowdPlayVersion
end

CrowdPlay_RequestSession = function()
  -- function num : 0_12 , upvalues : _ENV, kCrowdPlayVersion, kMaxCrowdMemberDisplayCapacity, GetResponse, kSessionCode, kSessionServer, kSessionPort, kSessionCrowdMax, kSmallCrowdLimit, kDefaultMaxSmallCrowdCapacity, TrackPlayers, mCrowdExpressions
  if CrowdPlay_IsEnabled() then
    return CrowdPlay_GetSessionCode(), "AlreadyEnabled"
  end
  local specialSessionCodeRequest = ""
  local postData = (string.format)("\t{ \n\t\t\"crowdplay_gettoken\":{\n\t\t\t\"v\":\"%s\",\n\t\t\t\"r\":\"%s\",\n\t\t\t\"c\":\"%d\"\n\t\t}\n\t}\n\t", kCrowdPlayVersion, specialSessionCodeRequest, kMaxCrowdMemberDisplayCapacity)
  local success, sessionCode, sessionServer, sessionPort, sessionLimit, errorCode = GetResponse(postData, "crowdplay_gettoken")
  if success then
    success = TellNetConnect(sessionServer, sessionPort, sessionCode)
    if not success then
      CreateEventLogEvent("CrowdPlay GetToken Fail", "Bad Server Info returned from server")
      Print("Failed to connect to given server: " .. sessionServer .. " : " .. sessionPort .. " : " .. sessionCode)
      errorCode = "BadSocketInit"
    end
  end
  if success then
    SessionProperties_Set(kSessionCode, sessionCode, "String")
    SessionProperties_Set(kSessionServer, sessionServer, "String")
    SessionProperties_Set(kSessionPort, sessionPort, "String")
    local prefs = GetPreferences()
    prefs[kSessionCrowdMax] = 1
    prefs[kSmallCrowdLimit] = sessionLimit or kDefaultMaxSmallCrowdCapacity
    SavePrefs()
    TrackPlayers()
    mCrowdExpressions = {}
  end
  do
    return sessionCode, errorCode
  end
end

CrowdPlay_GetSessionCode = function()
  -- function num : 0_13 , upvalues : _ENV, kSessionCode
  return SessionProperties_Get(kSessionCode) or ""
end

CrowdPlay_GetSessionServer = function()
  -- function num : 0_14 , upvalues : _ENV, kSessionServer, kSessionPort
  return SessionProperties_Get(kSessionServer) or "", SessionProperties_Get(kSessionPort) or ""
end

CrowdPlay_GetNumPlayers = function()
  -- function num : 0_15 , upvalues : _ENV, kPlayerCount
  return SessionProperties_Get(kPlayerCount) or 0
end

CrowdPlay_GetNumServerPlayers = function()
  -- function num : 0_16 , upvalues : _ENV, kServerPlayerCount
  return SessionProperties_Get(kServerPlayerCount) or 0
end

CrowdPlay_GetNumHostPlayers = function()
  -- function num : 0_17 , upvalues : _ENV, kHostPlayerCount
  return SessionProperties_Get(kHostPlayerCount) or 0
end

CrowdPlay_SetServerPlayers = function(playerData)
  -- function num : 0_18 , upvalues : _ENV, mServerPlayers
  local newPlayerCount = 0
  local oldPlayerCount = 0
  local overlapPlayerCount = 0
  for x,newPlayer in pairs(playerData.players) do
    newPlayerCount = newPlayerCount + 1
    for y,oldPlayer in pairs(mServerPlayers) do
      if newPlayer.uuid == oldPlayer.uuid then
        overlapPlayerCount = overlapPlayerCount + 1
        break
      end
    end
  end
  for y,oldPlayer in pairs(mServerPlayers) do
    oldPlayerCount = oldPlayerCount + 1
  end
  mServerPlayers = playerData.players
  if overlapPlayerCount == oldPlayerCount and overlapPlayerCount == newPlayerCount then
    return false
  else
    return true
  end
end

CrowdPlay_GetServerPlayers = function()
  -- function num : 0_19 , upvalues : mServerPlayers
  return mServerPlayers
end

CrowdPlay_GetSmallCrowdLimit = function()
  -- function num : 0_20 , upvalues : _ENV, kSmallCrowdLimit, kDefaultMaxSmallCrowdCapacity
  return (GetPreferences())[kSmallCrowdLimit] or kDefaultMaxSmallCrowdCapacity
end

CrowdPlay_GetSessionCrowdMax = function()
  -- function num : 0_21 , upvalues : _ENV, kSessionCrowdMax
  return (GetPreferences())[kSessionCrowdMax] or 1
end

CrowdPlay_ReportCrowdSize = function(crowdSize)
  -- function num : 0_22 , upvalues : _ENV, kSessionCrowdMax
  if CrowdPlay_GetSessionCrowdMax() < crowdSize then
    local prefs = GetPreferences()
    prefs[kSessionCrowdMax] = crowdSize
    SavePrefs()
  end
end

CrowdPlay_IsStatsEnabled = function()
  -- function num : 0_23 , upvalues : _ENV
  if (GetPreferences())["Beta Menu - Beta Test Crowd Play"] or CrowdPlay_IsEnabled() then
    return true
  end
  return false
end

CrowdPlay_SetServerHealthy = function(healthyState)
  -- function num : 0_24 , upvalues : mServerHealthy, mServerHealthThread, mServerHealthStatusTimer, _ENV, ExpireServerUnhealthy
  mServerHealthy = healthyState
  if not mServerHealthy and not mServerHealthThread then
    mServerHealthy = false
    mServerHealthStatusTimer = 0
    Callback_CrowdPlayServerHealth:Run(mServerHealthy)
    mServerHealthThread = ThreadStart(ExpireServerUnhealthy)
  end
end

CrowdPlay_GetServerHealthy = function()
  -- function num : 0_25 , upvalues : mServerHealthy
  return mServerHealthy
end

CrowdPlay_IsActivityAllowed = function()
  -- function num : 0_26 , upvalues : mSimErr, _ENV
  local simErr = ""
  if mSimErr ~= nil then
    if IsToolBuild() and IsDebugBuild() then
      print("Crowdplay.lua: simulating error with keyword " .. mSimErr)
    end
    simErr = mSimErr
  end
  if simErr == "notttuser" or not IsTTUser() and not (GetPreferences())["Beta Menu - Beta Test Crowd Play"] then
    return false, true, "crowdPlayError_missingAccountCredential_header", "crowdPlayError_missingAccountCredential_message"
  end
  if simErr == "nointernet" or not PlatformIsConnectedToInternet() then
    return false, false, "crowdPlayError_networkDisconnect_header", "crowdPlayError_networkDisconnect_message"
  end
  if simErr == "notellnet" or CrowdPlay_IsEnabled() and not TellNetIsConnected() then
    return false, false, "crowdPlayError_networkDisconnect_header", "crowdPlayError_networkDisconnect_message"
  end
  if simErr == "win10small" or IsPlatformWin10() and Input_UseCursor() and InputHasTouch() then
    return false, false, "crowdPlayError_touchNotSupported_header", "crowdPlayError_touchNotSupported_message"
  end
  if simErr == "agerestricted" or PlatformIsAgeRestricted() then
    return false, true, "crowdPlayError_ageRestricted_header", "crowdPlayError_ageRestricted_message"
  end
  local connected = PlatformIsConnectedToLicenseServer()
  local signed = PlatformIsUserSignedIn()
  if simErr == "agerestricted2" or PlatformIsAgeRestricted() then
    return false, true, "crowdPlayError_ageRestricted_header", "crowdPlayError_ageRestricted_message"
  end
  if simErr == "notconnected" or simErr == "notsignedin" or not connected or not signed then
    return false, true, "crowdPlayError_networkRequired_header", "crowdPlayError_networkRequired_message"
  end
  return true
end

CrowdPlay_SimulateError = function(err)
  -- function num : 0_27 , upvalues : _ENV, mSimErr
  if not err and IsToolBuild() and IsDebugBuild() then
    print("CrowdPlay.lua: supported error simulation keywords: notttuser, nointernet, notellnet, win10small, agerestricted, agerestricted2, notconnected, notsignedin")
  end
  mSimErr = err
end

CrowdPlay_IsValidPlayerDecorator = function(data)
  -- function num : 0_28 , upvalues : _ENV
  if tonumber(data) > -1 and tonumber(data) < 9 then
    return true
  end
  return false
end

CrowdPlay_IsSupported = function()
  -- function num : 0_29 , upvalues : _ENV
  if not CrowdPlay_IsSocketsSupported() then
    return false
  end
  if not PropertyGet("user.prop", "Licensed") then
    return false
  end
  if IsPlatformXbox360() or IsPlatformPS3() then
    return false
  end
  if IsPlatformWiiU() then
    return false
  end
  if IsPlatformIOS() and not IsPlatformAppleTV() then
    return false
  end
  if IsPlatformAndroid() and not IsEngineAndroidTV() then
    return false
  end
  return true
end

CrowdPlay_IsSocketsSupported = function(forceAllChecks)
  -- function num : 0_30 , upvalues : kCrowdPlayVersion, _ENV
  if (kCrowdPlayVersion == nil or kCrowdPlayVersion == "1608.1" or forceAllChecks) and (not rawget(_G, "TellNetConnect") or not rawget(_G, "TellNetIsConnected") or not rawget(_G, "TellNetDisconnect") or not rawget(_G, "TellNetGetWebClientList") or not rawget(_G, "TellNetPostBallot") or not rawget(_G, "TellNetIsVoting") or not rawget(_G, "TellNetGetWebClientVotingResults") or not rawget(_G, "TellNetEndVotingSession") or not rawget(_G, "TellNetSetPauseState")) then
    print("Crowd Play 1608.1 - Sockets are not supported.")
    return false
  end
  return true
end

CrowdPlay_IsEnabled = function()
  -- function num : 0_31 , upvalues : _ENV
  local sessionCode = CrowdPlay_GetSessionCode()
  do return sessionCode ~= nil and sessionCode ~= "" end
  -- DECOMPILER ERROR: 1 unprocessed JMP targets
end

CrowdPlay_IsConnected = function()
  -- function num : 0_32 , upvalues : _ENV
  local prefs = GetPreferences()
  if IsTTUser() then
    return true
  else
    if IsDebugBuild() and prefs["Beta Menu - Beta Test Crowd Play"] then
      return true
    end
  end
  return false
end

CrowdPlay_IsExpressionAllowed = function()
  -- function num : 0_33 , upvalues : _ENV, kEnableExpressions, mVoteActive, mVoteDenouement
  local prefs = GetPreferences()
  if not prefs[kEnableExpressions] then
    return false
  end
  if mVoteActive then
    return false
  end
  if mVoteDenouement then
    return false
  end
  if Game_IsPaused() then
    return false
  end
  return true
end

CrowdPlay_StopAcceptingPlayers = function()
  -- function num : 0_34 , upvalues : mPlayerCountThread, _ENV
  if mPlayerCountThread then
    ThreadKill(mPlayerCountThread)
    mPlayerCountThread = nil
  end
end

CrowdPlay_IsVoteActive = function()
  -- function num : 0_35 , upvalues : mVoteActive
  return mVoteActive
end

CrowdPlay_AddExpressionCount = function(player)
  -- function num : 0_36 , upvalues : mCrowdExpressions
  if not player or not player.id then
    return 
  end
  if not mCrowdExpressions then
    mCrowdExpressions = {}
  end
  if not mCrowdExpressions[player.id] then
    mCrowdExpressions[player.id] = {}
    -- DECOMPILER ERROR at PC21: Confused about usage of register: R1 in 'UnsetPending'

    ;
    (mCrowdExpressions[player.id]).name = player.name
    -- DECOMPILER ERROR at PC25: Confused about usage of register: R1 in 'UnsetPending'

    ;
    (mCrowdExpressions[player.id]).decorator = player.decorator
    -- DECOMPILER ERROR at PC28: Confused about usage of register: R1 in 'UnsetPending'

    ;
    (mCrowdExpressions[player.id]).thumbsdown = 0
    -- DECOMPILER ERROR at PC31: Confused about usage of register: R1 in 'UnsetPending'

    ;
    (mCrowdExpressions[player.id]).thumbsup = 0
  end
  -- DECOMPILER ERROR at PC42: Confused about usage of register: R1 in 'UnsetPending'

  ;
  (mCrowdExpressions[player.id]).thumbsdown = (mCrowdExpressions[player.id]).thumbsdown + (player.thumbsdown or 0)
  -- DECOMPILER ERROR at PC53: Confused about usage of register: R1 in 'UnsetPending'

  ;
  (mCrowdExpressions[player.id]).thumbsup = (mCrowdExpressions[player.id]).thumbsup + (player.thumbsup or 0)
end

CrowdPlay_GetExpressionCount = function(player)
  -- function num : 0_37
  return (player.thumbsdown or 0) + (player.thumbsup or 0)
end

CrowdPlay_SendExpressionCounts = function(maxPlayers)
  -- function num : 0_38 , upvalues : _ENV, mCrowdExpressions, kMaxCrowdMemberDisplayCapacity, GetResponse
  if not CrowdPlay_IsEnabled() or not CrowdPlay_IsExpressionAllowed() or not mCrowdExpressions then
    return 
  end
  local playerCount = 0
  for id,player in pairs(mCrowdExpressions) do
    playerCount = playerCount + 1
  end
  if playerCount < 1 then
    return 
  end
  if not maxPlayers then
    maxPlayers = kMaxCrowdMemberDisplayCapacity
  end
  local playersProcessed = 0
  local playersToFlush = {}
  local playersToLinger = {}
  local localExpressionCount = 0
  local localMaxExpressionCount = 0
  local lastLocalMaxExpressionCount = 0
  while 1 do
    if playersProcessed < maxPlayers and playersProcessed < playerCount then
      localMaxExpressionCount = 0
      for id,player in pairs(mCrowdExpressions) do
        localExpressionCount = CrowdPlay_GetExpressionCount(player)
        if localMaxExpressionCount < localExpressionCount and (lastLocalMaxExpressionCount < 1 or localExpressionCount < lastLocalMaxExpressionCount) then
          localMaxExpressionCount = localExpressionCount
        end
      end
      if localMaxExpressionCount > 0 then
        for id,player in pairs(mCrowdExpressions) do
          localExpressionCount = CrowdPlay_GetExpressionCount(player)
          if localExpressionCount == localMaxExpressionCount then
            playersToFlush[id] = player
            playersProcessed = playersProcessed + 1
          end
        end
        do
          if kMaxCrowdMemberDisplayCapacity + kMaxCrowdMemberDisplayCapacity >= playersProcessed then
            lastLocalMaxExpressionCount = localMaxExpressionCount
            -- DECOMPILER ERROR at PC76: LeaveBlock: unexpected jumping out IF_THEN_STMT

            -- DECOMPILER ERROR at PC76: LeaveBlock: unexpected jumping out IF_STMT

            -- DECOMPILER ERROR at PC76: LeaveBlock: unexpected jumping out DO_STMT

            -- DECOMPILER ERROR at PC76: LeaveBlock: unexpected jumping out IF_THEN_STMT

            -- DECOMPILER ERROR at PC76: LeaveBlock: unexpected jumping out IF_STMT

            -- DECOMPILER ERROR at PC76: LeaveBlock: unexpected jumping out IF_THEN_STMT

            -- DECOMPILER ERROR at PC76: LeaveBlock: unexpected jumping out IF_STMT

          end
        end
      end
    end
  end
  if playersProcessed < playerCount then
    for id,player in pairs(mCrowdExpressions) do
      if CrowdPlay_GetExpressionCount(player) < lastLocalMaxExpressionCount then
        playersToLinger[id] = player
      end
    end
    mCrowdExpressions = playersToLinger
  else
    mCrowdExpressions = {}
  end
  local playerString = ""
  for id,player in pairs(playersToFlush) do
    playerString = playerString .. (string.format)("\t\t%s{\n\t\t\t\"id\": \"%s\",\n\t\t\t\"decorator\": \"%s\",\n\t\t\t\"name\": \"%s\",\n\t\t\t\"thumbsup\": \"%d\",\n\t\t\t\"thumbsdown\": \"%d\"\n\t\t}\n\t\t", playerString ~= "" and "," or "", id, player.decorator, player.name, player.thumbsup or 0, player.thumbsdown or 0)
  end
  local postData = (string.format)("\t{ \n\t\t\"crowdplay_postexpressions\":{ \n\t\t\t\"roomcode\": \"%s\",\n\t\t\t\"players\": [\n\t\t\t\t%s\n\t\t\t]\n\t\t}\n\t}\n\t", CrowdPlay_GetSessionCode(), playerString)
  if IsDebugBuild() then
    local success = GetResponse(postData, "crowdplay_postexpressions")
  end
end

CrowdPlay_ReBeginChoice = function()
  -- function num : 0_39 , upvalues : mVoteActive, mResponseThread, _ENV, mChoiceNodeID, mChoiceOptionTable
  if not mVoteActive then
    return 
  end
  if mResponseThread then
    if ThreadIsRunning(mResponseThread) then
      ThreadKill(mResponseThread)
    end
    mResponseThread = nil
  end
  CrowdPlay_BeginChoice(mChoiceNodeID, mChoiceOptionTable)
end

CrowdPlay_BeginChoice = function(choiceNodeID, optionTable)
  -- function num : 0_40 , upvalues : _ENV, mResponseThread, mSubChoiceIDs, GetResponse, mVoteActive, mVoteDenouement, mHostResponseOvertimeThread, mServerResponses, mHostResponses, mNumServerResponses, mLocalPlayerResponse, mBallotID, kPollingDelay, GetBestResponse
  if not CrowdPlay_IsEnabled() or mResponseThread then
    return false
  end
  CrowdPlay_SendExpressionCounts()
  if not optionTable then
    CrowdPlay_SetChoiceInitState(choiceNodeID or "0", {})
    local optionString = ""
    mSubChoiceIDs = {}
    local numOptions = nil
    for i,opt in ipairs(optionTable) do
      optionString = optionString .. (string.format)("\t\t{\n\t\t\t\"id\": \"%d\",\n\t\t\t\"mappedid\": \"%d\",\n\t\t\t\"text\": \"%s\",\n\t\t\t\"button\": \"%s\",\n\t\t\t\"nodeid\": \"%s\"\n\t\t}%s\n\t\t", i, opt.mappedid or 0, opt.text, tostring(opt.button), opt.choiceid, i < #optionTable and "," or "")
      mSubChoiceIDs[i] = opt.choiceid
      numOptions = i
    end
    local postData = (string.format)("\t{ \n\t\t\"message_type\":\"cp_gameclient_postchoices\",\n\t\t\"room_code\": \"%s\",\n\t\t\"ballotid\": \"%s\",\n\t\t\"choices\": [\n\t\t\t%s\n\t\t]\n\t}\n\t", CrowdPlay_GetSessionCode(), choiceNodeID, optionString)
    local success, ballotID, errorCode = GetResponse(postData, "crowdplay_postchoices")
    if not ballotID and CrowdPlay_IsSocketsSupported() then
      ballotID = choiceNodeID
    end
    if not ballotID then
      success = false
    end
    if success then
      mVoteActive = true
      if mVoteDenouement then
        CrowdPlay_ChoiceSetDenouement(false)
      end
      Callback_CrowdPlayRefresh:Run()
      local WaitForResponses = function()
    -- function num : 0_40_0 , upvalues : mHostResponseOvertimeThread, mServerResponses, mHostResponses, optionTable, _ENV, mNumServerResponses, mLocalPlayerResponse, mBallotID, ballotID, kPollingDelay, GetResponse, GetBestResponse, mResponseThread
    if mHostResponseOvertimeThread then
      mHostResponseOvertimeThread = nil
    end
    mServerResponses = {}
    mHostResponses = {}
    for i = 1, #optionTable do
      mServerResponses[i] = {}
      -- DECOMPILER ERROR at PC17: Confused about usage of register: R4 in 'UnsetPending'

      ;
      (mServerResponses[i]).votecount = 0
    end
    for i = 1, CrowdPlay_GetNumHostPlayers() do
      mHostResponses[i] = (math.random)(1, #optionTable)
    end
    mHostResponses[1] = 0
    mNumServerResponses = 0
    mLocalPlayerResponse = nil
    mBallotID = ballotID
    local pollTiming = 0
    local pollInterval = (GetPreferences())[kPollingDelay] or 0.5
    while 1 do
      if CrowdPlay_IsEnabled() then
        local choicePostData = (string.format)("\t\t\t\t{ \n\t\t\t\t\t\"crowdplay_getchoicedata\":{ \n\t\t\t\t\t\t\"roomcode\": \"%s\",\n\t\t\t\t\t\t\"ballotid\": \"%s\",\n\t\t\t\t\t\t\"choiceid\": \"%s\"\n\t\t\t\t\t}\n\t\t\t\t}\n\t\t\t\t", CrowdPlay_GetSessionCode(), ballotID, ballotID)
        local choiceSuccess, returnedBallotID, numResponses, responses, choiceErrorCode = GetResponse(choicePostData, "crowdplay_getchoicedata")
        if choiceSuccess and returnedBallotID == ballotID then
          CrowdPlay_SetServerResponses(responses)
          if mNumServerResponses == 0 or numResponses ~= mNumServerResponses then
            mNumServerResponses = numResponses
            for i,count in ipairs(responses) do
              if count ~= mServerResponses[i] then
                mServerResponses[i] = count
              end
            end
            Callback_CrowdPlayResponse:Run()
          end
          if CrowdPlay_GetNumResponses() == CrowdPlay_GetNumPlayers() then
            Callback_CrowdPlayFinalResponse:Run(GetBestResponse())
            break
          end
        end
        if pollTiming < pollInterval then
          pollTiming = pollTiming + GetFrameTime()
        else
          pollTiming = 0
          local bActivityAllowed, bRetryAllowed, errHeader, errMessage = CrowdPlay_IsActivityAllowed()
          if not bActivityAllowed then
            CrowdPlay_SetServerHealthy(false)
          end
        end
        do
          do
            WaitForNextFrame()
            -- DECOMPILER ERROR at PC120: LeaveBlock: unexpected jumping out DO_STMT

            -- DECOMPILER ERROR at PC120: LeaveBlock: unexpected jumping out IF_THEN_STMT

            -- DECOMPILER ERROR at PC120: LeaveBlock: unexpected jumping out IF_STMT

          end
        end
      end
    end
    mResponseThread = nil
  end

      local thread = ThreadStart(WaitForResponses)
      if ThreadIsRunning(thread) then
        mResponseThread = thread
      end
    else
      do
        do return false end
        return true
      end
    end
  end
end

CrowdPlay_SetChoiceInitState = function(nodeID, optionTable)
  -- function num : 0_41 , upvalues : mChoiceNodeID, mChoiceOptionTable
  mChoiceNodeID = nodeID
  mChoiceOptionTable = optionTable
end

CrowdPlay_SetLocalPlayerResponse = function(index)
  -- function num : 0_42 , upvalues : _ENV, mResponseThread, mLocalPlayerResponse, mHostResponses, GetBestResponse, kHostMakesChoice, mHostResponseOvertimer, mHostResponseOvertimeout, kHostResponseOvertimeout, mHostResponseOvertimeThread
  if not CrowdPlay_IsEnabled() or not mResponseThread or not index or mLocalPlayerResponse then
    return 
  end
  mLocalPlayerResponse = index
  mHostResponses[1] = index
  Callback_CrowdPlayResponse:Run()
  if CrowdPlay_GetNumResponses() == CrowdPlay_GetNumPlayers() then
    Callback_CrowdPlayFinalResponse:Run(GetBestResponse())
  else
    if not (GetPreferences())[kHostMakesChoice] then
      mHostResponseOvertimer = 0
      mHostResponseOvertimeout = (GetPreferences())[kHostResponseOvertimeout] or 10
      if not mHostResponseOvertimeThread then
        mHostResponseOvertimeThread = ThreadStart(CrowdPlay_HostResponseOvertimer)
      end
    end
  end
end

CrowdPlay_HostResponseOvertimer = function()
  -- function num : 0_43 , upvalues : mHostResponseOvertimer, mHostResponseOvertimeout, mVoteActive, _ENV, GetBestResponse, mHostResponseOvertimeThread
  while mHostResponseOvertimer < mHostResponseOvertimeout and mVoteActive do
    WaitForNextFrame()
    mHostResponseOvertimer = mHostResponseOvertimer + GetFrameTime()
  end
  if mVoteActive then
    Callback_CrowdPlayFinalResponse:Run(GetBestResponse())
  end
  mHostResponseOvertimeThread = nil
end

CrowdPlay_GetHostResponse = function(controllerId)
  -- function num : 0_44 , upvalues : mHostResponses
  return mHostResponses[controllerId] or 0
end

CrowdPlay_SetServerResponses = function(responses)
  -- function num : 0_45 , upvalues : mServerResponses
  mServerResponses = responses
end

CrowdPlay_GetServerResponses = function()
  -- function num : 0_46 , upvalues : mServerResponses
  return mServerResponses
end

CrowdPlay_GetResponses = function()
  -- function num : 0_47 , upvalues : _ENV
  local responses = CrowdPlay_GetServerResponses()
  local numHostPlayers = CrowdPlay_GetNumHostPlayers()
  if not responses then
    responses = {}
    responses.playercount = numHostPlayers
  end
  if not responses.players then
    responses.players = {}
  end
  if not responses.controllers then
    responses.controllers = {}
  end
  for i = 1, numHostPlayers do
    -- DECOMPILER ERROR at PC25: Confused about usage of register: R6 in 'UnsetPending'

    (responses.controllers)[i] = {}
    -- DECOMPILER ERROR at PC28: Confused about usage of register: R6 in 'UnsetPending'

    ;
    ((responses.controllers)[i]).id = i
    -- DECOMPILER ERROR at PC31: Confused about usage of register: R6 in 'UnsetPending'

    ;
    ((responses.controllers)[i]).decorator = "0"
    -- DECOMPILER ERROR at PC39: Confused about usage of register: R6 in 'UnsetPending'

    ;
    ((responses.controllers)[i]).name = "P" .. tostring(i)
    -- DECOMPILER ERROR at PC45: Confused about usage of register: R6 in 'UnsetPending'

    ;
    ((responses.controllers)[i]).votedfor = CrowdPlay_GetHostResponse(i)
  end
  return responses
end

CrowdPlay_GetNumResponses = function(index)
  -- function num : 0_48 , upvalues : _ENV, mServerResponses, mHostResponses, mLocalPlayerResponse, mNumServerResponses
  if not CrowdPlay_IsEnabled() then
    return 0
  end
  if index then
    if index < 1 or #mServerResponses < index then
      return 0
    end
    local hostResponsesForIndex = 0
    if #mHostResponses > 0 then
      for i,response in ipairs(mHostResponses) do
        if response == index then
          hostResponsesForIndex = hostResponsesForIndex + 1
        end
      end
    else
      do
        do
          if mLocalPlayerResponse ~= nil and mLocalPlayerResponse == index then
            hostResponsesForIndex = 1
          end
          do return (mServerResponses[index] ~= nil and (mServerResponses[index]).votecount or 0) + hostResponsesForIndex end
          do return mNumServerResponses + (mLocalPlayerResponse ~= nil and mLocalPlayerResponse ~= 0 and 1 or 0) end
        end
      end
    end
  end
end

CrowdPlay_GetSelectedResponse = function(bEndChoice)
  -- function num : 0_49 , upvalues : _ENV, GetBestResponse
  if not CrowdPlay_IsEnabled() then
    return nil
  end
  if bEndChoice ~= false then
    CrowdPlay_EndChoice()
  end
  return GetBestResponse()
end

CrowdPlay_EndChoice = function(activatedChoice)
  -- function num : 0_50 , upvalues : _ENV, mResponseThread, mBallotID, GetResponse, kNumControllers, kServerPlayerCount, kPlayerCount, mChoiceNodeID, mSubChoiceIDs, kCrowdPlayVersion, mVoteActive, mHostResponseOvertimeThread, mNumServerResponses, mServerResponses, GetBestResponse
  if not CrowdPlay_IsEnabled() then
    return 
  end
  if mResponseThread then
    ThreadKill(mResponseThread)
    mResponseThread = nil
  end
  if not mBallotID then
    return 
  end
  local postData = (string.format)("\t{ \n\t\t\"crowdplay_getplayercount\":{ \n\t\t\t\"roomcode\": \"%s\"\n\t\t}\n\t}\n\t", CrowdPlay_GetSessionCode())
  local success, serverPlayerCount, serverPlayers, errorCode = GetResponse(postData, "crowdplay_getplayercount")
  if success then
    local playerSetChanged = CrowdPlay_SetServerPlayers(serverPlayers)
    local hostPlayerCount = IsDebugBuild() and (GetPreferences())[kNumControllers] or 0
    if hostPlayerCount < 1 then
      hostPlayerCount = 1
    end
    SessionProperties_Set(kServerPlayerCount, serverPlayerCount, "int")
    SessionProperties_Set(kPlayerCount, serverPlayerCount + hostPlayerCount, "int")
    Callback_CrowdPlayNumPlayers:Run(serverPlayerCount, serverPlayers.players, serverPlayers.useTotals, serverPlayers.totals)
  end
  do
    ThreadStart(function()
    -- function num : 0_50_0 , upvalues : _ENV, mChoiceNodeID, mSubChoiceIDs, activatedChoice, kCrowdPlayVersion, mBallotID, GetResponse, mVoteActive, mHostResponseOvertimeThread, mNumServerResponses, mServerResponses, GetBestResponse
    local optionString = ""
    local tallyString = ""
    local numResponses = CrowdPlay_GetNumResponses()
    local voteTable = CrowdPlay_GetResponses()
    local vote = 0
    local voteChoiceID = 0
    local voteChoiceCapacity = 6
    local voteChoiceBuckets = {}
    local i = 1
    local ballotNodeID = mChoiceNodeID or "0"
    if voteTable ~= nil then
      for id,voter in pairs(voteTable.controllers) do
        if not voter or not voter.votedfor or voter.votedfor < 1 or voter.votedfor > 4 then
          vote = 0
        else
          vote = tonumber(voter.votedfor)
        end
        if mSubChoiceIDs[vote] == nil then
          voteChoiceID = 0
        else
          voteChoiceID = mSubChoiceIDs[vote]
        end
        if not voteChoiceBuckets[vote] then
          voteChoiceBuckets[vote] = 1
        else
          voteChoiceBuckets[vote] = voteChoiceBuckets[vote] + 1
        end
        if i <= 1 or not "," then
          do
            optionString = optionString .. (string.format)("\t\t\t\t\t%s{\n\t\t\t\t\t\t\"id\": \"%d\",\n\t\t\t\t\t\t\"decorator\": \"%s\",\n\t\t\t\t\t\t\"name\": \"%s\",\n\t\t\t\t\t\t\"votedfor\": \"%d\",\n\t\t\t\t\t\t\"votedfornodeid\": \"{%s}\"\n\t\t\t\t\t}\n\t\t\t\t\t", voteChoiceBuckets[vote] > voteChoiceCapacity or "", voter.id, voter.decorator, voter.name, vote, voteChoiceID)
            i = i + 1
            -- DECOMPILER ERROR at PC73: LeaveBlock: unexpected jumping out IF_THEN_STMT

            -- DECOMPILER ERROR at PC73: LeaveBlock: unexpected jumping out IF_STMT

          end
        end
      end
      for id,voter in pairs(voteTable.players) do
        if not voter or not voter.votedfor or voter.votedfor < 1 or voter.votedfor > 4 then
          vote = 0
        else
          vote = tonumber(voter.votedfor)
        end
        if mSubChoiceIDs[vote] == nil then
          voteChoiceID = 0
        else
          voteChoiceID = mSubChoiceIDs[vote]
        end
        if not voteChoiceBuckets[vote] then
          voteChoiceBuckets[vote] = 1
        else
          voteChoiceBuckets[vote] = voteChoiceBuckets[vote] + 1
        end
        if i <= 1 or not "," then
          do
            optionString = optionString .. (string.format)("\t\t\t\t\t%s{\n\t\t\t\t\t\t\"id\": \"%s\",\n\t\t\t\t\t\t\"decorator\": \"%s\",\n\t\t\t\t\t\t\"name\": \"%s\",\n\t\t\t\t\t\t\"votedfor\": \"%d\",\n\t\t\t\t\t\t\"votedfornodeid\": \"{%s}\"\n\t\t\t\t\t}\n\t\t\t\t\t", voteChoiceBuckets[vote] > voteChoiceCapacity or "", voter.id, voter.decorator, voter.name, vote, voteChoiceID)
            i = i + 1
            -- DECOMPILER ERROR at PC131: LeaveBlock: unexpected jumping out IF_THEN_STMT

            -- DECOMPILER ERROR at PC131: LeaveBlock: unexpected jumping out IF_STMT

          end
        end
      end
      if activatedChoice then
        local winnerNodeID = (string.sub)(activatedChoice["Choice Object ID"], 9)
        optionString = optionString .. (string.format)("\t\t\t\t%s{\n\t\t\t\t\t\"id\": \"winner\",\n\t\t\t\t\t\"decorator\": \"\",\n\t\t\t\t\t\"name\": \"\",\n\t\t\t\t\t\"votedfor\": \"\",\n\t\t\t\t\t\"votedfornodeid\": \"{%s}\"\n\t\t\t\t}\n\t\t\t\t", optionString ~= "" and "," or "", winnerNodeID)
      end
    end
    do
      i = 1
      for id,tally in pairs(voteChoiceBuckets) do
        if i <= 1 or not "," then
          do
            tallyString = tallyString .. (string.format)("\t\t\t\t%s{\n\t\t\t\t\t\"id\": \"%s\",\n\t\t\t\t\t\"tally\": \"%s\"\n\t\t\t\t}\n\t\t\t\t", voteTable[id] == nil or (voteTable[id]).votecount == nil or "", id, (voteTable[id]).votecount)
            i = i + 1
            -- DECOMPILER ERROR at PC182: LeaveBlock: unexpected jumping out IF_THEN_STMT

            -- DECOMPILER ERROR at PC182: LeaveBlock: unexpected jumping out IF_STMT

          end
        end
      end
      local postData = (string.format)("\t\t{ \n\t\t\t\"crowdplay_closechoice\":{\n\t\t\t\t\"v\": \"%s\",\n\t\t\t\t\"roomcode\": \"%s\",\n\t\t\t\t\"ballotid\": \"{%s}\",\n\t\t\t\t\"choiceid\": \"{%s}\",\n\t\t\t\t\"nodeid\": \"{%s}\",\n\t\t\t\t\"context\": \"%s\",\n\t\t\t\t\"votes\": [\n\t\t\t\t\t%s\n\t\t\t\t],\n\t\t\t\t\"votetallies\": [\n\t\t\t\t\t%s\n\t\t\t\t]\n\t\t\t}\n\t\t}\n\t\t", kCrowdPlayVersion, CrowdPlay_GetSessionCode(), mBallotID, mBallotID, ballotNodeID, SubProject_GetCurrent(), optionString, tallyString)
      local success, returnedBallotID, numResponses, responses, errorCode = GetResponse(postData, "crowdplay_closechoice")
      mVoteActive = false
      mHostResponseOvertimeThread = nil
      if success and returnedBallotID == mBallotID then
        if numResponses ~= mNumServerResponses then
          mNumServerResponses = numResponses
          for i,count in ipairs(responses) do
            if count ~= mServerResponses[i] then
              mServerResponses[i] = count
            end
          end
          Callback_CrowdPlayResponse:Run()
        end
        if CrowdPlay_GetNumResponses() == CrowdPlay_GetNumPlayers() then
          Callback_CrowdPlayFinalResponse:Run(GetBestResponse())
        end
        mBallotID = nil
      else
        if not success then
          CreateEventLogEvent("CrowdPlay Close Choice Fail", "General fail", true)
        else
          if returnedBallotID ~= mBallotID then
            if not returnedBallotID then
              returnedBallotID = "nil"
            end
            local expectedBallotID = mBallotID or "nil"
            CreateEventLogEvent("CrowdPlay Close Choice Fail", "Unexpected Ballot ID: " .. returnedBallotID .. " vs expected: " .. expectedBallotID, true)
          else
            do
              CreateEventLogEvent("CrowdPlay Close Choice Fail", "Unknown fail", true)
            end
          end
        end
      end
    end
  end
)
  end
end

CrowdPlay_ChoiceSetDenouement = function(bNewState)
  -- function num : 0_51 , upvalues : mVoteDenouement, _ENV, GetResponse
  if bNewState == mVoteDenouement then
    return 
  end
  mVoteDenouement = bNewState
  if mVoteDenouement then
    Callback_CrowdPlayResponse:Run()
    local success, errorCode = GetResponse("{}", "crowdplay_closevote")
    TellNetSetPauseState(true)
  else
    do
      TellNetSetPauseState(false)
    end
  end
end

CrowdPlay_EnterPostEpisode = function()
  -- function num : 0_52 , upvalues : _ENV, GetResponse
  if not CrowdPlay_IsEnabled() then
    return 
  end
  local success, errorCode = GetResponse("{}", "crowdplay_enterpostepisode")
  if not success then
  end
end

CrowdPlay_EndSession = function()
  -- function num : 0_53 , upvalues : _ENV, kSessionCode, kPlayerCount, kHostPlayerCount, kServerPlayerCount
  if not CrowdPlay_IsEnabled() then
    return 
  end
  Callback_CrowdPlayEndSession:Run()
  local postData = (string.format)("\t{ \n\t\t\"crowdplay_killroom\":{ \n\t\t\t\"roomcode\": \"%s\"\n\t\t}\n\t}\n\t", CrowdPlay_GetSessionCode())
  local timeout = 10
  ThreadStart(TellNetDisconnect)
  SessionProperties_Set(kSessionCode, "", "String")
  SessionProperties_Set(kPlayerCount, 0, "int")
  SessionProperties_Set(kHostPlayerCount, 0, "int")
  SessionProperties_Set(kServerPlayerCount, 0, "int")
end

CrowdPlay_GetContextForEpisode = function(epNum)
  -- function num : 0_54 , upvalues : _ENV
  local projects = ContainerToTable(PropertyGet("resourceSets", "Projects"))
  local subEpNum = ""
  for i,project in ipairs(projects) do
    subEpNum = SubProject_GetEpisodeNumber(project)
    if SubProject_IsEpisode(project) and tostring(SubProject_GetEpisodeNumber(project)) == epNum then
      return project
    end
  end
  return nil
end

CrowdPlay_RequestCrowdStats = function(context)
  -- function num : 0_55 , upvalues : _ENV, GetResponse
  if not CrowdPlay_IsEnabled() then
    return false
  end
  local postData = (string.format)("\t{ \n\t\t\"crowdplay_getstats\":{ \n\t\t\t\"roomcode\": \"%s\",\n\t\t\t\"context\": \"%s\"\n\t\t}\n\t}\n\t", CrowdPlay_GetSessionCode(), context)
  local success, crowdStats, errorCode = GetResponse(postData, "crowdplay_getstats")
  if not success then
    return success, crowdStats, errorCode
  end
end

CrowdPlay_HostMakesChoice = function()
  -- function num : 0_56 , upvalues : _ENV, kHostMakesChoice
  return PropertyGet(GetPreferences(), kHostMakesChoice)
end

CrowdPlay_RequestDebugging = function(numActions)
  -- function num : 0_57 , upvalues : mDebugActions
  if mDebugActions < 1 then
    mDebugActions = numActions
  end
end

if IsToolBuild() then
  CreateAssets()
end
Callback_OnGameSceneOpen:Add(OnGameSceneOpen)
