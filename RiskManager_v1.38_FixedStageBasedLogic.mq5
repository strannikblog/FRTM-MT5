//+------------------------------------------------------------------+
//|                                    RiskManagerIndicator.mq5     |
//|                             Risk Management Indicator System    |
//|                    Based on RISK_MANAGER_SYSTEM_LOGIC.md v1.0   |
//+------------------------------------------------------------------+
#property copyright "Risk Management Indicator"
#property link      ""
#property version   "1.38"
#property description "3-Level Dynamic Risk Management with Recovery Targets"
#property indicator_chart_window
#property indicator_plots   0

//+------------------------------------------------------------------+
//| Input Parameters                                                 |
//+------------------------------------------------------------------+
input group "=== Risk Management Settings ==="
input double inpMaxRiskPercent = 2.0;           // Maximum Risk %
input double inpMinRiskPercent = 0.5;           // Minimum Risk %
input double inpRecoveryThreshold = 0.5;        // Recovery Multiplier (fixed at 0.5)
input bool inpAutoDetectTrades = true;          // Auto-detect new closed trades

input group "=== Chart Control Settings ==="
input bool inpRunOnAllCharts = false;           // Run on all charts (false = single chart mode)
input string inpPreferredSymbol = "";           // Preferred symbol (empty = any symbol)

input group "=== Display Settings ==="
input color inpLabelBackgroundColor = C'240,240,240';  // Label background
input color inpLabelTextColor = C'50,50,50';            // Label text color
input int inpLabelX = 20;                               // Panel X position (pixels from left)
input int inpLabelY = 30;                               // Panel Y position (pixels from top)
input bool inpShowCompactDisplay = false;               // Compact format (false = detailed)
input int inpFontSize = 9;                              // Font size

//+------------------------------------------------------------------+
//| Risk Manager State Structure - Based on System Logic Manual     |
//+------------------------------------------------------------------+
struct RiskManagerState {
    // Three Risk Levels
    double maxRiskPercent;        // User defined (e.g., 2.0)
    double midRiskPercent;        // Calculated (50% of max, e.g., 1.0)
    double minRiskPercent;        // User defined (e.g., 0.5)
    double currentRiskPercent;    // Current active risk (one of the three levels)

    // Recovery Journey Variables
    double peakEquity;            // Highest equity ever reached
    double startingEquity;        // Equity after last losing trade (recovery start)
    double accumulatedProfit;     // Profit accumulated since last loss
    double currentLevelTarget;    // Target to reach immediate next level
    double maxLevelTarget;        // Total target to reach MAX level

    // Fixed Target Amounts for Display (stage-based logic)
    double targetMidToMax;        // Fixed amount needed from MID to MAX (for display reference)

    // Trade Tracking
    int consecutiveLosses;        // Current loss streak
    datetime journeyStartTime;    // When current recovery journey started
    ulong lastProcessedTicket;    // Avoid reprocessing same trades
    string lastTradeType;          // "LOSS" or "PROFIT" for logging

    // System State
    string accountNumber;         // Account identifier
    datetime lastUpdateTime;      // Last state update
};

//+------------------------------------------------------------------+
//| Global Variables                                                 |
//+------------------------------------------------------------------+
RiskManagerState g_state;
string g_labelName = "RiskManagerLabel";
string g_buttonName = "RiskManagerResetButton";
bool g_initialized = false;
bool g_shouldRun = false;
bool g_stateModified = false;

//+------------------------------------------------------------------+
//| Chart Control Functions                                         |
//+------------------------------------------------------------------+
bool ShouldRunOnChart() {
    if(inpRunOnAllCharts) {
        return true;
    }

    if(inpPreferredSymbol != "") {
        if(StringCompare(_Symbol, inpPreferredSymbol, false) == 0) {
            return true;
        } else {
            return false;
        }
    }

    return true; // Default: let user control by not adding to multiple charts
}

//+------------------------------------------------------------------+
//| State Serialization Functions                                      |
//+------------------------------------------------------------------+
string StateToCsv(const RiskManagerState &state) {
    return StringFormat(
        "%.6f,%.6f,%.6f,%.6f,%.2f,%.2f,%.2f,%.2f,%.2f,%d,%d,%s,%llu,%s,%d",
        state.maxRiskPercent,
        state.midRiskPercent,
        state.currentRiskPercent,
        state.minRiskPercent,
        state.peakEquity,
        state.startingEquity,
        state.accumulatedProfit,
        state.currentLevelTarget,
        state.maxLevelTarget,
        state.targetMidToMax,
        state.consecutiveLosses,
        (int)state.journeyStartTime,
        state.lastTradeType,
        state.lastProcessedTicket,
        state.accountNumber,
        (int)state.lastUpdateTime
    );
}

bool CsvToState(const string csvStr, RiskManagerState &state) {
    string parts[];
    int count = StringSplit(csvStr, ',', parts);

    if(count != 16) {
        Print("❌ Invalid state file format. Expected 16 fields, got ", count);
        return false;
    }

    state.maxRiskPercent = StringToDouble(parts[0]);
    state.midRiskPercent = StringToDouble(parts[1]);
    state.currentRiskPercent = StringToDouble(parts[2]);
    state.minRiskPercent = StringToDouble(parts[3]);
    state.peakEquity = StringToDouble(parts[4]);
    state.startingEquity = StringToDouble(parts[5]);
    state.accumulatedProfit = StringToDouble(parts[6]);
    state.currentLevelTarget = StringToDouble(parts[7]);
    state.maxLevelTarget = StringToDouble(parts[8]);
    state.targetMidToMax = StringToDouble(parts[9]);
    state.consecutiveLosses = (int)StringToInteger(parts[10]);
    state.journeyStartTime = (datetime)StringToInteger(parts[11]);
    state.lastTradeType = parts[12];
    state.lastProcessedTicket = StringToInteger(parts[13]);
    state.accountNumber = parts[14];
    state.lastUpdateTime = (datetime)StringToInteger(parts[15]);

    return true;
}

//+------------------------------------------------------------------+
//| Transaction Logging Functions                                     |
//+------------------------------------------------------------------+
void LogTransactionToSpreadsheet(const RiskManagerState &state, double profit, string tradeType) {
    string fileName = "RiskManager\\RiskManager_Transactions_" + state.accountNumber + ".csv";
    string oldFileName = "RiskManager_Transactions_" + state.accountNumber + ".csv";

    // Try to open file to check if it exists and create header if needed
    int fileHandle = FileOpen(fileName, FILE_READ | FILE_WRITE | FILE_CSV | FILE_ANSI, ",");
    if(fileHandle == INVALID_HANDLE) {
        // File doesn't exist, create it with header
        fileHandle = FileOpen(fileName, FILE_WRITE | FILE_CSV | FILE_ANSI, ",");
        if(fileHandle != INVALID_HANDLE) {
            FileWriteString(fileHandle, "Date,Time,RiskLevel,Equity,Profit,TradeType,NextLevel,NextLevelTarget,MaxLevelTarget,StartingEquity,AccumulatedProfit\n");
            FileClose(fileHandle);
            Print("📊 Created transaction log: ", fileName);
        }
    } else {
        // File exists, check if it has header by reading first line
        string header = FileReadString(fileHandle);
        if(StringLen(header) == 0) {
            // Empty file, write header
            FileSeek(fileHandle, 0, SEEK_SET);
            FileWriteString(fileHandle, "Date,Time,RiskLevel,Equity,Profit,TradeType,NextLevel,NextLevelTarget,MaxLevelTarget,StartingEquity,AccumulatedProfit\n");
            Print("📊 Created transaction log: ", fileName);
        }
        FileClose(fileHandle);
    }

    // Append transaction (reopen file)
    fileHandle = FileOpen(fileName, FILE_READ | FILE_WRITE | FILE_CSV | FILE_ANSI, ",");
    if(fileHandle != INVALID_HANDLE) {
        datetime now = TimeCurrent();
        double currentEquity = AccountInfoDouble(ACCOUNT_EQUITY);

        string currentLevelStr = DoubleToString(state.currentRiskPercent, 2) + "%";
        string nextLevelStr = "";
        string nextTargetStr = "";

        // Determine next level and targets
        if(state.currentRiskPercent == state.minRiskPercent) {
            nextLevelStr = DoubleToString(state.midRiskPercent, 2) + "%";
            nextTargetStr = "$" + DoubleToString(state.currentLevelTarget - currentEquity, 2);
        } else if(state.currentRiskPercent == state.midRiskPercent) {
            nextLevelStr = DoubleToString(state.maxRiskPercent, 2) + "%";
            nextTargetStr = "$" + DoubleToString(state.currentLevelTarget - currentEquity, 2);
        } else if(state.currentRiskPercent == state.maxRiskPercent) {
            nextLevelStr = "MAX";
            nextTargetStr = "At Target";
        }

        string maxTargetStr = "$" + DoubleToString(state.maxLevelTarget - currentEquity, 2);
        string startingEqStr = "$" + DoubleToString(state.startingEquity, 2);
        string accumulatedStr = "$" + DoubleToString(state.accumulatedProfit, 2);

        FileWrite(fileHandle,
            TimeToString(now, TIME_DATE),
            TimeToString(now, TIME_SECONDS),
            currentLevelStr,
            DoubleToString(currentEquity, 2),
            DoubleToString(profit, 2),
            tradeType,
            nextLevelStr,
            nextTargetStr,
            maxTargetStr,
            startingEqStr,
            accumulatedStr
        );

        FileClose(fileHandle);

        Print("📊 Transaction logged: ", tradeType, " $", DoubleToString(profit, 2),
              " at ", currentLevelStr, " → Next: ", nextLevelStr);
    }
}

//+------------------------------------------------------------------+
//| File Operations                                                  |
//+------------------------------------------------------------------+
void EnsureRiskManagerDirectory() {
    // In MQL5, directories are automatically created when files are saved with subdirectory paths
    Print("ℹ️ Using RiskManager subdirectory for file organization");
}

string GetStateFileName() {
    string account = IntegerToString(AccountInfoInteger(ACCOUNT_LOGIN));
    string company = StringSubstr(AccountInfoString(ACCOUNT_COMPANY), 0, 10);
    StringReplace(company, " ", "_");
    return "RiskManager\\RiskManager_" + account + "_" + company + ".csv";
}

void SaveStateToFile(const RiskManagerState &state) {
    EnsureRiskManagerDirectory();

    string filename = GetStateFileName();
    string csvStr = StateToCsv(state);

    int fileHandle = FileOpen(filename, FILE_WRITE | FILE_TXT | FILE_ANSI);
    if(fileHandle != INVALID_HANDLE) {
        FileWriteString(fileHandle, csvStr);
        FileClose(fileHandle);
        Print("✓ Risk manager state saved to ", filename);
    } else {
        Print("❌ Failed to save risk manager state to ", filename);
    }
}

bool LoadStateFromFile(RiskManagerState &state) {
    string filename = GetStateFileName();

    // First try to load from new location (RiskManager subdirectory)
    int fileHandle = FileOpen(filename, FILE_READ | FILE_TXT | FILE_ANSI);
    if(fileHandle != INVALID_HANDLE) {
        string csvStr = FileReadString(fileHandle);
        FileClose(fileHandle);

        if(CsvToState(csvStr, state)) {
            Print("✓ Risk manager state loaded from ", filename);
            return true;
        }
    }

    // If not found in new location, check old location (root directory)
    string oldFilename = "RiskManager_" + IntegerToString(AccountInfoInteger(ACCOUNT_LOGIN)) + "_" + StringSubstr(AccountInfoString(ACCOUNT_COMPANY), 0, 10) + ".csv";
    StringReplace(oldFilename, " ", "_");

    fileHandle = FileOpen(oldFilename, FILE_READ | FILE_TXT | FILE_ANSI);
    if(fileHandle != INVALID_HANDLE) {
        string csvStr = FileReadString(fileHandle);
        FileClose(fileHandle);

        if(CsvToState(csvStr, state)) {
            Print("✓ Risk manager state loaded from old location: ", oldFilename);
            Print("📋 Migrating to new location: ", filename);

            // Save to new location immediately
            SaveStateToFile(state);

            return true;
        }
    }

    Print("ℹ No existing risk manager state found, will initialize new");
    return false;
}

//+------------------------------------------------------------------+
//| Recovery Logic Functions - Based on System Logic Manual         |
//+------------------------------------------------------------------+
void InitializeState(RiskManagerState &state) {
    // Three Risk Levels
    state.maxRiskPercent = inpMaxRiskPercent;
    state.midRiskPercent = inpMaxRiskPercent * 0.5;  // 50% of max
    state.minRiskPercent = inpMinRiskPercent;

    // Start at maximum risk level
    state.currentRiskPercent = inpMaxRiskPercent;

    // Recovery Journey Variables
    state.peakEquity = AccountInfoDouble(ACCOUNT_EQUITY);
    state.startingEquity = state.peakEquity;
    state.accumulatedProfit = 0.0;
    state.currentLevelTarget = state.peakEquity;  // No recovery needed at max
    state.maxLevelTarget = state.peakEquity;
    state.targetMidToMax = 0.0; // No recovery targets at MAX level

    // Trade Tracking
    state.consecutiveLosses = 0;
    state.journeyStartTime = TimeCurrent();
    state.lastProcessedTicket = 0;
    state.lastTradeType = "INIT";
    state.accountNumber = IntegerToString(AccountInfoInteger(ACCOUNT_LOGIN));
    state.lastUpdateTime = TimeCurrent();

    SaveStateToFile(state);

    Print("🆕 Risk Manager v1.38 Initialized:");
    Print("   MAX: ", DoubleToString(state.maxRiskPercent, 2), "%");
    Print("   MID: ", DoubleToString(state.midRiskPercent, 2), "%");
    Print("   MIN: ", DoubleToString(state.minRiskPercent, 2), "%");
    Print("   Starting at MAX level");

    // Log initialization to spreadsheet
    LogTransactionToSpreadsheet(state, 0.0, "INIT");
}

void ProcessNewTrades(RiskManagerState &state) {
    if(!inpAutoDetectTrades) return;

    // Get trade history
    HistorySelect(0, TimeCurrent());

    // Process new closed trades (reverse order to get newest first)
    for(int i = HistoryDealsTotal() - 1; i >= 0; i--) {
        ulong ticket = HistoryDealGetTicket(i);
        if(ticket == 0) continue;

        if(!HistoryDealSelect(ticket)) continue;

        // Skip if already processed
        if(ticket <= state.lastProcessedTicket) continue;

        // Check if it's a deal for current symbol and a closing deal
        string symbol = HistoryDealGetString(ticket, DEAL_SYMBOL);
        long entry = HistoryDealGetInteger(ticket, DEAL_ENTRY);

        if(symbol != _Symbol) continue;
        if(entry != DEAL_ENTRY_OUT) continue; // Skip non-closing deals

        double profit = HistoryDealGetDouble(ticket, DEAL_PROFIT);
        datetime closeTime = (datetime)HistoryDealGetInteger(ticket, DEAL_TIME);

        Print("📊 Processing closed trade #", ticket, " P/L: $", profit);

        // Process trade result
        ProcessTradeResult(state, profit, closeTime);
        state.lastProcessedTicket = ticket;
    }

    // Check for recovery progress
    CheckLevelProgress(state);
}

void ProcessTradeResult(RiskManagerState &state, double profit, datetime closeTime) {
    double currentEquity = AccountInfoDouble(ACCOUNT_EQUITY);
    string tradeType = profit < 0 ? "LOSS" : "PROFIT";

    // Update peak equity (new high watermark)
    if(currentEquity > state.peakEquity) {
        state.peakEquity = currentEquity;
        Print("🏈 New equity peak: $", state.peakEquity);
    }

    // COMPREHENSIVE RECOVERY DEBUG
    Print("🔍 === COMPREHENSIVE RECOVERY ANALYSIS ===");
    Print("🔍 Current Level: ", (state.currentRiskPercent == state.maxRiskPercent ? "MAX" :
                               state.currentRiskPercent == state.midRiskPercent ? "MID" : "MIN"),
          " (", DoubleToString(state.currentRiskPercent, 2), "%)");
    Print("🔍 This Transaction: ", tradeType, " $", DoubleToString(profit, 2));
    Print("🔍 Original Peak Equity: $", DoubleToString(state.peakEquity, 2));
    Print("🔍 Current Equity: $", DoubleToString(currentEquity, 2));
    Print("🔍 Total Drawdown: $", DoubleToString(state.peakEquity - currentEquity, 2));
    Print("🔍 Journey Started When: ", TimeToString(state.journeyStartTime));

    if(state.currentRiskPercent < state.maxRiskPercent) {
        Print("🔍 Recovery Journey:");
        Print("   Started from: $", DoubleToString(state.startingEquity, 2));
        Print("   Target for next level: $", DoubleToString(state.currentLevelTarget, 2));
        Print("   Progress so far: $", DoubleToString(state.accumulatedProfit, 2));
        Print("   Still needed: $", DoubleToString(state.currentLevelTarget - currentEquity, 2));

        if(profit > 0) {
            Print("✅ This WIN counts toward recovery!");
            Print("   Recovery progress: ", DoubleToString(state.accumulatedProfit / (state.maxLevelTarget - state.startingEquity) * 100, 1), "%");
        } else if(profit < 0) {
            Print("❌ This LOSS sets back recovery progress");
            Print("   New recovery needed: $", DoubleToString(state.maxLevelTarget - currentEquity, 2));
        }
    } else {
        Print("🔍 At MAX level - no recovery needed");
    }
    Print("🔍 =================================");

    if(profit < 0) {
        // Loss detected - reduce risk level
        HandleLoss(state, profit, closeTime);
    } else if(profit > 0 && state.currentRiskPercent < state.maxRiskPercent) {
        // Profit detected while below max level - accumulate toward recovery
        state.accumulatedProfit += profit;
        Print("💰 Profit accumulated: $", DoubleToString(state.accumulatedProfit, 2));
        CheckLevelProgress(state);
    }

    // Log transaction to spreadsheet
    LogTransactionToSpreadsheet(state, profit, tradeType);

    state.lastTradeType = tradeType;
    state.lastUpdateTime = TimeCurrent();
    g_stateModified = true;
}

void HandleLoss(RiskManagerState &state, double lossAmount, datetime closeTime) {
    state.consecutiveLosses++;
    double currentEquity = AccountInfoDouble(ACCOUNT_EQUITY);

    Print("📉 Loss #", state.consecutiveLosses, " detected: -$", MathAbs(lossAmount),
          " at ", DoubleToString(state.currentRiskPercent, 2), "% risk level");

    // Move down one risk level (simplified logic)
    double previousRisk = state.currentRiskPercent;

    if(state.currentRiskPercent == state.maxRiskPercent) {
        // MAX → MID
        state.currentRiskPercent = state.midRiskPercent;
        Print("⚠️ Level Down: MAX(", DoubleToString(state.maxRiskPercent, 2), "%) → MID(",
              DoubleToString(state.midRiskPercent, 2), "%)");

    } else if(state.currentRiskPercent == state.midRiskPercent) {
        // MID → MIN
        state.currentRiskPercent = state.minRiskPercent;
        Print("⚠️ Level Down: MID(", DoubleToString(state.midRiskPercent, 2), "%) → MIN(",
              DoubleToString(state.minRiskPercent, 2), "%)");

    } else if(state.currentRiskPercent == state.minRiskPercent) {
        // Already at MIN - stay at MIN
        Print("⚠️ Already at MIN level (", DoubleToString(state.minRiskPercent, 2), "%) - staying");
    }

    // Only update journey if we actually moved down
    if(state.currentRiskPercent < previousRisk) {
        // Start new recovery journey from this losing trade
        state.startingEquity = currentEquity;
        state.journeyStartTime = closeTime;
        state.accumulatedProfit = 0.0;  // Reset accumulated profit on loss
        g_stateModified = true;

        Print("🆕 Starting NEW recovery journey from loss at $", DoubleToString(currentEquity, 2));

        // Calculate FIXED recovery targets based on risk level targets
        double accountEquity = currentEquity;

        if(state.currentRiskPercent == state.midRiskPercent) {
            // At MID: Need fixed amount to reach MAX
            double targetToMax = (state.maxRiskPercent * accountEquity * 0.01) * inpRecoveryThreshold;
            state.currentLevelTarget = currentEquity + targetToMax;
            state.maxLevelTarget = state.currentLevelTarget; // Same target since we're going to MAX
            state.targetMidToMax = targetToMax; // Store fixed reference amount

            Print("   MID Level Recovery Target:");
            Print("   Target to MAX (", DoubleToString(state.maxRiskPercent, 1), "%): $", DoubleToString(targetToMax, 2));
            Print("   Starting from: $", DoubleToString(currentEquity, 2));
            Print("   Target Equity: $", DoubleToString(state.currentLevelTarget, 2));

        } else if(state.currentRiskPercent == state.minRiskPercent) {
            // At MIN: Need fixed amount to reach MID, then fixed amount from MID to MAX
            double targetToMid = (state.midRiskPercent * accountEquity * 0.01) * inpRecoveryThreshold;
            double targetToMax = (state.maxRiskPercent * accountEquity * 0.01) * inpRecoveryThreshold;
            state.currentLevelTarget = currentEquity + targetToMid; // Target for next level (MID)
            state.maxLevelTarget = currentEquity + targetToMid + targetToMax; // Total target to reach MAX
            state.targetMidToMax = targetToMax; // Store fixed reference amount from MID to MAX

            Print("   MIN Level Recovery Target:");
            Print("   Target to MID (", DoubleToString(state.midRiskPercent, 1), "%): $", DoubleToString(targetToMid, 2));
            Print("   Target to MAX (", DoubleToString(state.maxRiskPercent, 1), "%): $", DoubleToString(targetToMax, 2));
            Print("   Starting from: $", DoubleToString(currentEquity, 2));
            Print("   Target Equity for MID: $", DoubleToString(state.currentLevelTarget, 2));
            Print("   Total Target for MAX: $", DoubleToString(state.maxLevelTarget, 2));
        }

        Print("🎯 Updated Recovery Targets:");
        Print("   Journey Started: $", DoubleToString(state.startingEquity, 2));
        Print("   Current Equity: $", DoubleToString(currentEquity, 2));
        Print("   Next Level Target: $", DoubleToString(state.currentLevelTarget, 2));
        Print("   Max Level Target: $", DoubleToString(state.maxLevelTarget, 2));
        Print("   Recovery Needed: $", DoubleToString(state.currentLevelTarget - currentEquity, 2));
    }
}

void CheckLevelProgress(RiskManagerState &state) {
    double currentEquity = AccountInfoDouble(ACCOUNT_EQUITY);

    // Only check progress if we're below MAX level
    if(state.currentRiskPercent >= state.maxRiskPercent) {
        return;
    }

    double recoveryProfit = currentEquity - state.startingEquity;
    bool leveledUp = false;
    string levelUpReason = "";

    // Check for multi-level jumps from current position
    if(state.currentRiskPercent == state.minRiskPercent) {
        // At MIN (0.5%): Can jump to MID or directly to MAX

        if(currentEquity >= state.maxLevelTarget) {
            // Jump directly from MIN to MAX (multi-level jump)
            state.currentRiskPercent = state.maxRiskPercent;
            levelUpReason = "MIN → MAX (Multi-level jump)";
            leveledUp = true;

            Print("🚀 Multi-Level Jump: MIN(0.5%) → MAX(2.0%)! Surplus: $",
                  DoubleToString(currentEquity - state.maxLevelTarget, 2));

        } else if(currentEquity >= state.currentLevelTarget) {
            // Jump from MIN to MID
            state.currentRiskPercent = state.midRiskPercent;
            levelUpReason = "MIN → MID";
            leveledUp = true;

            // Update targets for reaching MAX from new MID position
            state.currentLevelTarget = state.maxLevelTarget; // Continue toward same MAX target
            // targetMidToMax remains the same (fixed reference amount)

            Print("📈 Level Up: MIN(0.5%) → MID(1.0%)!");
        }

    } else if(state.currentRiskPercent == state.midRiskPercent) {
        // At MID (1%): Can only jump to MAX

        if(currentEquity >= state.maxLevelTarget) {
            // Jump from MID to MAX
            state.currentRiskPercent = state.maxRiskPercent;
            levelUpReason = "MID → MAX";
            leveledUp = true;

            Print("📈 Level Up: MID(1.0%) → MAX(2.0%)!");
        }
    }

    // Handle level up actions
    if(leveledUp) {
        Print("🎯 Level Achievement: ", levelUpReason);
        Print("   Recovery Profit: $", DoubleToString(recoveryProfit, 2));
        Print("   Current Equity: $", DoubleToString(currentEquity, 2));

        // If we reached MAX, reset accumulated profit
        if(state.currentRiskPercent == state.maxRiskPercent) {
            state.accumulatedProfit = 0.0; // Reset at MAX
            state.consecutiveLosses = 0; // Reset loss streak
            state.currentLevelTarget = currentEquity;
            state.maxLevelTarget = currentEquity;

            Print("🏆 MAX Level Reached! Recovery complete.");
            Print("   Accumulated profit reset to $0");

        } else {
            // Continue accumulating toward MAX (no reset)
            Print("📊 Continuing toward MAX level");
            Print("   Still need: $", DoubleToString(state.maxLevelTarget - currentEquity, 2));
        }

        // Log level up to spreadsheet
        LogTransactionToSpreadsheet(state, recoveryProfit, "LEVEL_UP");
        g_stateModified = true;
    }
}

//+------------------------------------------------------------------+
//| Helper Functions                                                 |
//+------------------------------------------------------------------+
string GetCurrentLevelText() {
    if(g_state.currentRiskPercent == g_state.maxRiskPercent) {
        return "MAX";
    } else if(g_state.currentRiskPercent == g_state.midRiskPercent) {
        return "MID";
    } else if(g_state.currentRiskPercent == g_state.minRiskPercent) {
        return "MIN";
    } else {
        return "CUSTOM";
    }
}

//+------------------------------------------------------------------+
//| Display Functions                                                |
//+------------------------------------------------------------------+
void CreateDisplay() {
    // Simple positioning like Forex Risk Manager
    int panelX = inpLabelX;
    int panelY = inpLabelY;
    int panelWidth = 240;
    int textPadding = 10;
    int lineHeight = 15;

    // Dynamic height calculation based on content
    int panelHeight;
    if(inpShowCompactDisplay) {
        panelHeight = 100;  // Compact mode
    } else {
        if(g_state.currentRiskPercent < g_state.maxRiskPercent) {
            panelHeight = 190; // Recovery mode with additional info
        } else {
            panelHeight = 160; // Normal detailed mode
        }
    }

    // Create main panel (always use CORNER_LEFT_UPPER like Forex Risk Manager)
    if(ObjectCreate(0, g_labelName, OBJ_RECTANGLE_LABEL, 0, 0, 0)) {
        ObjectSetInteger(0, g_labelName, OBJPROP_XDISTANCE, panelX);
        ObjectSetInteger(0, g_labelName, OBJPROP_YDISTANCE, panelY);
        ObjectSetInteger(0, g_labelName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
        ObjectSetInteger(0, g_labelName, OBJPROP_XSIZE, panelWidth);
        ObjectSetInteger(0, g_labelName, OBJPROP_YSIZE, panelHeight);
        ObjectSetInteger(0, g_labelName, OBJPROP_BGCOLOR, inpLabelBackgroundColor);
        ObjectSetInteger(0, g_labelName, OBJPROP_BORDER_COLOR, clrGray);
        ObjectSetInteger(0, g_labelName, OBJPROP_BACK, true);
        ObjectSetInteger(0, g_labelName, OBJPROP_BORDER_TYPE, BORDER_FLAT);
    }

    // Create text labels - only the ones we actually use
    string lineNames[5] = {"_Title", "_DD", "_Risk", "_Targets", "_Detail1"};
    for(int i = 0; i < 5; i++) {
        string labelName = g_labelName + lineNames[i];
        if(ObjectCreate(0, labelName, OBJ_LABEL, 0, 0, 0)) {
            int textX = panelX + textPadding;
            int textY = panelY + textPadding + (i * lineHeight);

            ObjectSetInteger(0, labelName, OBJPROP_XDISTANCE, textX);
            ObjectSetInteger(0, labelName, OBJPROP_YDISTANCE, textY);
            ObjectSetInteger(0, labelName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
            ObjectSetString(0, labelName, OBJPROP_FONT, "Arial");
            ObjectSetInteger(0, labelName, OBJPROP_FONTSIZE, inpFontSize);
            ObjectSetInteger(0, labelName, OBJPROP_COLOR, inpLabelTextColor);
            ObjectSetInteger(0, labelName, OBJPROP_BACK, false);
        }
    }

    // Create reset button (positioned below panel)
    int buttonY = panelY + panelHeight + 5;
    if(ObjectCreate(0, g_buttonName, OBJ_BUTTON, 0, 0, 0)) {
        ObjectSetInteger(0, g_buttonName, OBJPROP_XDISTANCE, panelX);
        ObjectSetInteger(0, g_buttonName, OBJPROP_YDISTANCE, buttonY);
        ObjectSetInteger(0, g_buttonName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
        ObjectSetInteger(0, g_buttonName, OBJPROP_XSIZE, panelWidth);
        ObjectSetInteger(0, g_buttonName, OBJPROP_YSIZE, 25);
        ObjectSetString(0, g_buttonName, OBJPROP_TEXT, "🔄 RESET RISK");
        ObjectSetString(0, g_buttonName, OBJPROP_FONT, "Arial Bold");
        ObjectSetInteger(0, g_buttonName, OBJPROP_FONTSIZE, 9);
        ObjectSetInteger(0, g_buttonName, OBJPROP_BGCOLOR, clrTomato);
        ObjectSetInteger(0, g_buttonName, OBJPROP_COLOR, clrWhite);
        ObjectSetInteger(0, g_buttonName, OBJPROP_BORDER_COLOR, clrRed);
    }
}

void UpdateDisplay() {
    double currentEquity = AccountInfoDouble(ACCOUNT_EQUITY);
    double currentDD = g_state.peakEquity - currentEquity;
    double ddPercent = (g_state.peakEquity > 0) ? (currentDD / g_state.peakEquity) * 100 : 0;

    string currentLevel = GetCurrentLevelText();
    string riskArrow = (g_state.currentRiskPercent < g_state.maxRiskPercent) ? "⬆️" : "✅";

    // Calculate remaining amounts for display
    double remainingToNext = 0.0;
    double remainingToMax = 0.0;
    double progressPercent = 0.0;

    if(g_state.currentRiskPercent < g_state.maxRiskPercent && g_state.currentLevelTarget > 0) {
        remainingToNext = MathMax(0.0, g_state.currentLevelTarget - currentEquity);
        remainingToMax = MathMax(0.0, g_state.maxLevelTarget - currentEquity);

        double totalNeeded = g_state.maxLevelTarget - g_state.startingEquity;
        if(totalNeeded > 0) {
            progressPercent = (g_state.accumulatedProfit / totalNeeded) * 100;
        }
    }

    if(inpShowCompactDisplay) {
        // Compact format - show essential information
        ObjectSetString(0, g_labelName + "_Title", OBJPROP_TEXT, "🛡️ " + currentLevel + " " + riskArrow);
        ObjectSetString(0, g_labelName + "_DD", OBJPROP_TEXT, "DD: -$" + DoubleToString(MathAbs(currentDD), 2) + " (" + DoubleToString(ddPercent, 1) + "%)");
        ObjectSetString(0, g_labelName + "_Risk", OBJPROP_TEXT, "Risk: " + DoubleToString(g_state.currentRiskPercent, 1) + "%" + riskArrow);
        ObjectSetString(0, g_labelName + "_Losses", OBJPROP_TEXT, "Peak: $" + DoubleToString(g_state.peakEquity, 2));

        // Show recovery targets if in recovery
        if(g_state.currentRiskPercent < g_state.maxRiskPercent && remainingToNext > 0) {
            double remainingToMid = 0.0;
            double remainingToMaxValue = 0.0;
            double totalToMax = 0.0;

            if(g_state.currentRiskPercent == g_state.minRiskPercent) {
                // At MIN: Need to reach MID, then MAX
                remainingToMid = MathMax(0.0, g_state.currentLevelTarget - currentEquity);
                remainingToMaxValue = g_state.targetMidToMax; // Use stored fixed amount from MID to MAX
                totalToMax = MathMax(0.0, g_state.maxLevelTarget - currentEquity);

                ObjectSetString(0, g_labelName + "_Progress", OBJPROP_TEXT,
                    "To " + DoubleToString(g_state.midRiskPercent, 1) + "%: $" + DoubleToString(remainingToMid, 2));
            } else if(g_state.currentRiskPercent == g_state.midRiskPercent) {
                // At MID: Only need to reach MAX
                remainingToMid = 0.0;
                remainingToMaxValue = MathMax(0.0, g_state.maxLevelTarget - currentEquity);
                totalToMax = remainingToMaxValue;

                ObjectSetString(0, g_labelName + "_Progress", OBJPROP_TEXT,
                    "To MAX: $" + DoubleToString(remainingToMaxValue, 2));
            }
        }

        // Hide unused labels
        // No additional labels needed in compact mode
    } else {
        // Detailed format - show all information
        ObjectSetString(0, g_labelName + "_Title", OBJPROP_TEXT, "🛡️ RISK MANAGER");
        ObjectSetString(0, g_labelName + "_DD", OBJPROP_TEXT, "Level: " + currentLevel + " (" + DoubleToString(g_state.currentRiskPercent, 1) + "%)");
        ObjectSetString(0, g_labelName + "_Risk", OBJPROP_TEXT, "Drawdown: $" + DoubleToString(MathAbs(currentDD), 2) + " (" + DoubleToString(ddPercent, 1) + "%)");

        if(g_state.currentRiskPercent < g_state.maxRiskPercent && remainingToNext > 0) {
            // Calculate remaining amounts using stage-based logic
            double remainingToMid = 0.0;
            double remainingToMaxFromMid = 0.0;
            double totalToMax = 0.0;

            if(g_state.currentRiskPercent == g_state.minRiskPercent) {
                // At MIN: Need to reach MID, then MAX
                remainingToMid = MathMax(0.0, g_state.currentLevelTarget - currentEquity);
                remainingToMaxFromMid = g_state.targetMidToMax; // Use stored fixed amount from MID to MAX
                totalToMax = MathMax(0.0, g_state.maxLevelTarget - currentEquity);

                ObjectSetString(0, g_labelName + "_Targets", OBJPROP_TEXT, "To MID: $" + DoubleToString(remainingToMid, 2) + " remaining");
                ObjectSetString(0, g_labelName + "_Detail1", OBJPROP_TEXT, "To MAX (" + DoubleToString(g_state.maxRiskPercent, 1) + "%): $" + DoubleToString(remainingToMaxFromMid, 2) + " remaining");

            } else if(g_state.currentRiskPercent == g_state.midRiskPercent) {
                // At MID: Only need to reach MAX
                remainingToMid = 0.0; // Already at MID level
                remainingToMaxFromMid = MathMax(0.0, g_state.maxLevelTarget - currentEquity);
                totalToMax = remainingToMaxFromMid;

                ObjectSetString(0, g_labelName + "_Targets", OBJPROP_TEXT, "To MID: -");
                ObjectSetString(0, g_labelName + "_Detail1", OBJPROP_TEXT, "To MAX (" + DoubleToString(g_state.maxRiskPercent, 1) + "%): $" + DoubleToString(remainingToMaxFromMid, 2) + " remaining");
            }
        } else {
            ObjectSetString(0, g_labelName + "_Targets", OBJPROP_TEXT, "To MID: -");
            ObjectSetString(0, g_labelName + "_Detail1", OBJPROP_TEXT, "To MAX (" + DoubleToString(g_state.maxRiskPercent, 1) + "%): Trading at MAX risk");
        }
    }
}

void DeleteDisplay() {
    ObjectDelete(0, g_labelName);
    ObjectDelete(0, g_buttonName);

    // Delete only the text labels we actually use
    string lineNames[5] = {"_Title", "_DD", "_Risk", "_Targets", "_Detail1"};
    for(int i = 0; i < 5; i++) {
        ObjectDelete(0, g_labelName + lineNames[i]);
    }
}

//+------------------------------------------------------------------+
//| Manual Reset                                                     |
//+------------------------------------------------------------------+
void ManualReset() {
    Print("🔄 Manual reset requested");

    // Get current highest ticket number to prevent reprocessing old trades
    ulong highestTicket = 0;
    HistorySelect(0, TimeCurrent());
    for(int i = HistoryDealsTotal() - 1; i >= 0; i--) {
        ulong ticket = HistoryDealGetTicket(i);
        if(ticket > highestTicket) {
            highestTicket = ticket;
        }
    }

    InitializeState(g_state);
    // Set last processed ticket to current highest to skip all existing trades
    g_state.lastProcessedTicket = highestTicket;
    Print("🔄 Reset complete. Skipping trades up to ticket #", highestTicket);
    UpdateDisplay();
}

//+------------------------------------------------------------------+
//| Indicator Event Handlers                                         |
//+------------------------------------------------------------------+
int OnInit() {
    // Check if indicator should run on this chart
    g_shouldRun = ShouldRunOnChart();

    if(!g_shouldRun) {
        Print("🚫 Risk Manager Indicator disabled on ", _Symbol, " (chart control settings)");
        return(INIT_FAILED);
    }

    Print("🚀 Risk Manager Indicator v1.38 (Fixed Stage-Based Logic) starting on ", _Symbol);

    // Try to load existing state
    if(!LoadStateFromFile(g_state)) {
        // No existing state, initialize new one
        InitializeState(g_state);
    } else {
        // Validate loaded state
        if(g_state.accountNumber != IntegerToString(AccountInfoInteger(ACCOUNT_LOGIN))) {
            Print("⚠️ State mismatch - reinitializing for new account");
            InitializeState(g_state);
        } else {
            Print("✓ Existing state loaded successfully");
        }
    }

    // Create display elements
    CreateDisplay();
    UpdateDisplay();

    g_initialized = true;
    Print("✅ Risk Manager Indicator initialized");

    return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason) {
    Print("🛑 Risk Manager Indicator stopping...");

    // Save current state
    if(g_initialized) {
        if(g_stateModified) {
            SaveStateToFile(g_state);
        }
        DeleteDisplay();
    }

    Print("👋 Risk Manager Indicator stopped");
}

int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &real_volume[],
                const int &spread[]) {

    // Only process if this indicator instance should be running
    if(!g_shouldRun || !g_initialized) {
        return(rates_total);
    }

    // Process new trades and update display
    ProcessNewTrades(g_state);
    UpdateDisplay();

    // Save state only if it was modified
    if(g_stateModified) {
        SaveStateToFile(g_state);
        g_stateModified = false;
    }

    return(rates_total);
}

void OnChartEvent(const int id,
                  const long &lparam,
                  const double &dparam,
                  const string &sparam) {

    // Only process events if this indicator instance should be running
    if(!g_shouldRun || !g_initialized) {
        return;
    }

    // Handle reset button click
    if(id == CHARTEVENT_OBJECT_CLICK && sparam == g_buttonName) {
        ManualReset();
        ObjectSetInteger(0, g_buttonName, OBJPROP_STATE, false);
        ChartRedraw();
    }

    // Handle chart property change (timeframe change, etc.)
    if(id == CHARTEVENT_CHART_CHANGE) {
        UpdateDisplay();
    }
}
