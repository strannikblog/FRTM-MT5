//+------------------------------------------------------------------+
//|                                           ForexRiskManager.mq5    |
//|                                  Risk Management & Lot Calculator |
//|                                                                    |
//+------------------------------------------------------------------+
#property copyright "Forex Risk Manager"
#property link      ""
#property version   "2.04"
#property description "Risk Management EA with Complete Draggable UI | All Labels v1.18.7"
#property description "Ideal & Conservative Modes | One-Click Execution | Position Persistence | State Management Fixed"

//--- Include libraries
#include <Trade\Trade.mqh>
CTrade trade;

//--- Include CAppDialog Framework for Draggable UI
#include <Controls\Dialog.mqh>
#include <Controls\Button.mqh>
#include <Controls\Label.mqh>
#include <Controls\Defines.mqh>

//+------------------------------------------------------------------+
//| Enumerations - MUST BE BEFORE INPUTS                            |
//+------------------------------------------------------------------+
enum ENUM_PIP_MODE
{
   PIP_AUTO,           // Auto Calculate
   PIP_MANUAL          // Manual Entry
};

enum ENUM_SL_MODE
{
   SL_MANUAL,          // Manual (Fixed Pips)
   SL_DYNAMIC,         // Dynamic (to Price Level)
   SL_HYBRID           // Hybrid (Reference + Dynamic)
};

enum ENUM_DISPLAY_MODE
{
   DISPLAY_IDEAL,           // Ideal (No Entry Slippage)
   DISPLAY_CONSERVATIVE     // Conservative (With Entry Slippage)
};

enum ENUM_TRADE_DIR
{
   TRADE_AUTO,   // Auto-Detect (from TP position)
   TRADE_BUY,    // Buy (Long)
   TRADE_SELL    // Sell (Short)
};enum ENUM_LABEL_POSITION
{
   LABEL_RIGHT,      // Right of line
   LABEL_ABOVE,      // Above line
   LABEL_BELOW       // Below line
};

enum ENUM_EXECUTION_MODE
{
   EXECUTE_BIDASK,   // Bid/Ask (Realistic - Accounts for Spread)
   EXECUTE_VISUAL    // Visual (Uses close[0] - Matches Price Line)
};

enum ENUM_EXIT_SLIPPAGE_MODE
{
   EXIT_SLIPPAGE_MANUAL,         // Manual (Fixed Value)
   EXIT_SLIPPAGE_SPREAD_BASED    // Spread-Based (Dynamic)
};

enum ENUM_ACCOUNT_MODE
{
   ACCOUNT_MODE_AUTO,      // Auto-Detect
   ACCOUNT_MODE_NETTING,   // Netting (Retail)
   ACCOUNT_MODE_HEDGING    // Hedging (Individual Positions)
};

//+------------------------------------------------------------------+
//| Input Parameters                                                  |
//+------------------------------------------------------------------+

//--- Trade Management Mode
input group "===== Trade Management ====="
input bool inpPlaceSLOrder = true;                          // Place SL Limit Order
input bool inpPlaceTPOrder = true;                          // Place TP Limit Orders
input ENUM_EXECUTION_MODE inpExecutionMode = EXECUTE_BIDASK; // Auto-Execution Mode (All Features)

//--- Execute on Candle Close
input group "===== Execute on Candle Close ====="
input bool inpExecuteOnCandleClose = false;                 // Enable Execute on Candle Close (Button Triggered)
input bool inpCandleCloseAlert = true;                      // Alert When Candle Closes
input bool inpShowCandleTimer = true;                       // Show Candle Close Timer

//--- Conditional Order Execution
input group "===== Conditional Order Execution ====="
input bool inpCheckSpreadCondition = false;                 // Enable Spread Condition Check
input double inpMaxSpreadPips = 2.0;                        // Maximum Acceptable Spread (pips)
input bool inpCheckMarginCondition = false;                 // Enable Margin Usage Check
input double inpMaxMarginUsagePercent = 50.0;               // Maximum Margin Usage %
input bool inpCheckExecutionCost = false;                   // Enable Execution Cost Check
input double inpMaxExecutionCostPercent = 10.0;             // Maximum Execution Cost %

//--- Take Profit Settings
input group "===== Take Profit Settings ====="
input bool inpShowTP = true;                                // Show Take Profit Lines
input int inpNumberOfLevels = 3;                            // Number of Exit Levels (1, 2, or 3)
input double inpExitPercent1 = 50.0;                        // Exit % at Level 1
input double inpExitPercent2 = 30.0;                        // Exit % at Level 2
input bool inpShowRR = true;                                // Show RR (Risk:Reward) on TP Levels

//--- Supertrend Settings (Last Level Management)
input group "===== Supertrend - Last Level Management ====="
input bool inpUseSupertrendOnLastLevel = false;            // Use Supertrend on Last Level
input int inpSupertrendATRPeriod = 14;                     // Supertrend ATR Period
input double inpSupertrendATRMultiplier = 2.0;             // Supertrend ATR Multiplier
input int inpSupertrendBarsToCalculate = 100;              // Bars to Calculate for Line
input bool inpSupertrendTrailingStop = true;               // Trailing Stop (true) or Auto-Close (false)
input bool inpShowSupertrendLine = true;                   // Show Supertrend Line
input color inpSupertrendUptrendColor = clrLime;           // Supertrend Uptrend Color
input color inpSupertrendDowntrendColor = clrRed;          // Supertrend Downtrend Color
input int inpSupertrendLineWidth = 2;                      // Supertrend Line Width
input bool inpSupertrendEnableNotifications = false;       // Enable Supertrend Reversal Notifications
input bool inpSupertrendSendAlert = true;                  // Supertrend Send Alert
input bool inpSupertrendSendPush = false;                  // Supertrend Send Push
input bool inpSupertrendSendEmail = false;                 // Supertrend Send Email

//--- Stop Loss Settings
input group "===== Stop Loss Settings ====="
input ENUM_SL_MODE inpSLMode = SL_MANUAL;                    // Stop Loss Mode
input double inpManualSLPips = 15.0;                         // Manual Stop Loss (pips)
input ENUM_TRADE_DIR inpTradeDirection = TRADE_AUTO;         // Trade Direction (Manual SL Mode)

//--- Active SL Management (Percentage-Based)
input group "===== Active SL Management (Percentage-Based) ====="
input bool inpUsePercentageSLManagement = false;                // Enable Percentage-Based SL Management
input double inpSLTrimLevel1_PriceMove = 50.0;                  // Level 1: Price Moves (% of target, 0=disable)
input double inpSLTrimLevel1_TrimAmount = 25.0;                 // Level 1: Trim SL by (%)
input double inpSLTrimLevel2_PriceMove = 60.0;                  // Level 2: Price Moves (% of target, 0=disable)
input double inpSLTrimLevel2_TrimAmount = 50.0;                 // Level 2: Trim SL by (%)
input double inpSLTrimLevel3_PriceMove = 75.0;                  // Level 3: Price Moves (% of target, 0=disable)
input double inpSLTrimLevel3_TrimAmount = 100.0;                // Level 3: Trim SL by (% - 100=BE)
input bool inpTrailSLToNextTP = false;                          // Trail SL to Previous TP Levels (post-TP profit locking)
input double inpBEOffsetPips = 0.0;                             // BE Offset (pips above/below entry)

//--- Pending Order Line (Touch to Execute)
input group "===== Pending Order Line (Touch to Execute) ====="
input bool inpUsePendingOrderLine = false;                  // Enable Pending Order Line
input double inpPendingOrderTolerance = 0.5;                // Execution Tolerance (pips)
input bool inpPendingOrderEnableAlert = true;               // Enable Alert Notification
input bool inpPendingOrderEnableSound = true;               // Enable Sound Notification
input bool inpPendingOrderEnablePush = true;                // Enable Push Notification
input bool inpPendingOrderEnableEmail = false;              // Enable Email Notification
input string inpPendingOrderSoundFile = "alert.wav";        // Sound File Name

//--- Stop Loss - Auto Execution
input group "===== Stop Loss - Auto Execution ====="
input bool inpAutoExecuteSL = false;                         // Auto Execute at Stop Loss
input bool inpSLExecuteEnableAlert = true;                   // Enable Alert Notification
input bool inpSLExecuteEnableSound = true;                   // Enable Sound Notification
input bool inpSLExecuteEnablePush = true;                    // Enable Push Notification
input bool inpSLExecuteEnableEmail = false;                  // Enable Email Notification
input string inpSLExecuteSoundFile = "alert.wav";            // Sound File Name

//--- Take Profit - Auto Execution
input group "===== Take Profit - Auto Execution ====="
input bool inpAutoExecuteTP = false;                        // Auto Execute at TP (All Levels)
input bool inpTPExecuteEnableAlert = true;                  // Enable Alert Notification
input bool inpTPExecuteEnableSound = true;                  // Enable Sound Notification
input bool inpTPExecuteEnablePush = true;                   // Enable Push Notification
input bool inpTPExecuteEnableEmail = false;                 // Enable Email Notification
input string inpTPExecuteSoundFile = "alert.wav";           // Sound File Name

//--- Account & Risk Settings
input group "===== Dynamic Risk Settings ====="
input bool inpUseDynamicRisk = false;                        // Use RiskManager for risk%
input bool inpUseDynamicAccountSize = false;                 // Use MT5 real-time equity
input int inpRiskFileCacheSeconds = 300;                     // Risk File Cache Duration (seconds, 0=no cache)

input group "===== Manual Risk Settings ====="
input double inpManualRiskPercent = 0.25;                    // Manual fallback risk%
input double inpManualAccountSize = 100000;                  // Manual fallback account size
input double inpMarginPercent = 3.0;                        // Margin Requirement %
input double inpCommissionPerLot = 5.0;                     // Commission per Lot (Round-turn USD)
input ENUM_ACCOUNT_MODE inpAccountMode = ACCOUNT_MODE_AUTO;     // Account Mode (Partial Close Method)
input ENUM_PIP_MODE inpPipValueMode = PIP_AUTO;            // Pip Value Mode
input double inpManualPipValue = 10.0;                      // Manual Pip Value (USD per lot)
input bool inpShowPipValue = true;                          // Show Pip Value in Panel

//--- Entry & Exit Slippage Settings
input group "===== Entry & Exit Slippage ====="
input double inpEntrySlippage = 0.2;                        // Expected Entry Slippage (pips)
input ENUM_EXIT_SLIPPAGE_MODE inpExitSlippageMode = EXIT_SLIPPAGE_MANUAL; // Exit Slippage Mode
input double inpExitSlippage = 0.1;                         // Exit Slippage (pips)
input ENUM_DISPLAY_MODE inpDisplayMode = DISPLAY_CONSERVATIVE; // Display Mode
input bool inpShowAlternateLotSize = false;                 // Show Alternate Lot Size

//--- Display Settings
input group "===== Display Settings ====="
input bool inpShowPanel = true;                             // Show Information Panel
input bool inpShowLines = true;                             // Show Reference Lines
input bool inpShowEntryLine = true;                         // Show Entry Line
input bool inpShowReturnOnMargin = false;                   // Show Return on Margin

input group "===== Panel Position & Size ====="
input int inpPanelX = 20;                                   // Panel X Position
input int inpPanelY = 80;                                   // Panel Y Position
input int inpPanelWidth = 260;                              // Panel Width (pixels)
input int inpPanelHeight = 490;                             // Panel Height (0 = Auto)
input int inpPanelPadding = 10;                             // Panel Internal Padding (pixels)
input int inpRowHeight = 18;                                // Row Height (pixels)
input int inpDividerLength = 26;                            // Divider Length (number of dashes)
input int inpFontSizeBold = 9;                              // Font Size (Bold Labels)
input int inpFontSizeNormal = 8;                            // Font Size (Normal Text)

input group "===== Panel Colors ====="
input color inpPanelBgColor = clrWhite;                     // Planning Panel Background Color
input color inpManagementPanelBgColor = C'230,255,230';     // Management Panel Background Color (Light Green)
input color inpPanelTextColor = C'100,100,100';             // Panel Text Color
input color inpSLLineColor = clrCrimson;                    // Stop Loss Line Color
input color inpTPLineColor = clrSeaGreen;                   // Take Profit Line Color
input color inpEntryLineColor = clrDeepPink;                // Entry Line Color
input color inpBELineColor = clrOrange;                     // Break-even Line Color
input color inpActiveSLLineColor = clrPurple;               // Active SL Line Color
input color inpPendingOrderLineColor = clrDodgerBlue;       // Pending Order Line Color
input ENUM_LABEL_POSITION inpLabelPosition = LABEL_ABOVE;   // Label Position (Dynamic Mode)

//--- Button Settings
input group "===== Button Settings ====="
input int inpButtonWidth = 125;                             // Button Width
input int inpButtonHeight = 30;                             // Button Height
input int inpButtonSpacing = 10;                            // Button Spacing Below Panel (pixels)
input color inpBuyButtonColor = clrSteelBlue;               // Buy Button Color
input color inpSellButtonColor = clrSeaGreen;               // Sell Button Color
input color inpMoveToBEButtonColor = clrDarkOrange;         // Breakeven Button Color
input color inpCloseAllButtonColor = clrBrown;              // Close All Button Color

//--- File Export
input group "===== File Export ====="
input string inpExportDirectory = "EA";                      // Export Directory (in Common\\Files\\)

//+------------------------------------------------------------------+
//| Global Variables                                                  |
//+------------------------------------------------------------------+
string g_PanelName = "RiskPanel";
string g_BuyButtonName = "BuyButton";
string g_SellButtonName = "SellButton";
string g_MoveToBEButtonName = "MoveToBEButton";
string g_CloseAllButtonName = "CloseAllButton";
string g_SLLineName = "SLLine";
string g_SLRefLineName = "SLRefLine";           // Reference SL line for Hybrid mode
string g_TPLineName = "TPLine";
string g_EntryLineName = "EntryLine";
string g_BELineName = "BELine";
string g_PartialTP1LineName = "PartialTP1Line";
string g_PartialTP2LineName = "PartialTP2Line";
string g_PartialTP3LineName = "PartialTP3Line";
string g_SLLabelName = "SLLine_Label";          // Text label for draggable SL
string g_TPLabelName = "TPLine_Label";          // Text label for TP
string g_PartialTP1LabelName = "PartialTP1Line_Label";  // Text label for Partial TP1
string g_PartialTP2LabelName = "PartialTP2Line_Label";  // Text label for Partial TP2
string g_PartialTP3LabelName = "PartialTP3Line_Label";  // Text label for Partial TP3
string g_ActiveSLLineName = "ActiveSLLine";              // Active SL line (created when order is placed)
string g_ActiveSLLabelName = "ActiveSLLine_Label";      // Text label for Active SL line
string g_PendingOrderLineName = "PendingOrderLine";     // Pending order line (acts like broker limit order)
string g_PendingOrderLabelName = "PendingOrderLine_Label";  // Text label for Pending Order line

double g_PointValue;
double g_PipValue;
int g_Digits;
double g_Point;

// Runtime prices for draggable lines (updated when lines are dragged, synced via settings file)
double g_DynamicSLPrice = 0;         // Dynamic SL Line Price
double g_ReferenceSLPrice = 0;       // Reference SL Line Price (Hybrid mode)
double g_DynamicTPPrice = 0;         // Dynamic TP Line Price
double g_PartialTP1Price = 0;        // Partial TP1 Line Price
double g_PartialTP2Price = 0;        // Partial TP2 Line Price
double g_PartialTP3Price = 0;        // Partial TP3 Line Price

// Active SL tracking (for active trade management)
double g_ActiveSLPrice = 0;          // Current Active SL line price
double g_OriginalSLPrice = 0;        // Original SL price when position was opened (for 1/2 SL calculation)
ulong g_ActivePositionTicket = 0;    // Ticket of active position being managed
bool g_ActiveTradeDirection = true;  // Locked trade direction (true = BUY, false = SELL)

// Percentage-based SL trim tracking
bool g_SLTrimLevel1_Executed = false;  // Track if Level 1 trim has been executed
bool g_SLTrimLevel2_Executed = false;  // Track if Level 2 trim has been executed
bool g_SLTrimLevel3_Executed = false;  // Track if Level 3 trim has been executed

// Candle close execution tracking
datetime g_LastCandleTime = 0;              // Track last processed candle open time
bool g_CandleCloseOrderQueued = false;      // Order queued for next candle close
bool g_QueuedOrderIsBuy = true;             // Direction: true = BUY, false = SELL

// Pending order line tracking (acts like broker limit order)
double g_PendingOrderPrice = 0;             // Pending order line price
bool g_PendingOrderActive = false;          // Is pending order armed and waiting

// Runtime TP settings (synced via settings file)
double g_ExitPercent1 = 0;           // Exit % at Level 1 - 0 means use input parameter
double g_ExitPercent2 = 0;           // Exit % at Level 2 - 0 means use input parameter
double g_PartialLots1 = 0;           // Absolute lot size for TP1 - 0 means recalculate
double g_PartialLots2 = 0;           // Absolute lot size for TP2 - 0 means recalculate
double g_PartialLots3 = 0;           // Absolute lot size for TP3 - 0 means recalculate
double g_OriginalTotalLots = 0;      // Original total lot size at position open (for multi-instance coordination)

// Settings file sync tracking
datetime g_LastFileModifyTime = 0;  // Track last file modification time for auto-reload
bool g_IsReloadingFromFile = false;  // Prevent circular saves during file reload

// Position tracking for email alerts
ulong g_LastClosedDeal = 0;  // Track last processed deal to avoid duplicate alerts

// Position tracking for auto execution
ulong g_ExecutedSLPositions[];  // Array of position tickets that have executed Stop Loss
ulong g_ExecutedStandardTPPositions[];  // Array of position tickets that have executed Standard TP
ulong g_ExecutedTP1Positions[];  // Array of position tickets that have executed TP1
ulong g_ExecutedTP2Positions[];  // Array of position tickets that have executed TP2
ulong g_ExecutedTP3Positions[];  // Array of position tickets that have executed TP3

// TP price change tracking (prevent false executions when TP moves to price vs price reaching TP)
double g_LastTP1Price = 0;  // Last checked TP1 price
double g_LastTP2Price = 0;  // Last checked TP2 price
double g_LastTP3Price = 0;  // Last checked TP3 price
double g_LastActiveSLPriceCheck = 0;  // Last checked Active SL price

// Supertrend variables (for last level management)
int g_SupertrendATRHandle = INVALID_HANDLE;  // ATR indicator handle for Supertrend
double g_SupertrendUp[];                     // Supertrend upper band buffer
double g_SupertrendDn[];                     // Supertrend lower band buffer
double g_SupertrendTrend[];                  // Supertrend trend direction buffer
double g_SupertrendValue[];                  // Supertrend value buffer (actual line value)
int g_SupertrendLastTrend = 0;              // Last trend direction (for reversal detection)
datetime g_SupertrendLastBarTime = 0;        // Last bar time (for new candle detection)
string g_SupertrendLinePrefix = "STLine_";   // Prefix for Supertrend line objects
ulong g_SupertrendManagedPositions[];        // Array of positions being managed by Supertrend

// Calculation results
struct RiskCalculation
{
   double lotSize;
   double priceRisk;
   double spreadCost;      // Spread cost (spread-based mode only)
   double commission;
   double totalRisk;
   double riskPercent;
   double slPips;
   double baseSLPips;      // Original SL distance (without entry slippage)
   double tpPips;
   double slPrice;
   double tpPrice;
   double entryPrice;
   double breakEvenPips;
   double grossTP;
   double netTP;
   double marginRequired;
   double buyingPowerPercent;
   double returnOnMargin;
   double executionCostPercent;  // Total fees as % of gross profit
   double currentPnL;            // Real-time P/L (Management Mode only)

   // Pip distance metrics
   double dollarPerPip;         // $ per pip for this trade (based on lot size)
   double tpPipDistance;        // Standard TP profit in pip distance

   // Partial exits
   double partialLots1;
   double partialLots2;
   double partialLots3;
   double partialPips1;
   double partialPips2;
   double partialPips3;
   double partialTP1Price;
   double partialTP2Price;
   double partialTP3Price;
   double partialGrossPnL1;
   double partialGrossPnL2;
   double partialGrossPnL3;
   double partialNetPnL1;
   double partialNetPnL2;
   double partialNetPnL3;
   double partialTotalNetPnL;
   double partialPipDistance1;  // TP1 profit in pip distance
   double partialPipDistance2;  // TP2 profit in pip distance
   double partialPipDistance3;  // TP3 profit in pip distance
   double partialTotalPipDistance; // Total profit in pip distance
};

RiskCalculation g_IdealCalc;
RiskCalculation g_ConservativeCalc;

//+------------------------------------------------------------------+
//| Dynamic Risk Management Globals                                   |
//+------------------------------------------------------------------+
struct DynamicRiskData {
    double currentRiskPercent;    // Risk% from RiskManager
    datetime lastUpdate;          // File timestamp
    bool fileReadSuccess;         // Read operation status
    datetime lastReadTime;        // Last successful read
};

DynamicRiskData g_DynamicRisk;
string g_RiskFileName = "RiskManager\\RiskManager_CurrentRisk.csv";
datetime g_LastRiskFileCheck = 0;

//+------------------------------------------------------------------+
//| Forex Trade Manager Draggable Dialog Class                        |
//+------------------------------------------------------------------+
class CForexTradeManagerDialog : public CAppDialog
{
private:
    // Display labels for Phase 1 (15-18 core labels)
    CLabel m_label_lotSize;
    CLabel m_label_lotSizeValue;
    CLabel m_label_riskSource;
    CLabel m_label_riskSourceValue;
    CLabel m_label_accountSource;
    CLabel m_label_accountSourceValue;
    CLabel m_label_divider1;
    CLabel m_label_sl;
    CLabel m_label_slValue;
    CLabel m_label_totalRiskPips;
    CLabel m_label_totalRiskPipsValue;
    CLabel m_label_breakeven;
    CLabel m_label_breakevenValue;
    CLabel m_label_divider2;
    CLabel m_label_totalRisk;
    CLabel m_label_totalRiskValue;
    CLabel m_label_riskPercent;
    CLabel m_label_riskPercentValue;

    // Phase 2: Additional Label Members (~35 labels)

    // Alternate Lot Size (Conditional - inpShowAlternateLotSize)
    CLabel m_label_altLotSize;
    CLabel m_label_altLotSizeValue;

    // Pip Value (Conditional - inpShowPipValue)
    CLabel m_label_pipValue;
    CLabel m_label_pipValueValue;

    // Partial Exits Summary (Conditional - inpShowTP)
    CLabel m_label_tp;
    CLabel m_label_tpValue;

    // Partial Exits Detailed Breakdown (Conditional - inpShowTP)
    CLabel m_label_partialTitle;
    // Level 1 (always shown when TP is enabled)
    CLabel m_label_level1Label;
    CLabel m_label_level1Pips;
    CLabel m_label_level1Net;
    // Level 2 (Conditional - inpNumberOfLevels >= 2)
    CLabel m_label_level2Label;
    CLabel m_label_level2Pips;
    CLabel m_label_level2Net;
    // Level 3 (Conditional - inpNumberOfLevels == 3)
    CLabel m_label_level3Label;
    CLabel m_label_level3Pips;
    CLabel m_label_level3Net;
    // Partial Total
    CLabel m_label_partialTotalLabel;
    CLabel m_label_partialTotalValue;

    // Additional Risk Details
    CLabel m_label_priceRisk;
    CLabel m_label_priceRiskValue;
    CLabel m_label_commission;
    CLabel m_label_commissionValue;
    // Spread Cost (Conditional - inpShowSpreadCost)
    CLabel m_label_spreadCost;
    CLabel m_label_spreadCostValue;

    // Margin Information
    CLabel m_label_divider3;
    CLabel m_label_margin;
    CLabel m_label_marginValue;
    CLabel m_label_buyingPower;
    CLabel m_label_buyingPowerValue;
    // Return on Margin (Conditional - inpShowROM)
    CLabel m_label_rom;
    CLabel m_label_romValue;

    // Trading buttons (4 buttons)
    CButton m_btn_buy;
    CButton m_btn_sell;
    CButton m_btn_breakeven;
    CButton m_btn_closeAll;

    // Button request flags for communication with main EA
    bool m_buyRequested;
    bool m_sellRequested;
    bool m_breakevenRequested;
    bool m_closeAllRequested;

public:
    // Constructor
    CForexTradeManagerDialog() : m_buyRequested(false), m_sellRequested(false),
                                  m_breakevenRequested(false), m_closeAllRequested(false),
                                  m_isDialogVisible(false) {}

    // Create dialog and all controls
    virtual bool Create(const long chart, const string name, const int subwin, const int x1, const int y1, const int x2, const int y2);

    // Update display with current calculation data
    void UpdateDisplay(RiskCalculation &calc, bool isManagementMode);

    // Button request accessors
    bool IsBuyRequested() { return m_buyRequested; }
    void ClearBuyRequest() { m_buyRequested = false; }
    bool IsSellRequested() { return m_sellRequested; }
    void ClearSellRequest() { m_sellRequested = false; }
    bool IsBreakevenRequested() { return m_breakevenRequested; }
    void ClearBreakevenRequest() { m_breakevenRequested = false; }
    bool IsCloseAllRequested() { return m_closeAllRequested; }
    void ClearCloseAllRequest() { m_closeAllRequested = false; }

protected:
    // Event handler for button clicks
    virtual bool OnEvent(const int id, const long &lparam, const double &dparam, const string &sparam);

    // Override dialog state changes to ensure proper visibility management
    virtual bool OnShow(void);
    virtual bool OnHide(void);
    virtual bool OnChange(void);

    // State management methods
    void HideAllControls();
    void ShowAllControls();
    void RefreshDisplay();

    // Control creation helpers
    bool CreateControls();
    bool CreateLabels();
    bool CreateButtons();

private:
    // State management tracking
    bool m_isDialogVisible;
};

//+------------------------------------------------------------------+
//| Global Dialog Instance                                           |
//+------------------------------------------------------------------+
CForexTradeManagerDialog ExtDialog;

//+------------------------------------------------------------------+
//| Position Persistence Functions                                    |
//+------------------------------------------------------------------+
void SavePanelPosition();
bool LoadPanelPosition(int &x, int &y);

// Panel position constants
const int DEFAULT_PANEL_X = 20;
const int DEFAULT_PANEL_Y = 30;

//+------------------------------------------------------------------+
//| Expert initialization function                                    |
//+------------------------------------------------------------------+
int OnInit()
{
   //--- Initialize symbol info
   g_Digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   g_Point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   
   //--- Calculate pip value
   string baseCurrency = SymbolInfoString(_Symbol, SYMBOL_CURRENCY_BASE);
   string quoteCurrency = SymbolInfoString(_Symbol, SYMBOL_CURRENCY_PROFIT);
   
   // Determine pip size
   if(StringFind(baseCurrency, "JPY") >= 0 || StringFind(quoteCurrency, "JPY") >= 0)
      g_PipValue = 0.01;
   else if(g_Digits == 5 || g_Digits == 3)
      g_PipValue = g_Point * 10;
   else
      g_PipValue = g_Point;
   
   //--- Calculate point value per standard lot (USD per point per lot)
   double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double contractSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_CONTRACT_SIZE);
   
   if(tickSize != 0 && tickValue != 0)
      g_PointValue = (tickValue / tickSize) * g_Point;
   else
   {
      // Fallback calculation
      double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(quoteCurrency == "USD")
         g_PointValue = g_Point * contractSize; // Direct USD quote
      else
         g_PointValue = (g_Point * contractSize) / bid; // Cross pair
   }
   
   // Use manual pip value if mode is set to manual
   double pipValuePerLot = (inpPipValueMode == PIP_MANUAL) ? inpManualPipValue : (g_PointValue * (g_PipValue / g_Point));
   
   Print("Symbol: ", _Symbol);
   Print("Digits: ", g_Digits);
   Print("Point: ", g_Point);
   Print("Pip Value: ", g_PipValue);
   Print("Point Value per lot: $", g_PointValue);
   Print("Pip Value per lot: $", pipValuePerLot);
   Print("Pip Value Mode: ", (inpPipValueMode == PIP_MANUAL ? "Manual" : "Auto"));
   Print("Base Currency: ", baseCurrency);
   Print("Quote Currency: ", quoteCurrency);
   Print("Contract Size: ", contractSize);
   Print("Tick Size: ", tickSize);
   Print("Tick Value: ", tickValue);

   //--- Initialize Pending Order Line if enabled (below current price for visual clarity)
   if(inpUsePendingOrderLine)
   {
      double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      g_PendingOrderPrice = currentPrice - (30 * g_Point);  // 30 points below current price
      CreatePendingOrderLine(g_PendingOrderPrice);
      Print("✓ Pending Order Line initialized at ", DoubleToString(g_PendingOrderPrice, g_Digits));
   }

   // Initialize TP settings from input parameters
   // Note: During OnInit(), input parameters are authoritative (user may have just changed them)
   // File sync only happens via CheckAndReloadSettings() for percentage values
   g_ExitPercent1 = inpExitPercent1;
   g_ExitPercent2 = inpExitPercent2;

   //--- Load settings from file (prices and Active SL only, NOT percentage settings during OnInit)
   LoadSettingsFromFile(false);  // false = skip loading percentage settings

   //--- If position exists, recalculate partial lots based on current settings
   //    (Handles user changing exit percentages mid-trade)
   for(int i = 0; i < PositionsTotal(); i++)
   {
      if(PositionGetSymbol(i) == _Symbol)
      {
         double positionVolume = PositionGetDouble(POSITION_VOLUME);
         double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);

         // Recalculate based on current settings
         double exitPct1 = GetActiveExitPercent1();
         double exitPct2 = (inpNumberOfLevels >= 2) ? g_ExitPercent2 : 0;

         // Calculate TP1 lots
         if(inpNumberOfLevels == 1)
         {
            // TP1 is LAST level - calculate as 100% of position
            g_PartialLots1 = positionVolume;
            g_PartialLots1 = NormalizeDouble(MathFloor(g_PartialLots1 / lotStep) * lotStep, 2);
         }
         else
         {
            // TP1 is NOT last level - calculate based on percentage
            g_PartialLots1 = positionVolume * (exitPct1 / 100.0);
            g_PartialLots1 = NormalizeDouble(MathFloor(g_PartialLots1 / lotStep) * lotStep, 2);
         }

         // Calculate TP2 lots
         if(inpNumberOfLevels == 3)
         {
            // TP2 is NOT last level - calculate based on percentage
            g_PartialLots2 = positionVolume * (exitPct2 / 100.0);
            g_PartialLots2 = NormalizeDouble(MathFloor(g_PartialLots2 / lotStep) * lotStep, 2);
         }
         else
            g_PartialLots2 = 0;

         g_PartialLots3 = 0; // Last TP always closes remainder

         Print("Partial lots recalculated from settings change: TP1=", g_PartialLots1, ", TP2=", g_PartialLots2);
         break;
      }
   }

   //--- Save current input parameters back to file (persists EA settings panel changes)
   SaveSettingsToFile();

   //--- Configuration validation warnings
   if(inpPlaceTPOrder && inpAutoExecuteTP)
   {
      Print("⚠️ WARNING: Both TP Limit Orders (inpPlaceTPOrder) and Auto-Execution (inpAutoExecuteTP) are enabled!");
      Print("   This creates a CONFLICT - both features will try to execute the same TP levels.");
      Print("   RECOMMENDED: Choose ONE approach:");
      Print("   - Option 1: Enable inpPlaceTPOrder=true, Disable inpAutoExecuteTP=false (Broker-side automation)");
      Print("   - Option 2: Disable inpPlaceTPOrder=false, Enable inpAutoExecuteTP=true (EA-side monitoring)");
      Alert("⚠️ CONFIG WARNING: Both TP limit orders AND auto-execution are enabled. Check logs for details.");
   }

   //--- Initialize Supertrend if enabled
   if(inpUseSupertrendOnLastLevel)
   {
      // Create ATR indicator handle for Supertrend
      g_SupertrendATRHandle = iATR(_Symbol, PERIOD_CURRENT, inpSupertrendATRPeriod);
      if(g_SupertrendATRHandle == INVALID_HANDLE)
      {
         Print("ERROR: Failed to create ATR indicator handle for Supertrend");
         return INIT_FAILED;
      }

      // Initialize Supertrend buffers
      ArraySetAsSeries(g_SupertrendUp, true);
      ArraySetAsSeries(g_SupertrendDn, true);
      ArraySetAsSeries(g_SupertrendTrend, true);
      ArraySetAsSeries(g_SupertrendValue, true);

      ArrayResize(g_SupertrendUp, inpSupertrendBarsToCalculate);
      ArrayResize(g_SupertrendDn, inpSupertrendBarsToCalculate);
      ArrayResize(g_SupertrendTrend, inpSupertrendBarsToCalculate);
      ArrayResize(g_SupertrendValue, inpSupertrendBarsToCalculate);

      Print("✓ Supertrend initialized for last level management");
      Print("  ATR Period: ", inpSupertrendATRPeriod);
      Print("  ATR Multiplier: ", inpSupertrendATRMultiplier);
      Print("  Mode: ", (inpSupertrendTrailingStop ? "Trailing Stop (Broker-Based)" : "Auto-Close on Reversal (EA-Based)"));
   }

   //--- Create Draggable UI
   int panelX, panelY;
   LoadPanelPosition(panelX, panelY);

   // Create draggable dialog with proper spacing
   // Width: 300px (170 labels + 100 values + 30 spacing)
   // Height: 650px (proper space for all labels + buttons + padding)
   if(!ExtDialog.Create(0, "ForexTM", 0, panelX, panelY, panelX + 300, panelY + 650))
   {
      Print("Failed to create Forex Trade Manager dialog!");
      return INIT_FAILED;
   }

   // Initial dialog update
   ExtDialog.UpdateDisplay(g_IdealCalc, IsTradeManagementMode());

   //--- Initial calculation
   CalculateRisk();
   UpdateLines();

   //--- Set timer for updates
   EventSetTimer(1);

   //--- Restore Active SL line if there's an existing position for this symbol
   //    (Handles EA reload from settings changes, timeframe switches, etc.)
   //    Only restore if EA is managing SL (not broker)
   //    Priority: Use INI-saved values, then fallback to broker SL
   bool activeSLRestored = false;

   if(inpAutoExecuteSL)
   {
      // Check if we have Active SL data from INI file (loaded in LoadSettingsFromFile)
      if(g_ActiveSLPrice > 0 && g_ActivePositionTicket > 0)
      {
         // Verify the position still exists
         if(PositionSelectByTicket(g_ActivePositionTicket))
         {
            if(PositionGetString(POSITION_SYMBOL) == _Symbol)
            {
               CreateActiveSLLine(g_ActiveSLPrice);
               Print("Active SL line restored from INI - Position: ", g_ActivePositionTicket,
                     ", SL: ", DoubleToString(g_ActiveSLPrice, g_Digits),
                     ", Original SL: ", DoubleToString(g_OriginalSLPrice, g_Digits));
               activeSLRestored = true;
            }
         }
      }

      // Fallback: If INI didn't have Active SL, check if there's a position with broker SL
      if(!activeSLRestored)
      {
         for(int i = 0; i < PositionsTotal(); i++)
         {
            if(PositionGetSymbol(i) == _Symbol)
            {
               ulong ticket = PositionGetInteger(POSITION_TICKET);
               double positionSL = PositionGetDouble(POSITION_SL);

               if(positionSL > 0)
               {
                  // Restore Active SL line and state from broker SL
                  g_ActivePositionTicket = ticket;
                  g_ActiveSLPrice = positionSL;
                  g_OriginalSLPrice = positionSL;

                  CreateActiveSLLine(positionSL);

                  Print("Active SL line restored from broker SL - Position: ", ticket,
                        ", SL: ", DoubleToString(positionSL, g_Digits));
                  activeSLRestored = true;
                  break;
               }
            }
         }
      }
   }
   else
   {
      Print("Active SL line NOT restored - AutoExecuteSL is OFF (using broker SL orders)");
   }

   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   //--- Kill timer
   EventKillTimer();

   //--- Release Supertrend indicator handle
   if(g_SupertrendATRHandle != INVALID_HANDLE)
      IndicatorRelease(g_SupertrendATRHandle);

   //--- Delete Supertrend line objects
   DeleteSupertrendLines();

   //--- Save panel position before destroying dialog
   SavePanelPosition();

   //--- Destroy draggable dialog
   ExtDialog.Destroy(reason);

   //--- Delete trading lines (keep these)
   DeleteLines();

   //--- Delete actual order lines
   for(int i = ObjectsTotal(0, 0, OBJ_TREND) - 1; i >= 0; i--)
   {
      string objName = ObjectName(0, i, 0, OBJ_TREND);
      if(StringFind(objName, "ActualEntry_") == 0 || StringFind(objName, "ActualBE_") == 0)
         ObjectDelete(0, objName);
   }
}

//+------------------------------------------------------------------+
//| Manage Percentage-Based SL Trim                                  |
//| Trims Active SL based on price movement as % of target range    |
//+------------------------------------------------------------------+
void ManagePercentageBasedSLTrim()
{
   // Exit if feature is disabled
   if(!inpUsePercentageSLManagement)
      return;

   // Exit if no active position
   if(g_ActivePositionTicket == 0)
      return;

   // Exit if position is managed by Supertrend (Supertrend handles exit, not Active SL)
   if(inpUseSupertrendOnLastLevel && IsPositionManagedBySupertrend(g_ActivePositionTicket))
   {
      return;
   }

   // Check if position still exists
   if(!PositionSelectByTicket(g_ActivePositionTicket))
   {
      // Position closed, reset trim tracking
      g_SLTrimLevel1_Executed = false;
      g_SLTrimLevel2_Executed = false;
      g_SLTrimLevel3_Executed = false;
      return;
   }

   // Get position details
   double entryPrice = PositionGetDouble(POSITION_PRICE_OPEN);
   string comment = PositionGetString(POSITION_COMMENT);

   // Determine which calculation to use
   bool useConservative = (StringFind(comment, "_CONS") >= 0);
   RiskCalculation calc = useConservative ? g_ConservativeCalc : g_IdealCalc;

   // Define target range: Entry to TP1 (or final TP if only 1 level)
   double targetPrice = calc.partialTP1Price;
   if(targetPrice <= 0)
      return;  // No target defined yet

   // Calculate target range distance (in price)
   double targetRange = MathAbs(targetPrice - entryPrice);
   if(targetRange == 0)
      return;  // Invalid range

   // Get current price (respects execution mode)
   ENUM_POSITION_TYPE posType = g_ActiveTradeDirection ? POSITION_TYPE_BUY : POSITION_TYPE_SELL;
   double currentPrice = GetExecutionPrice(posType, true);

   // Calculate how far price has moved toward target (as percentage)
   double priceMovement = 0;
   if(g_ActiveTradeDirection)  // BUY
   {
      priceMovement = currentPrice - entryPrice;
   }
   else  // SELL
   {
      priceMovement = entryPrice - currentPrice;
   }

   // Calculate percentage of target reached
   double percentageMoved = (priceMovement / targetRange) * 100.0;
   if(percentageMoved < 0)
      percentageMoved = 0;  // Price moved against us

   // Calculate original SL distance
   double originalSLDistance = MathAbs(entryPrice - g_OriginalSLPrice);
   if(originalSLDistance == 0)
      return;  // No SL defined

   // Calculate BE price (entry + commissions + spread + offset)
   double actualBEPips = 0;
   int bePos = StringFind(comment, "|BE:");
   if(bePos >= 0)
   {
      string beStr = StringSubstr(comment, bePos + 4);
      actualBEPips = StringToDouble(beStr);
   }
   else
   {
      double actualLotSize = PositionGetDouble(POSITION_VOLUME);
      actualBEPips = CalculateBEPipsForOrder(actualLotSize);
   }

   double totalBEPips = actualBEPips + inpBEOffsetPips;
   double bePrice;
   if(g_ActiveTradeDirection)
      bePrice = entryPrice + (totalBEPips * g_PipValue);
   else
      bePrice = entryPrice - (totalBEPips * g_PipValue);

   bePrice = NormalizeDouble(bePrice, g_Digits);

   // Check each level in order (Level 1, then 2, then 3)
   // Process in reverse order to execute highest level first if multiple thresholds crossed

   // Level 3 (skip if disabled)
   if(inpSLTrimLevel3_PriceMove > 0 && !g_SLTrimLevel3_Executed && percentageMoved >= inpSLTrimLevel3_PriceMove)
   {
      double newSL = CalculateTrimmedSL(entryPrice, g_OriginalSLPrice, inpSLTrimLevel3_TrimAmount, bePrice, g_ActiveTradeDirection);
      if(MoveSLIfBetter(newSL, "Level 3"))
      {
         g_SLTrimLevel3_Executed = true;
         g_SLTrimLevel2_Executed = true;  // Mark lower levels as executed too
         g_SLTrimLevel1_Executed = true;
         Print("✓ SL Trim Level 3: Price moved ", DoubleToString(percentageMoved, 1),
               "% of target → SL trimmed by ", DoubleToString(inpSLTrimLevel3_TrimAmount, 0),
               "% to ", DoubleToString(newSL, g_Digits));
         return;
      }
   }

   // Level 2 (skip if disabled)
   if(inpSLTrimLevel2_PriceMove > 0 && !g_SLTrimLevel2_Executed && percentageMoved >= inpSLTrimLevel2_PriceMove)
   {
      double newSL = CalculateTrimmedSL(entryPrice, g_OriginalSLPrice, inpSLTrimLevel2_TrimAmount, bePrice, g_ActiveTradeDirection);
      if(MoveSLIfBetter(newSL, "Level 2"))
      {
         g_SLTrimLevel2_Executed = true;
         g_SLTrimLevel1_Executed = true;  // Mark lower level as executed too
         Print("✓ SL Trim Level 2: Price moved ", DoubleToString(percentageMoved, 1),
               "% of target → SL trimmed by ", DoubleToString(inpSLTrimLevel2_TrimAmount, 0),
               "% to ", DoubleToString(newSL, g_Digits));
         return;
      }
   }

   // Level 1 (skip if disabled)
   if(inpSLTrimLevel1_PriceMove > 0 && !g_SLTrimLevel1_Executed && percentageMoved >= inpSLTrimLevel1_PriceMove)
   {
      double newSL = CalculateTrimmedSL(entryPrice, g_OriginalSLPrice, inpSLTrimLevel1_TrimAmount, bePrice, g_ActiveTradeDirection);
      if(MoveSLIfBetter(newSL, "Level 1"))
      {
         g_SLTrimLevel1_Executed = true;
         Print("✓ SL Trim Level 1: Price moved ", DoubleToString(percentageMoved, 1),
               "% of target → SL trimmed by ", DoubleToString(inpSLTrimLevel1_TrimAmount, 0),
               "% to ", DoubleToString(newSL, g_Digits));
         return;
      }
   }
}

//+------------------------------------------------------------------+
//| Calculate Trimmed SL                                             |
//| trimPercent: 25 = trim by 25%, 100 = move to BE                 |
//+------------------------------------------------------------------+
double CalculateTrimmedSL(double entry, double originalSL, double trimPercent, double bePrice, bool isLong)
{
   // If trim is 100%, move to BE
   if(trimPercent >= 100.0)
      return bePrice;

   // Calculate trimmed SL: entry + (originalDistance * (1 - trim%))
   double originalDistance = MathAbs(entry - originalSL);
   double newDistance = originalDistance * (1.0 - trimPercent / 100.0);

   double newSL;
   if(isLong)
      newSL = entry - newDistance;
   else
      newSL = entry + newDistance;

   return NormalizeDouble(newSL, g_Digits);
}

//+------------------------------------------------------------------+
//| Move SL if Better (never move backwards)                         |
//+------------------------------------------------------------------+
bool MoveSLIfBetter(double newSL, string levelName)
{
   // Check if Active SL already at target (with tolerance)
   double tolerance = g_Point * 5;
   if(MathAbs(g_ActiveSLPrice - newSL) < tolerance)
      return false;  // Already at target

   // Check if new SL is better than current (don't move backwards)
   bool shouldMove = false;
   if(g_ActiveTradeDirection)  // BUY
      shouldMove = (newSL > g_ActiveSLPrice || g_ActiveSLPrice == 0);
   else  // SELL
      shouldMove = (newSL < g_ActiveSLPrice || g_ActiveSLPrice == 0);

   if(!shouldMove)
      return false;  // Would move backwards

   // Move the SL
   CreateActiveSLLine(newSL);

   // Save to file for multi-instance sync
   if(inpExportDirectory != "")
      SaveSettingsToFile();

   return true;
}

//+------------------------------------------------------------------+
//| Helper: Get current spread in pips                               |
//+------------------------------------------------------------------+
double GetCurrentSpreadPips()
{
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double spreadPips = (ask - bid) / g_PipValue;
   return spreadPips;
}

//+------------------------------------------------------------------+
//| Helper: Check spread condition and confirm with user             |
//| Returns: true = proceed with order, false = cancel order         |
//+------------------------------------------------------------------+
bool CheckSpreadCondition(string orderType)
{
   // Exit if spread checking is disabled
   if(!inpCheckSpreadCondition)
      return true;  // Proceed without checking

   // Get current spread
   double currentSpread = GetCurrentSpreadPips();

   // If spread is within acceptable range, proceed
   if(currentSpread < inpMaxSpreadPips)
      return true;

   // Spread exceeds limit - ask user for confirmation
   string message = StringFormat(
      "⚠️ SPREAD WARNING ⚠️\n\n"
      "Current spread: %.1f pips\n"
      "Your limit: %.1f pips\n\n"
      "The spread is ABOVE your acceptable limit.\n\n"
      "Do you want to continue with %s order?",
      currentSpread,
      inpMaxSpreadPips,
      orderType
   );

   int result = MessageBox(message, "High Spread Confirmation", MB_YESNO | MB_ICONWARNING);

   if(result == IDYES)
   {
      Print("User confirmed ", orderType, " order despite high spread (", DoubleToString(currentSpread, 1), " pips)");
      return true;
   }
   else
   {
      Print("User cancelled ", orderType, " order due to high spread (", DoubleToString(currentSpread, 1), " pips)");
      Comment("✗ ", orderType, " order cancelled due to high spread (", DoubleToString(currentSpread, 1), " pips)");
      return false;
   }
}

//+------------------------------------------------------------------+
//| Helper: Check margin usage and confirm with user                 |
//| Returns: true = proceed with order, false = cancel order         |
//+------------------------------------------------------------------+
bool CheckMarginCondition(string orderType)
{
   // Exit if margin checking is disabled
   if(!inpCheckMarginCondition)
      return true;  // Proceed without checking

   // Get the appropriate calculation based on display mode
   RiskCalculation calc = (inpDisplayMode == DISPLAY_CONSERVATIVE) ? g_ConservativeCalc : g_IdealCalc;

   // Get margin usage percentage
   double marginUsage = calc.buyingPowerPercent;

   // If margin usage is within acceptable range, proceed
   if(marginUsage < inpMaxMarginUsagePercent)
      return true;

   // Margin usage exceeds limit - ask user for confirmation
   string message = StringFormat(
      "⚠️ MARGIN WARNING ⚠️\n\n"
      "Margin usage: %.2f%%\n"
      "Your limit: %.2f%%\n\n"
      "This trade will use MORE margin than your acceptable limit.\n"
      "High margin usage increases risk of margin calls.\n\n"
      "Do you want to continue with %s order?",
      marginUsage,
      inpMaxMarginUsagePercent,
      orderType
   );

   int result = MessageBox(message, "High Margin Usage Confirmation", MB_YESNO | MB_ICONWARNING);

   if(result == IDYES)
   {
      Print("User confirmed ", orderType, " order despite high margin usage (", DoubleToString(marginUsage, 2), "%)");
      return true;
   }
   else
   {
      Print("User cancelled ", orderType, " order due to high margin usage (", DoubleToString(marginUsage, 2), "%)");
      Comment("✗ ", orderType, " order cancelled due to high margin usage (", DoubleToString(marginUsage, 2), "%)");
      return false;
   }
}

//+------------------------------------------------------------------+
//| Helper: Check execution cost and confirm with user               |
//| Returns: true = proceed with order, false = cancel order         |
//+------------------------------------------------------------------+
bool CheckExecutionCost(string orderType)
{
   // Exit if execution cost checking is disabled
   if(!inpCheckExecutionCost)
      return true;  // Proceed without checking

   // Get the appropriate calculation based on display mode
   RiskCalculation calc = (inpDisplayMode == DISPLAY_CONSERVATIVE) ? g_ConservativeCalc : g_IdealCalc;

   // Get execution cost percentage
   double executionCost = calc.executionCostPercent;

   // If execution cost is within acceptable range, proceed
   if(executionCost < inpMaxExecutionCostPercent)
      return true;

   // Execution cost exceeds limit - ask user for confirmation
   string message = StringFormat(
      "⚠️ EXECUTION COST WARNING ⚠️\n\n"
      "Execution Cost: %.2f%%\n"
      "Your limit: %.2f%%\n\n"
      "Fees are consuming %.2f%% of your gross profit.\n"
      "This trade has HIGH execution costs relative to potential profit.\n\n"
      "Do you want to continue with %s order?",
      executionCost,
      inpMaxExecutionCostPercent,
      executionCost,
      orderType
   );

   int result = MessageBox(message, "High Execution Cost Confirmation", MB_YESNO | MB_ICONWARNING);

   if(result == IDYES)
   {
      Print("User confirmed ", orderType, " order despite high execution cost (", DoubleToString(executionCost, 2), "%)");
      return true;
   }
   else
   {
      Print("User cancelled ", orderType, " order due to high execution cost (", DoubleToString(executionCost, 2), "%)");
      Comment("✗ ", orderType, " order cancelled due to high execution cost (", DoubleToString(executionCost, 2), "%)");
      return false;
   }
}

//+------------------------------------------------------------------+
//| Helper: Check if position has already executed a TP level       |
//+------------------------------------------------------------------+
bool HasExecutedTPLevel(ulong ticket, int tpLevel)
{
   ulong ticketArray[];

   if(tpLevel == 1)
      ArrayCopy(ticketArray, g_ExecutedTP1Positions);
   else if(tpLevel == 2)
      ArrayCopy(ticketArray, g_ExecutedTP2Positions);
   else if(tpLevel == 3)
      ArrayCopy(ticketArray, g_ExecutedTP3Positions);
   else
      return false;

   int size = ArraySize(ticketArray);
   for(int i = 0; i < size; i++)
   {
      if(ticketArray[i] == ticket)
         return true;
   }

   return false;
}

//+------------------------------------------------------------------+
//| Helper: Mark position as having executed a TP level             |
//+------------------------------------------------------------------+
void MarkTPLevelExecuted(ulong ticket, int tpLevel)
{
   if(tpLevel == 1)
   {
      int size = ArraySize(g_ExecutedTP1Positions);
      ArrayResize(g_ExecutedTP1Positions, size + 1);
      g_ExecutedTP1Positions[size] = ticket;
   }
   else if(tpLevel == 2)
   {
      int size = ArraySize(g_ExecutedTP2Positions);
      ArrayResize(g_ExecutedTP2Positions, size + 1);
      g_ExecutedTP2Positions[size] = ticket;
   }
   else if(tpLevel == 3)
   {
      int size = ArraySize(g_ExecutedTP3Positions);
      ArrayResize(g_ExecutedTP3Positions, size + 1);
      g_ExecutedTP3Positions[size] = ticket;
   }
}

//+------------------------------------------------------------------+
//| Execute Partial TP Close                                         |
//+------------------------------------------------------------------+
bool ExecutePartialClose(ulong ticket, double percentage, int tpLevel, double tpPrice, double absoluteLots = 0, bool isLastTP = false)
{
   if(!PositionSelectByTicket(ticket))
      return false;

   double currentVolume = PositionGetDouble(POSITION_VOLUME);
   double closeVolume;

   // If this is the last TP level, close entire remaining position to avoid rounding errors
   if(isLastTP)
   {
      closeVolume = currentVolume;
   }
   // Use absolute lot size if provided, otherwise calculate from percentage
   else if(absoluteLots > 0)
   {
      // Absolute lots are already lot-step normalized from CalculateRisk()
      closeVolume = NormalizeDouble(absoluteLots, 2);
   }
   else
   {
      // Calculate from current volume percentage and apply lot step normalization
      closeVolume = currentVolume * percentage / 100.0;
      double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
      closeVolume = NormalizeDouble(MathFloor(closeVolume / lotStep) * lotStep, 2);
   }

   // Ensure we close at least the minimum lot size
   double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   if(closeVolume < minLot)
   {
      Print("WARNING: Calculated close volume (", closeVolume, ") is less than minimum lot size (", minLot, ")");
      return false;
   }

   // Don't close more than available
   if(closeVolume > currentVolume)
   {
      Print("WARNING: Close volume (", closeVolume, ") exceeds current volume (", currentVolume, "), adjusting");
      closeVolume = currentVolume;
   }

   // Execute the partial close
   // Determine account mode based on user setting
   bool isNetting = false;

   if(inpAccountMode == ACCOUNT_MODE_AUTO)
   {
      // Auto-detect account mode
      ENUM_ACCOUNT_MARGIN_MODE marginMode = (ENUM_ACCOUNT_MARGIN_MODE)AccountInfoInteger(ACCOUNT_MARGIN_MODE);
      isNetting = (marginMode == ACCOUNT_MARGIN_MODE_RETAIL_NETTING || marginMode == ACCOUNT_MARGIN_MODE_EXCHANGE);
   }
   else if(inpAccountMode == ACCOUNT_MODE_NETTING)
   {
      isNetting = true;
   }
   else // ACCOUNT_MODE_HEDGING
   {
      isNetting = false;
   }

   bool result = false;

   if(isNetting)
   {
      // Netting mode: Close by symbol with opposite order
      ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);

      if(posType == POSITION_TYPE_BUY)
         result = trade.Sell(closeVolume, _Symbol);  // Close BUY with SELL
      else
         result = trade.Buy(closeVolume, _Symbol);   // Close SELL with BUY
   }
   else
   {
      // Hedging mode: Use ticket-based partial close
      result = trade.PositionClosePartial(ticket, closeVolume);
   }

   if(result)
   {
      Print("✓ Partial TP", tpLevel, " executed: Closed ", DoubleToString(closeVolume, 2),
            " lots (", DoubleToString(percentage, 1), "%) at TP", tpLevel, " price ", DoubleToString(tpPrice, _Digits),
            " for Ticket #", ticket);
      return true;
   }
   else
   {
      uint retcode = trade.ResultRetcode();
      Print("✗ Failed to execute partial close for Ticket #", ticket);
      Print("   Error code: ", retcode, " - ", trade.ResultRetcodeDescription());
      Print("   Attempted volume: ", DoubleToString(closeVolume, 2));
      Print("   Position volume: ", DoubleToString(currentVolume, 2));
      Print("   HINT: If using TP limit orders (inpPlaceTPOrder=true), disable auto-execution (inpAutoExecuteTP=false) to avoid conflicts");
      return false;
   }
}

//+------------------------------------------------------------------+
//| Manage Stop Loss Execution (Active SL Line Monitor)              |
//+------------------------------------------------------------------+
void ManageStopLossExecution()
{
   // Exit if auto-execution is disabled
   if(!inpAutoExecuteSL)
      return;

   // Exit if currently reloading from file (prevent false executions during sync)
   if(g_IsReloadingFromFile)
      return;

   // Exit if no active position
   if(g_ActivePositionTicket == 0)
      return;

   // Exit if Active SL not set
   if(g_ActiveSLPrice <= 0)
      return;

   // Exit if position is managed by Supertrend (Supertrend handles exit, not Active SL)
   if(inpUseSupertrendOnLastLevel && IsPositionManagedBySupertrend(g_ActivePositionTicket))
   {
      return;
   }

   // Check if position still exists
   if(!PositionSelectByTicket(g_ActivePositionTicket))
   {
      // Position closed, cleanup
      DeleteActiveSLLine();
      return;
   }

   // Check if already executed
   int size = ArraySize(g_ExecutedSLPositions);
   for(int j = 0; j < size; j++)
   {
      if(g_ExecutedSLPositions[j] == g_ActivePositionTicket)
         return;  // Already executed
   }

   // Get execution price using centralized function (respects inpExecutionMode)
   ENUM_POSITION_TYPE posType = g_ActiveTradeDirection ? POSITION_TYPE_BUY : POSITION_TYPE_SELL;
   double currentPrice = GetExecutionPrice(posType, true);  // true = closing position

   // Check if Active SL price changed (user dragged or system moved SL)
   double priceTolerance = g_Point * 2;  // 2 point tolerance for float comparison
   bool slPriceChanged = (MathAbs(g_ActiveSLPrice - g_LastActiveSLPriceCheck) > priceTolerance);

   if(slPriceChanged)
   {
      // SL price changed - skip execution this tick, just update tracking
      g_LastActiveSLPriceCheck = g_ActiveSLPrice;
      return;
   }

   // SL price stable - check if market reached it
   bool slReached = false;
   if(g_ActiveTradeDirection)  // BUY
      slReached = (currentPrice <= g_ActiveSLPrice);
   else  // SELL
      slReached = (currentPrice >= g_ActiveSLPrice);

   // Debug logging to understand execution conditions
   if(slReached)
   {
      Print("Active SL execution triggered:");
      Print("  Direction: ", (g_ActiveTradeDirection ? "BUY (long)" : "SELL (short)"));
      Print("  Current Price: ", DoubleToString(currentPrice, g_Digits));
      Print("  Active SL Price: ", DoubleToString(g_ActiveSLPrice, g_Digits));
      Print("  Distance: ", DoubleToString(MathAbs(currentPrice - g_ActiveSLPrice) / g_PipValue, 2), " pips");
   }

   if(slReached)
   {
      // Close entire position
      // Note: No volume check needed - full close makes position disappear completely.
      // If another instance already closed it, PositionSelectByTicket() check above handles it.
      bool result = trade.PositionClose(g_ActivePositionTicket);

      if(result)
      {
         Print("OK Active SL executed: Closed entire position at Active SL price ", DoubleToString(g_ActiveSLPrice, g_Digits),
               " for Ticket #", g_ActivePositionTicket);

         // Mark as executed
         int size = ArraySize(g_ExecutedSLPositions);
         ArrayResize(g_ExecutedSLPositions, size + 1);
         g_ExecutedSLPositions[size] = g_ActivePositionTicket;

         // Delete Active SL line
         DeleteActiveSLLine();

         // Notifications
         if(inpSLExecuteEnableAlert)
            Alert("Active SL executed (100%) for ", _Symbol, " Ticket #", g_ActivePositionTicket);

         if(inpSLExecuteEnableSound)
            PlaySound(inpSLExecuteSoundFile);

         if(inpSLExecuteEnablePush)
            SendNotification("Active SL executed for " + _Symbol + " Ticket: " + IntegerToString(g_ActivePositionTicket));

         if(inpSLExecuteEnableEmail)
         {
            string subject = "MT5 Alert: Active SL Executed - " + _Symbol;
            string body = "Active Stop Loss executed!\n\n" +
                         "Symbol: " + _Symbol + "\n" +
                         "Ticket: " + IntegerToString(g_ActivePositionTicket) + "\n" +
                         "Active SL Price: " + DoubleToString(g_ActiveSLPrice, _Digits) + "\n" +
                         "Closed: 100% (Full Position)\n" +
                         "Time: " + TimeToString(TimeCurrent(), TIME_DATE | TIME_SECONDS);
            SendMail(subject, body);
         }
      }
      else
      {
         Print("✗ Failed to close position for Ticket #", g_ActivePositionTicket, " - Error: ", trade.ResultRetcodeDescription());
      }
   }
}

//+------------------------------------------------------------------+
//| Manage Trailing Stop (Move Active SL to Previous TP Level)       |
//+------------------------------------------------------------------+
void ManageTrailingStop()
{
   // Exit if trailing stop is disabled
   if(!inpTrailSLToNextTP)
      return;

   // Exit if no active position
   if(g_ActivePositionTicket == 0)
      return;

   // Exit if position is managed by Supertrend (Supertrend handles exit, not Active SL)
   if(inpUseSupertrendOnLastLevel && IsPositionManagedBySupertrend(g_ActivePositionTicket))
   {
      return;
   }

   // Check if position still exists
   if(!PositionSelectByTicket(g_ActivePositionTicket))
   {
      // Position closed, cleanup
      DeleteActiveSLLine();
      return;
   }

   // Get position details
   double entryPrice = PositionGetDouble(POSITION_PRICE_OPEN);
   string comment = PositionGetString(POSITION_COMMENT);

   // Determine which calculation to use based on comment
   bool useConservative = (StringFind(comment, "_CONS") >= 0);
   RiskCalculation calc = useConservative ? g_ConservativeCalc : g_IdealCalc;

   double newSL = 0;
   string levelName = "";
   int activeNumLevels = inpNumberOfLevels;

   // Trailing Stop Logic (Level-Aware):
   // Progressive Protection Flow (combined with Trigger Line):
   //
   // 1 level:  Trigger → SL to BE
   //           No trailing (100% exits at TP1)
   //
   // 2 levels: Trigger → SL to 1/2 SL (50% risk reduction)
   //           TP1 hit → SL to BE (0% risk - breakeven)
   //
   // 3 levels: Trigger → SL to 1/2 SL (50% risk reduction)
   //           TP1 hit → SL to BE (0% risk - breakeven)
   //           TP2 hit → SL to TP1 (profit locked in)

   // Calculate BE price (entry + commissions + spread + offset)
   // Note: 'comment' already retrieved above at line 1059
   double actualBEPips = 0;
   int bePos = StringFind(comment, "|BE:");
   if(bePos >= 0)
   {
      // Extract BE value from comment (locked in at order placement)
      string beStr = StringSubstr(comment, bePos + 4);  // Skip "|BE:"
      actualBEPips = StringToDouble(beStr);
   }
   else
   {
      // Fallback: Calculate BE for old orders (no BE in comment)
      double actualLotSize = PositionGetDouble(POSITION_VOLUME);
      actualBEPips = CalculateBEPipsForOrder(actualLotSize);
   }

   // Add user's desired offset
   double totalBEPips = actualBEPips + inpBEOffsetPips;

   // Calculate BE price based on actual entry
   double bePrice;
   if(g_ActiveTradeDirection)  // BUY
      bePrice = entryPrice + (totalBEPips * g_PipValue);
   else  // SELL
      bePrice = entryPrice - (totalBEPips * g_PipValue);

   bePrice = NormalizeDouble(bePrice, g_Digits);

   if(activeNumLevels == 1)
   {
      // No trailing for 1-level setup (full exit at TP1)
      return;
   }
   else if(activeNumLevels == 2)
   {
      // TP1 hit → Move Active SL to BE
      if(HasExecutedTPLevel(g_ActivePositionTicket, 1))
      {
         newSL = bePrice;
         levelName = "BE";
      }
   }
   else if(activeNumLevels == 3)
   {
      // TP2 hit → Move Active SL to TP1 price
      if(HasExecutedTPLevel(g_ActivePositionTicket, 2) && !HasExecutedTPLevel(g_ActivePositionTicket, 3))
      {
         newSL = calc.partialTP1Price;
         levelName = "TP1";
      }
      // TP1 hit → Move Active SL to BE
      else if(HasExecutedTPLevel(g_ActivePositionTicket, 1) && !HasExecutedTPLevel(g_ActivePositionTicket, 2))
      {
         newSL = bePrice;
         levelName = "BE";
      }
   }

   // Execute Active SL movement if needed
   if(newSL > 0)
   {
      // Check if Active SL already at target level (with tolerance)
      double tolerance = g_Point * 5;
      if(MathAbs(g_ActiveSLPrice - newSL) < tolerance)
         return;  // Already at target level

      // Check if new SL is better than current (don't move it backwards)
      bool shouldMove = false;
      if(g_ActiveTradeDirection)  // BUY
         shouldMove = (newSL > g_ActiveSLPrice || g_ActiveSLPrice == 0);
      else  // SELL
         shouldMove = (newSL < g_ActiveSLPrice || g_ActiveSLPrice == 0);

      if(shouldMove)
      {
         // Move Active SL line
         newSL = NormalizeDouble(newSL, g_Digits);
         CreateActiveSLLine(newSL);

         // Save to file for multi-instance sync
         if(inpExportDirectory != "")
            SaveSettingsToFile();

         Print("Trailing Stop: Moved Active SL to ", levelName, " price ", DoubleToString(newSL, g_Digits));
      }
   }
}

//+------------------------------------------------------------------+
//| Manage Partial TP Execution Automation                           |
//+------------------------------------------------------------------+
void ManagePartialTPExecution()
{
   // Exit if all auto-execution features are disabled
   if(!inpAutoExecuteTP)
      return;

   // Exit if currently reloading from file (prevent false executions during sync)
   if(g_IsReloadingFromFile)
      return;

   // Loop through all positions
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket <= 0) continue;

      // Filter: only process positions for this symbol
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;

      // Get position details
      ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      string comment = PositionGetString(POSITION_COMMENT);

      // Determine which calculation to use based on comment
      bool useConservative = (StringFind(comment, "_CONS") >= 0);
      RiskCalculation calc = useConservative ? g_ConservativeCalc : g_IdealCalc;

      // Get execution price based on selected mode (Bid/Ask or Visual/Midpoint)
      double currentPrice = GetExecutionPrice(posType, true);  // true = closing position

      // Check TP1
      // Skip TP1 check entirely if Supertrend is managing entire position (1 level + Supertrend)
      // In this case, position is already under Supertrend management from the start
      bool supertrendManagingAll = (inpNumberOfLevels == 1 && inpUseSupertrendOnLastLevel);

      if(!supertrendManagingAll && !HasExecutedTPLevel(ticket, 1) && calc.partialTP1Price > 0)
      {
         // Check if TP1 price changed (line moved vs market reached)
         double priceTolerance = g_Point * 2;  // 2 point tolerance for float comparison
         bool tp1PriceChanged = (MathAbs(calc.partialTP1Price - g_LastTP1Price) > priceTolerance);

         if(tp1PriceChanged)
         {
            // TP price changed - skip execution this tick, just update tracking
            g_LastTP1Price = calc.partialTP1Price;
            continue;  // Skip to next position
         }

         // TP price stable - check if market reached it
         bool tp1Reached = false;
         if(posType == POSITION_TYPE_BUY)
            tp1Reached = (currentPrice >= calc.partialTP1Price);
         else
            tp1Reached = (currentPrice <= calc.partialTP1Price);

         // Debug logging
         if(tp1Reached)
         {
            Print("TP1 execution triggered:");
            Print("  Direction: ", (posType == POSITION_TYPE_BUY ? "BUY (long)" : "SELL (short)"));
            Print("  Current Price: ", DoubleToString(currentPrice, g_Digits));
            Print("  TP1 Price: ", DoubleToString(calc.partialTP1Price, g_Digits));
            Print("  Distance: ", DoubleToString(MathAbs(currentPrice - calc.partialTP1Price) / g_PipValue, 2), " pips");
         }

         if(tp1Reached)
         {
            // TP1 is last TP only if we have exactly 1 level
            bool isLastTP = (inpNumberOfLevels == 1);

            // Multi-instance protection: Volume STATE verification
            // ONLY needed if TP1 is NOT the last level (i.e., 2+ levels)
            // If TP1 is last level, it closes 100% - one instance succeeds, other finds no position
            if(!isLastTP)
            {
               // At TP1, current volume should ≈ original total lots (within 1%)
               // This ensures only ONE instance executes when multiple instances check simultaneously
               double currentVolume = PositionGetDouble(POSITION_VOLUME);
               double expectedVolume = g_OriginalTotalLots;  // At TP1, we expect full position
               double tolerancePercent = 0.01;  // 1% tolerance for broker rounding
               double toleranceAmount = expectedVolume * tolerancePercent;

               Print("═══ TP1 Volume State Check ═══");
               Print("  Ticket: #", ticket);
               Print("  Current Volume: ", DoubleToString(currentVolume, 2), " lots");
               Print("  Expected Volume (Original Total): ", DoubleToString(expectedVolume, 2), " lots");
               Print("  Tolerance (1%): ±", DoubleToString(toleranceAmount, 2), " lots");
               Print("  TP1 will close: ", DoubleToString(g_PartialLots1, 2), " lots (partial)");

               // Check if current volume matches expected state (original total ± 1%)
               bool volumeMatchesState = (MathAbs(currentVolume - expectedVolume) <= toleranceAmount);
               Print("  Volume Matches TP1 State? ", volumeMatchesState ? "YES (can execute)" : "NO (already executed by another instance)");

               // If current volume doesn't match expected state, TP1 was already executed
               if(!volumeMatchesState)
               {
                  Print("✗ TP1 SKIPPED - Current volume ", DoubleToString(currentVolume, 2),
                        " lots doesn't match expected ", DoubleToString(expectedVolume, 2),
                        " lots - another instance already executed TP1");
                  MarkTPLevelExecuted(ticket, 1); // Mark as executed to prevent repeated attempts

                  // Check if Supertrend should activate on this instance after TP1
                  // (Same logic as successful TP1 execution)
                  bool nextLevelIsLast = (inpNumberOfLevels == 2);  // With 2 levels, TP2 is last
                  if(inpUseSupertrendOnLastLevel && nextLevelIsLast)
                  {
                     // Add remaining position to Supertrend management
                     AddSupertrendManagedPosition(ticket, "TP1 executed by another instance - remainder handed to Supertrend");

                     // Delete Active SL line (Supertrend manages exit now)
                     if(ticket == g_ActivePositionTicket)
                        DeleteActiveSLLine();

                     Print("✓ Supertrend activated for remaining position after TP1 (executed by another instance)");
                  }

                  continue;
               }
               else
               {
                  Print("✓ TP1 PROCEEDING - Volume state verified (", DoubleToString(currentVolume, 2), " ≈ ", DoubleToString(expectedVolume, 2), " lots)");
               }
            }
            else
            {
               Print("TP1 is last level - closes 100% of position, no volume state check needed");
            }

            // For 2+ levels with Supertrend on last: hand over after TP1 closes partial
            // (This case shouldn't happen anymore since we're skipping when supertrendManagingAll,
            //  but kept for 2+ level scenarios where TP1 closes partial and TP2/TP3 is last)
            if(inpUseSupertrendOnLastLevel && isLastTP)
            {
               // Mark as executed to prevent repeated checks
               MarkTPLevelExecuted(ticket, 1);

               // Add position to Supertrend management
               AddSupertrendManagedPosition(ticket, "TP1 price reached (last level)");

               // Delete Active SL line (Supertrend manages exit now)
               if(ticket == g_ActivePositionTicket)
                  DeleteActiveSLLine();

               Print("✓ TP1 is last level - Position #", ticket, " handed over to Supertrend management");

               // Notification
               if(inpTPExecuteEnableAlert)
                  Alert("TP1 reached - Position #", ticket, " now managed by Supertrend for ", _Symbol);
            }
            else if(ExecutePartialClose(ticket, inpExitPercent1, 1, calc.partialTP1Price, g_PartialLots1, isLastTP))
            {
               MarkTPLevelExecuted(ticket, 1);

               // Check if next level (TP2 or TP3) is the last AND Supertrend is managing last
               // If so, hand over the remaining position to Supertrend management
               bool nextLevelIsLast = (inpNumberOfLevels == 2);  // With 2 levels, TP2 is last

               if(inpUseSupertrendOnLastLevel && nextLevelIsLast)
               {
                  // Add remaining position to Supertrend management
                  AddSupertrendManagedPosition(ticket, "TP1 executed - remainder handed to Supertrend");

                  // Delete Active SL line (Supertrend manages exit now)
                  if(ticket == g_ActivePositionTicket)
                     DeleteActiveSLLine();

                  Print("✓ TP1 closed partial - Remaining position #", ticket, " handed over to Supertrend management");
               }

               // Notifications
               if(inpTPExecuteEnableAlert)
                  Alert("Partial TP1 executed (", DoubleToString(inpExitPercent1, 1), "%) for ", _Symbol, " Ticket #", ticket);

               if(inpTPExecuteEnableSound)
                  PlaySound(inpTPExecuteSoundFile);

               if(inpTPExecuteEnablePush)
                  SendNotification("Partial TP1 executed for " + _Symbol + " Ticket: " + IntegerToString(ticket));

               if(inpTPExecuteEnableEmail)
               {
                  string subject = "MT5 Alert: Partial TP1 Executed - " + _Symbol;
                  string body = "Partial Take Profit 1 executed!\n\n" +
                               "Symbol: " + _Symbol + "\n" +
                               "Ticket: " + IntegerToString(ticket) + "\n" +
                               "TP1 Price: " + DoubleToString(calc.partialTP1Price, _Digits) + "\n" +
                               "Closed: " + DoubleToString(inpExitPercent1, 1) + "%\n" +
                               "Time: " + TimeToString(TimeCurrent(), TIME_DATE | TIME_SECONDS);
                  SendMail(subject, body);
               }
            }
         }
      }

      // Check TP2
      if(!HasExecutedTPLevel(ticket, 2) && calc.partialTP2Price > 0)
      {
         // Check if TP2 price changed (line moved vs market reached)
         double priceTolerance = g_Point * 2;  // 2 point tolerance for float comparison
         bool tp2PriceChanged = (MathAbs(calc.partialTP2Price - g_LastTP2Price) > priceTolerance);

         if(tp2PriceChanged)
         {
            // TP price changed - skip execution this tick, just update tracking
            g_LastTP2Price = calc.partialTP2Price;
            continue;  // Skip to next position
         }

         // TP price stable - check if market reached it
         bool tp2Reached = false;
         if(posType == POSITION_TYPE_BUY)
            tp2Reached = (currentPrice >= calc.partialTP2Price);
         else
            tp2Reached = (currentPrice <= calc.partialTP2Price);

         if(tp2Reached)
         {
            // TP2 is last TP if we have exactly 2 levels
            bool isLastTP = (inpNumberOfLevels == 2);

            // Multi-instance protection: Volume STATE verification
            // ONLY needed if TP2 is NOT the last level (i.e., 3 levels)
            // If TP2 is last level, it closes 100% - one instance succeeds, other finds no position
            if(!isLastTP)
            {
               // At TP2, current volume should ≈ (original total - TP1 lots) within 1%
               // This ensures only ONE instance executes when multiple instances check simultaneously
               double currentVolume = PositionGetDouble(POSITION_VOLUME);
               double expectedVolume = g_OriginalTotalLots - g_PartialLots1;  // After TP1, before TP2
               double tolerancePercent = 0.01;  // 1% tolerance for broker rounding
               double toleranceAmount = g_OriginalTotalLots * tolerancePercent;  // Use original for tolerance calc

               Print("═══ TP2 Volume State Check ═══");
               Print("  Ticket: #", ticket);
               Print("  Current Volume: ", DoubleToString(currentVolume, 2), " lots");
               Print("  Expected Volume (Original - TP1): ", DoubleToString(expectedVolume, 2), " lots");
               Print("  Calculation: ", DoubleToString(g_OriginalTotalLots, 2), " - ", DoubleToString(g_PartialLots1, 2), " = ", DoubleToString(expectedVolume, 2));
               Print("  Tolerance (1% of original): ±", DoubleToString(toleranceAmount, 2), " lots");
               Print("  TP2 will close: ", DoubleToString(g_PartialLots2, 2), " lots (partial)");

               // Check if current volume matches expected state ((original - TP1) ± 1%)
               bool volumeMatchesState = (MathAbs(currentVolume - expectedVolume) <= toleranceAmount);
               Print("  Volume Matches TP2 State? ", volumeMatchesState ? "YES (can execute)" : "NO (already executed by another instance)");

               // If current volume doesn't match expected state, TP2 was already executed
               if(!volumeMatchesState)
               {
                  Print("✗ TP2 SKIPPED - Current volume ", DoubleToString(currentVolume, 2),
                        " lots doesn't match expected ", DoubleToString(expectedVolume, 2),
                        " lots - another instance already executed TP2");
                  MarkTPLevelExecuted(ticket, 2);

                  // Check if Supertrend should activate on this instance after TP2
                  // (Same logic as successful TP2 execution)
                  bool nextLevelIsLast = (inpNumberOfLevels == 3);  // With 3 levels, TP3 is last
                  if(inpUseSupertrendOnLastLevel && nextLevelIsLast)
                  {
                     // Add remaining position to Supertrend management
                     AddSupertrendManagedPosition(ticket, "TP2 executed by another instance - remainder handed to Supertrend");

                     // Delete Active SL line (Supertrend manages exit now)
                     if(ticket == g_ActivePositionTicket)
                        DeleteActiveSLLine();

                     Print("✓ Supertrend activated for remaining position after TP2 (executed by another instance)");
                  }

                  continue;
               }
               else
               {
                  Print("✓ TP2 PROCEEDING - Volume state verified (", DoubleToString(currentVolume, 2), " ≈ ", DoubleToString(expectedVolume, 2), " lots)");
               }
            }
            else
            {
               Print("TP2 is last level - closes 100% of remaining position, no volume state check needed");
            }

            // Skip TP2 execution if Supertrend enabled on last level
            if(inpUseSupertrendOnLastLevel && isLastTP)
            {
               // Mark as executed to prevent repeated checks
               MarkTPLevelExecuted(ticket, 2);

               // Add position to Supertrend management
               AddSupertrendManagedPosition(ticket, "TP2 price reached (last level)");

               // Delete Active SL line (Supertrend manages exit now)
               if(ticket == g_ActivePositionTicket)
                  DeleteActiveSLLine();

               Print("✓ TP2 is last level - Position #", ticket, " handed over to Supertrend management");

               // Notification
               if(inpTPExecuteEnableAlert)
                  Alert("TP2 reached - Position #", ticket, " now managed by Supertrend for ", _Symbol);
            }
            else if(ExecutePartialClose(ticket, inpExitPercent2, 2, calc.partialTP2Price, g_PartialLots2, isLastTP))
            {
               MarkTPLevelExecuted(ticket, 2);

               // Check if next level (TP3) is the last AND Supertrend is managing last
               // If so, hand over the remaining position to Supertrend management
               bool nextLevelIsLast = (inpNumberOfLevels == 3);  // With 3 levels, TP3 is last

               if(inpUseSupertrendOnLastLevel && nextLevelIsLast)
               {
                  // Add remaining position to Supertrend management
                  AddSupertrendManagedPosition(ticket, "TP2 executed - remainder handed to Supertrend");

                  // Delete Active SL line (Supertrend manages exit now)
                  if(ticket == g_ActivePositionTicket)
                     DeleteActiveSLLine();

                  Print("✓ TP2 closed partial - Remaining position #", ticket, " handed over to Supertrend management");
               }

               // Notifications
               if(inpTPExecuteEnableAlert)
                  Alert("Partial TP2 executed (", DoubleToString(inpExitPercent2, 1), "%) for ", _Symbol, " Ticket #", ticket);

               if(inpTPExecuteEnableSound)
                  PlaySound(inpTPExecuteSoundFile);

               if(inpTPExecuteEnablePush)
                  SendNotification("Partial TP2 executed for " + _Symbol + " Ticket: " + IntegerToString(ticket));

               if(inpTPExecuteEnableEmail)
               {
                  string subject = "MT5 Alert: Partial TP2 Executed - " + _Symbol;
                  string body = "Partial Take Profit 2 executed!\n\n" +
                               "Symbol: " + _Symbol + "\n" +
                               "Ticket: " + IntegerToString(ticket) + "\n" +
                               "TP2 Price: " + DoubleToString(calc.partialTP2Price, _Digits) + "\n" +
                               "Closed: " + DoubleToString(inpExitPercent2, 1) + "%\n" +
                               "Time: " + TimeToString(TimeCurrent(), TIME_DATE | TIME_SECONDS);
                  SendMail(subject, body);
               }
            }
         }
      }

      // Check TP3 (only if 3 levels are configured)
      if(inpNumberOfLevels == 3 && !HasExecutedTPLevel(ticket, 3) && calc.partialTP3Price > 0)
      {
         // Check if TP3 price changed (line moved vs market reached)
         double priceTolerance = g_Point * 2;  // 2 point tolerance for float comparison
         bool tp3PriceChanged = (MathAbs(calc.partialTP3Price - g_LastTP3Price) > priceTolerance);

         if(tp3PriceChanged)
         {
            // TP price changed - skip execution this tick, just update tracking
            g_LastTP3Price = calc.partialTP3Price;
            continue;  // Skip to next position
         }

         // TP price stable - check if market reached it
         bool tp3Reached = false;
         if(posType == POSITION_TYPE_BUY)
            tp3Reached = (currentPrice >= calc.partialTP3Price);
         else
            tp3Reached = (currentPrice <= calc.partialTP3Price);

         if(tp3Reached)
         {
            // Multi-instance protection: NOT NEEDED for TP3
            // TP3 is ALWAYS the last level - closes 100% of remaining position
            // One instance succeeds and closes position, other instance finds no position (natural coordination)
            Print("TP3 is always last level - closes 100% of remaining position, no volume state check needed");

            // Calculate remaining percentage for TP3
            double remainingPercent = 100.0 - inpExitPercent1 - inpExitPercent2;

            // Skip TP3 execution if Supertrend enabled on last level (TP3 is always last)
            if(inpUseSupertrendOnLastLevel)
            {
               // Mark as executed to prevent repeated checks
               MarkTPLevelExecuted(ticket, 3);

               // Add position to Supertrend management
               AddSupertrendManagedPosition(ticket, "TP3 price reached (last level)");

               // Delete Active SL line (Supertrend manages exit now)
               if(ticket == g_ActivePositionTicket)
                  DeleteActiveSLLine();

               Print("✓ TP3 is last level - Position #", ticket, " handed over to Supertrend management");

               // Notification
               if(inpTPExecuteEnableAlert)
                  Alert("TP3 reached - Position #", ticket, " now managed by Supertrend for ", _Symbol);
            }
            else if(ExecutePartialClose(ticket, remainingPercent, 3, calc.partialTP3Price, 0, true))
            {
               MarkTPLevelExecuted(ticket, 3);

               // Notifications
               if(inpTPExecuteEnableAlert)
                  Alert("Partial TP3 executed (", DoubleToString(remainingPercent, 1), "%) for ", _Symbol, " Ticket #", ticket);

               if(inpTPExecuteEnableSound)
                  PlaySound(inpTPExecuteSoundFile);

               if(inpTPExecuteEnablePush)
                  SendNotification("Partial TP3 executed for " + _Symbol + " Ticket: " + IntegerToString(ticket));

               if(inpTPExecuteEnableEmail)
               {
                  string subject = "MT5 Alert: Partial TP3 Executed - " + _Symbol;
                  string body = "Partial Take Profit 3 executed!\n\n" +
                               "Symbol: " + _Symbol + "\n" +
                               "Ticket: " + IntegerToString(ticket) + "\n" +
                               "TP3 Price: " + DoubleToString(calc.partialTP3Price, _Digits) + "\n" +
                               "Closed: " + DoubleToString(remainingPercent, 1) + "% (Remaining)\n" +
                               "Time: " + TimeToString(TimeCurrent(), TIME_DATE | TIME_SECONDS);
                  SendMail(subject, body);
               }
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   //--- Recalculate on every tick
   CalculateRisk();
   ExtDialog.UpdateDisplay(g_IdealCalc, IsTradeManagementMode());
   UpdateLines();
   DrawActualOrderLines();  // Draw entry and BE lines for placed orders
   ManageCandleCloseExecution();  // Execute orders on candle close

   // Pre-TP1 SL management: Trim SL as price approaches TP1
   if(inpUsePercentageSLManagement)
   {
      ManagePercentageBasedSLTrim();  // Percentage-based trimming (e.g., 50% → trim 25%)
   }

   // Post-TP trailing: Move SL to previous TP levels after TPs are hit
   if(inpTrailSLToNextTP)
   {
      ManageTrailingStop();           // TP1 hit → BE, TP2 hit → TP1 price, etc.
   }

   ManageStopLossExecution();
   ManagePendingOrderExecution();  // Execute orders when pending line is touched
   ManagePartialTPExecution();

   //--- Pending Order Line visibility management
   if(inpUsePendingOrderLine)
   {
      // Hide line if position exists, show if no position
      bool hasPosition = IsTradeManagementMode();
      if(hasPosition && g_PendingOrderActive)
      {
         // Hide the line when a trade is active
         DeletePendingOrderLine();
         Print("ℹ Pending Order Line hidden - active trade detected");
      }
      else if(!hasPosition && !g_PendingOrderActive && g_PendingOrderPrice > 0)
      {
         // Restore the line after trade closes
         CreatePendingOrderLine(g_PendingOrderPrice);
         Print("ℹ Pending Order Line restored");
      }
   }

   //--- Supertrend management (if enabled)
   if(inpUseSupertrendOnLastLevel)
   {
      CalculateSupertrend();

      // Clean up closed positions from managed array
      CleanupClosedSupertrendPositions();

      // Check for positions that need immediate Supertrend management
      CheckPositionsForSupertrendManagement();

      // Check for new bar formation (closed candle) before checking reversal signals
      // Only check reversals when actively managing positions
      datetime currentBarTime = iTime(_Symbol, PERIOD_CURRENT, 0);
      bool isNewBar = (currentBarTime != g_SupertrendLastBarTime);

      if(isNewBar)
      {
         // Only check reversals when managing positions
         if(ArraySize(g_SupertrendManagedPositions) > 0)
         {
            CheckSupertrendReversal();  // Check BUY/SELL signals only when managing positions
         }
         g_SupertrendLastBarTime = currentBarTime;  // Always update to prevent repeated checks
      }

      // Apply Supertrend trailing (Broker-Based) if in that mode
      if(inpSupertrendTrailingStop)
      {
         ProcessSupertrendTrailing();
      }

      // Draw Supertrend line only if actively managing positions
      if(inpShowSupertrendLine && ArraySize(g_SupertrendManagedPositions) > 0)
         DrawSupertrendLine();
      else
         DeleteSupertrendLines();  // Hide line when not managing any positions
   }
}

//+------------------------------------------------------------------+
//| Timer function                                                    |
//+------------------------------------------------------------------+
void OnTimer()
{
   //--- Check for settings file changes
   CheckAndReloadSettings();

   //--- Update draggable display
   ExtDialog.UpdateDisplay(g_IdealCalc, IsTradeManagementMode());
}

//+------------------------------------------------------------------+
//| Trade function - Monitor position closes for email alerts        |
//+------------------------------------------------------------------+
void OnTrade()
{
   // Request history for the last 24 hours
   datetime timeFrom = TimeCurrent() - 86400;  // 24 hours ago
   datetime timeTo = TimeCurrent();

   if(!HistorySelect(timeFrom, timeTo))
      return;

   int totalDeals = HistoryDealsTotal();

   // Check the most recent deals (process backwards to get latest first)
   for(int i = totalDeals - 1; i >= 0; i--)
   {
      ulong dealTicket = HistoryDealGetTicket(i);
      if(dealTicket == 0)
         continue;

      // Skip if we've already processed this deal
      if(dealTicket <= g_LastClosedDeal)
         break;

      // Only process deals for this symbol
      if(HistoryDealGetString(dealTicket, DEAL_SYMBOL) != _Symbol)
         continue;

      // Only process position closures (OUT deals)
      ENUM_DEAL_ENTRY dealEntry = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(dealTicket, DEAL_ENTRY);
      if(dealEntry != DEAL_ENTRY_OUT)
         continue;

      // Update last processed deal
      g_LastClosedDeal = dealTicket;

      // Get deal information
      ulong positionTicket = HistoryDealGetInteger(dealTicket, DEAL_POSITION_ID);
      double profit = HistoryDealGetDouble(dealTicket, DEAL_PROFIT);
      double volume = HistoryDealGetDouble(dealTicket, DEAL_VOLUME);
      double price = HistoryDealGetDouble(dealTicket, DEAL_PRICE);
      ENUM_DEAL_REASON dealReason = (ENUM_DEAL_REASON)HistoryDealGetInteger(dealTicket, DEAL_REASON);
      string symbol = HistoryDealGetString(dealTicket, DEAL_SYMBOL);
      datetime dealTime = (datetime)HistoryDealGetInteger(dealTicket, DEAL_TIME);

      // Check if this was our active position
      if(positionTicket == g_ActivePositionTicket)
      {
         // Verify if position still exists (distinguish partial close from full close)
         if(!PositionSelectByTicket(g_ActivePositionTicket))
         {
            // Position fully closed - remove Active SL line
            Print("Active position fully closed (volume: ", DoubleToString(volume, 2), " lots) - removing Active SL line");
            DeleteActiveSLLine();
         }
         else
         {
            // Position still exists (partial close) - keep Active SL line
            double remainingVolume = PositionGetDouble(POSITION_VOLUME);
            Print("Partial close detected (closed: ", DoubleToString(volume, 2),
                  " lots, remaining: ", DoubleToString(remainingVolume, 2),
                  " lots) - keeping Active SL line");
         }
      }

      // Note: Email alerts for TP/SL hits are now handled by auto-execution functions
      // (ManageStopLossExecution, ManagePartialTPExecution)
   }
}

//+------------------------------------------------------------------+
//| ChartEvent function                                              |
//+------------------------------------------------------------------+
void OnChartEvent(const int id,
                  const long &lparam,
                  const double &dparam,
                  const string &sparam)
{
   //--- Delegate all events to dialog (handles dragging automatically)
   ExtDialog.ChartEvent(id, lparam, dparam, sparam);

   //--- Check for dialog button requests and execute trades
   if(ExtDialog.IsBuyRequested())
   {
      ExtDialog.ClearBuyRequest();

      // Check if Execute on Candle Close is enabled
      if(inpExecuteOnCandleClose)
      {
         // Check if BUY order already queued - if so, cancel it
         if(g_CandleCloseOrderQueued && g_QueuedOrderIsBuy)
         {
            g_CandleCloseOrderQueued = false;
            Print("BUY order cancelled");
            Comment("BUY order cancelled");
         }
         else
         {
            QueueOrderForCandleClose(true);  // Queue BUY order
         }
      }
      else
         ExecuteBuyOrder();  // Execute immediately
   }

   if(ExtDialog.IsSellRequested())
   {
      ExtDialog.ClearSellRequest();

      // Check if Execute on Candle Close is enabled
      if(inpExecuteOnCandleClose)
      {
         // Check if SELL order already queued - if so, cancel it
         if(g_CandleCloseOrderQueued && !g_QueuedOrderIsBuy)
         {
            g_CandleCloseOrderQueued = false;
            Print("SELL order cancelled");
            Comment("SELL order cancelled");
         }
         else
         {
            QueueOrderForCandleClose(false);  // Queue SELL order
         }
      }
      else
         ExecuteSellOrder();  // Execute immediately
   }

   if(ExtDialog.IsBreakevenRequested())
   {
      ExtDialog.ClearBreakevenRequest();
      MoveSLToBreakEven();
   }

   if(ExtDialog.IsCloseAllRequested())
   {
      ExtDialog.ClearCloseAllRequest();
      CloseAllTrades();
   }

   //--- Legacy button handling (replaced by dialog events)
   // Legacy button code is now handled by ExtDialog.ChartEvent() above

   //--- Detect when lines are dragged (Dynamic mode)
   if(id == CHARTEVENT_OBJECT_DRAG)
   {
      // SL Line dragged (Dynamic or Hybrid mode)
      if(sparam == g_SLLineName && (inpSLMode == SL_DYNAMIC || inpSLMode == SL_HYBRID))
      {
         double newPrice = ObjectGetDouble(0, g_SLLineName, OBJPROP_PRICE, 0);

         // Normalize to tick size
         double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
         newPrice = NormalizeDouble(MathRound(newPrice / tickSize) * tickSize, g_Digits);

         // Update the line to normalized price
         datetime currentTime = TimeCurrent();
         datetime futureTime = currentTime + PeriodSeconds(PERIOD_CURRENT) * 100;
         ObjectMove(0, g_SLLineName, 0, currentTime, newPrice);
         ObjectMove(0, g_SLLineName, 1, futureTime, newPrice);

         // Save to global variable for file sync
         g_DynamicSLPrice = newPrice;

         // Recalculate risk with new SL
         CalculateRisk();
         ExtDialog.UpdateDisplay(g_IdealCalc, IsTradeManagementMode());

         // IMMEDIATE label update (fixes 3-second lag)
         RiskCalculation calc = (inpDisplayMode == DISPLAY_CONSERVATIVE) ? g_ConservativeCalc : g_IdealCalc;
         double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         double slPips = MathAbs(currentPrice - calc.slPrice) / g_PipValue;
         string slLabel = "SL: " + DoubleToString(slPips, 1) + " pips";
         UpdateLabelPosition(g_SLLabelName, calc.slPrice, slLabel);

         // Auto-save global variables
         if(inpExportDirectory != "")
            SaveSettingsToFile();

         Print("OK SL dragged to: ", DoubleToString(calc.slPrice, g_Digits), " (", DoubleToString(slPips, 1), " pips)");
      }
      // Partial TP1 Line dragged
      else if(sparam == g_PartialTP1LineName)
      {
         double oldTP1Price = g_PartialTP1Price;  // Store old TP1 price
         double newPrice = ObjectGetDouble(0, g_PartialTP1LineName, OBJPROP_PRICE, 0);

         // Normalize to tick size
         double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
         newPrice = NormalizeDouble(MathRound(newPrice / tickSize) * tickSize, g_Digits);

         // Update the line to normalized price
         datetime currentTime = TimeCurrent();
         datetime futureTime = currentTime + PeriodSeconds(PERIOD_CURRENT) * 100;
         ObjectMove(0, g_PartialTP1LineName, 0, currentTime, newPrice);
         ObjectMove(0, g_PartialTP1LineName, 1, futureTime, newPrice);

         // Detect if trade direction changed (TP1 crossed current price)
         double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         bool oldIsLong = (oldTP1Price > currentPrice);
         bool newIsLong = (newPrice > currentPrice);

         // If direction changed, relocate TP2 and TP3 to follow TP1
         if(oldIsLong != newIsLong && oldTP1Price > 0)
         {
            // Calculate distances between TP levels (in pips)
            double tp1_tp2_distance = 0;
            double tp1_tp3_distance = 0;

            if(g_PartialTP2Price > 0)
            {
               tp1_tp2_distance = MathAbs(g_PartialTP2Price - oldTP1Price);
            }

            if(g_PartialTP3Price > 0 && inpNumberOfLevels == 3)
            {
               tp1_tp3_distance = MathAbs(g_PartialTP3Price - oldTP1Price);
            }

            // Relocate TP2 and TP3 to same side as new TP1, maintaining distances
            if(newIsLong)
            {
               // LONG: TP levels should be above entry (above current price)
               if(g_PartialTP2Price > 0)
               {
                  g_PartialTP2Price = newPrice + tp1_tp2_distance;
                  g_PartialTP2Price = NormalizeDouble(MathRound(g_PartialTP2Price / tickSize) * tickSize, g_Digits);
               }

               if(g_PartialTP3Price > 0 && inpNumberOfLevels == 3)
               {
                  g_PartialTP3Price = newPrice + tp1_tp3_distance;
                  g_PartialTP3Price = NormalizeDouble(MathRound(g_PartialTP3Price / tickSize) * tickSize, g_Digits);
               }
            }
            else
            {
               // SHORT: TP levels should be below entry (below current price)
               if(g_PartialTP2Price > 0)
               {
                  g_PartialTP2Price = newPrice - tp1_tp2_distance;
                  g_PartialTP2Price = NormalizeDouble(MathRound(g_PartialTP2Price / tickSize) * tickSize, g_Digits);
               }

               if(g_PartialTP3Price > 0 && inpNumberOfLevels == 3)
               {
                  g_PartialTP3Price = newPrice - tp1_tp3_distance;
                  g_PartialTP3Price = NormalizeDouble(MathRound(g_PartialTP3Price / tickSize) * tickSize, g_Digits);
               }
            }

            Print("Direction changed - TP levels relocated to ", newIsLong ? "LONG" : "SHORT", " side");
         }

         // Save to global variable for file sync
         g_PartialTP1Price = newPrice;

         // Recalculate risk with new TP1 (and potentially new TP2/TP3)
         CalculateRisk();
         ExtDialog.UpdateDisplay(g_IdealCalc, IsTradeManagementMode());

         // IMMEDIATE label update (fixes 3-second lag)
         RiskCalculation calc = (inpDisplayMode == DISPLAY_CONSERVATIVE) ? g_ConservativeCalc : g_IdealCalc;

         // Calculate RR using actual gross profit from partial position
         double rr1 = (calc.totalRisk > 0) ? (calc.partialGrossPnL1 / calc.totalRisk) : 0;

         string tp1Label = "TP1: " + DoubleToString(GetActiveExitPercent1(), 0) + "% (" + DoubleToString(calc.partialLots1, 2) + " lots) @ " + DoubleToString(calc.partialPips1, 1) + " pips";
         if(inpShowRR && rr1 > 0) tp1Label += " | RR: " + DoubleToString(rr1, 2);
         UpdateLabelPosition(g_PartialTP1LabelName, calc.partialTP1Price, tp1Label);

         // Auto-save global variables
         if(inpExportDirectory != "")
            SaveSettingsToFile();

         Print("OK TP1 dragged to: ", DoubleToString(calc.partialTP1Price, g_Digits), " (", DoubleToString(calc.partialPips1, 1), " pips, RR: ", DoubleToString(rr1, 2), ")");
      }
      // Partial TP2 Line dragged
      else if(sparam == g_PartialTP2LineName)
      {
         double newPrice = ObjectGetDouble(0, g_PartialTP2LineName, OBJPROP_PRICE, 0);

         // Normalize to tick size
         double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
         newPrice = NormalizeDouble(MathRound(newPrice / tickSize) * tickSize, g_Digits);

         // Update the line to normalized price
         datetime currentTime = TimeCurrent();
         datetime futureTime = currentTime + PeriodSeconds(PERIOD_CURRENT) * 100;
         ObjectMove(0, g_PartialTP2LineName, 0, currentTime, newPrice);
         ObjectMove(0, g_PartialTP2LineName, 1, futureTime, newPrice);

         // Save to global variable for file sync
         g_PartialTP2Price = newPrice;

         // Recalculate risk with new TP2
         CalculateRisk();
         ExtDialog.UpdateDisplay(g_IdealCalc, IsTradeManagementMode());

         // IMMEDIATE label update (fixes 3-second lag)
         RiskCalculation calc = (inpDisplayMode == DISPLAY_CONSERVATIVE) ? g_ConservativeCalc : g_IdealCalc;

         // Calculate RR using actual gross profit from partial position
         double rr2 = (calc.totalRisk > 0) ? (calc.partialGrossPnL2 / calc.totalRisk) : 0;
         string tp2Label = "TP2: " + DoubleToString(GetActiveExitPercent2(), 0) + "% (" + DoubleToString(calc.partialLots2, 2) + " lots) @ " + DoubleToString(calc.partialPips2, 1) + " pips";
         if(inpShowRR && rr2 > 0) tp2Label += " | RR: " + DoubleToString(rr2, 2);
         UpdateLabelPosition(g_PartialTP2LabelName, calc.partialTP2Price, tp2Label);

         // Auto-save global variables
         if(inpExportDirectory != "")
            SaveSettingsToFile();

         Print("OK TP2 dragged to: ", DoubleToString(calc.partialTP2Price, g_Digits), " (", DoubleToString(calc.partialPips2, 1), " pips, RR: ", DoubleToString(rr2, 2), ")");
      }
      // Partial TP3 Line dragged
      else if(sparam == g_PartialTP3LineName && inpNumberOfLevels == 3)
      {
         double newPrice = ObjectGetDouble(0, g_PartialTP3LineName, OBJPROP_PRICE, 0);

         // Normalize to tick size
         double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
         newPrice = NormalizeDouble(MathRound(newPrice / tickSize) * tickSize, g_Digits);

         // Update the line to normalized price
         datetime currentTime = TimeCurrent();
         datetime futureTime = currentTime + PeriodSeconds(PERIOD_CURRENT) * 100;
         ObjectMove(0, g_PartialTP3LineName, 0, currentTime, newPrice);
         ObjectMove(0, g_PartialTP3LineName, 1, futureTime, newPrice);

         // Save to global variable for file sync
         g_PartialTP3Price = newPrice;

         // Recalculate risk with new TP3
         CalculateRisk();
         ExtDialog.UpdateDisplay(g_IdealCalc, IsTradeManagementMode());

         // IMMEDIATE label update (fixes 3-second lag)
         RiskCalculation calc = (inpDisplayMode == DISPLAY_CONSERVATIVE) ? g_ConservativeCalc : g_IdealCalc;
         double exitPercent3 = 100 - GetActiveExitPercent1() - GetActiveExitPercent2();

         // Calculate RR using actual gross profit from partial position
         double rr3 = (calc.totalRisk > 0) ? (calc.partialGrossPnL3 / calc.totalRisk) : 0;
         string tp3Label = "TP3: " + DoubleToString(exitPercent3, 0) + "% (" + DoubleToString(calc.partialLots3, 2) + " lots) @ " + DoubleToString(calc.partialPips3, 1) + " pips";
         if(inpShowRR && rr3 > 0) tp3Label += " | RR: " + DoubleToString(rr3, 2);
         UpdateLabelPosition(g_PartialTP3LabelName, calc.partialTP3Price, tp3Label);

         // Auto-save global variables
         if(inpExportDirectory != "")
            SaveSettingsToFile();

         Print("OK TP3 dragged to: ", DoubleToString(calc.partialTP3Price, g_Digits), " (", DoubleToString(calc.partialPips3, 1), " pips, RR: ", DoubleToString(rr3, 2), ")");
      }
      // Active SL Line dragged (user manual trailing)
      else if(sparam == g_ActiveSLLineName && g_ActivePositionTicket > 0)
      {
         double newPrice = ObjectGetDouble(0, g_ActiveSLLineName, OBJPROP_PRICE, 0);

         // Normalize to tick size
         double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
         newPrice = NormalizeDouble(MathRound(newPrice / tickSize) * tickSize, g_Digits);

         // Update the line to normalized price
         datetime currentTime = TimeCurrent();
         datetime futureTime = currentTime + PeriodSeconds(PERIOD_CURRENT) * 100;
         ObjectMove(0, g_ActiveSLLineName, 0, currentTime, newPrice);
         ObjectMove(0, g_ActiveSLLineName, 1, futureTime, newPrice);

         // Update global Active SL price
         g_ActiveSLPrice = newPrice;

         // Update line label
         UpdateLabelPosition(g_ActiveSLLabelName, g_ActiveSLPrice, "Active SL");

         // Auto-save global variables (sync to file for multi-instance)
         if(inpExportDirectory != "")
            SaveSettingsToFile();

         Print("OK Active SL dragged to: ", DoubleToString(newPrice, g_Digits));
      }
      // Pending Order Line dragged
      else if(sparam == g_PendingOrderLineName && inpUsePendingOrderLine)
      {
         double newPrice = ObjectGetDouble(0, g_PendingOrderLineName, OBJPROP_PRICE, 0);

         // Normalize to tick size
         double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
         newPrice = NormalizeDouble(MathRound(newPrice / tickSize) * tickSize, g_Digits);

         // Update the line price (HLINE updates automatically)
         ObjectSetDouble(0, g_PendingOrderLineName, OBJPROP_PRICE, newPrice);

         // Update global pending order price
         g_PendingOrderPrice = newPrice;

         // Re-create the line to update label with correct direction
         CreatePendingOrderLine(newPrice);

         Print("OK Pending Order Line dragged to: ", DoubleToString(newPrice, g_Digits));
      }
   }
}

//+------------------------------------------------------------------+
//| Calculate Risk in Management Mode (Using Actual Position Data)   |
//+------------------------------------------------------------------+
void CalculateRiskManagementMode()
{
   // Find the position for this symbol
   for(int i = 0; i < PositionsTotal(); i++)
   {
      if(PositionGetSymbol(i) != _Symbol)
         continue;

      // Get actual position data
      double actualLotSize = PositionGetDouble(POSITION_VOLUME);
      double actualEntry = PositionGetDouble(POSITION_PRICE_OPEN);
      double actualSL = PositionGetDouble(POSITION_SL);
      ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      string comment = PositionGetString(POSITION_COMMENT);
      bool isLongTrade = (posType == POSITION_TYPE_BUY);

      // Get current price for P/L calculation
      double currentPrice = isLongTrade ? SymbolInfoDouble(_Symbol, SYMBOL_BID) : SymbolInfoDouble(_Symbol, SYMBOL_ASK);

      // Calculate pip value
      double pipValuePerLot = (inpPipValueMode == PIP_MANUAL) ? inpManualPipValue : (g_PointValue * (g_PipValue / g_Point));

      // Get locked BE pips from comment
      double actualBEPips = 0;
      int bePos = StringFind(comment, "|BE:");
      if(bePos >= 0)
      {
         string beStr = StringSubstr(comment, bePos + 4);
         actualBEPips = StringToDouble(beStr);
      }
      else
      {
         // Fallback
         actualBEPips = CalculateBEPipsForOrder(actualLotSize);
      }

      // Calculate SL distance from actual entry to actual SL (or Active SL if managed by EA)
      double effectiveSL = (inpAutoExecuteSL && g_ActiveSLPrice > 0) ? g_ActiveSLPrice : actualSL;
      double slPips = (effectiveSL > 0) ? MathAbs(actualEntry - effectiveSL) / g_PipValue : 0;

      // Build IDEAL calculation (Management Mode is always IDEAL - no entry slippage)
      // Work directly with g_IdealCalc (MQL5 doesn't support references like C++)
      g_IdealCalc.entryPrice = actualEntry;
      g_IdealCalc.slPrice = effectiveSL;
      g_IdealCalc.slPips = slPips;
      g_IdealCalc.lotSize = actualLotSize;

      // Calculate price risk (SL distance in dollars)
      g_IdealCalc.priceRisk = actualLotSize * slPips * pipValuePerLot;

      // Commission (locked at execution)
      g_IdealCalc.commission = actualLotSize * inpCommissionPerLot;

      // Use locked spread from BE calculation (spread already accounted for in BE pips)
      // Spread cost = (BE pips - commission/pipValue) * pipValue * lotSize
      double commissionInPips = (pipValuePerLot > 0) ? (g_IdealCalc.commission / (actualLotSize * pipValuePerLot)) : 0;
      double spreadPips = actualBEPips - commissionInPips - inpBEOffsetPips;
      if(spreadPips < 0) spreadPips = 0;
      g_IdealCalc.spreadCost = spreadPips * pipValuePerLot * actualLotSize;

      // Total risk
      g_IdealCalc.totalRisk = g_IdealCalc.priceRisk + g_IdealCalc.commission + g_IdealCalc.spreadCost;

      // Risk percentage
      double effectiveAccountSize = GetEffectiveAccountSize();
      g_IdealCalc.riskPercent = (effectiveAccountSize > 0) ? (g_IdealCalc.totalRisk / effectiveAccountSize * 100.0) : 0;

      // Break-even (locked from execution)
      g_IdealCalc.breakEvenPips = actualBEPips;

      // Current P/L (real-time from broker)
      g_IdealCalc.currentPnL = PositionGetDouble(POSITION_PROFIT);

      // Margin
      g_IdealCalc.marginRequired = actualLotSize * SymbolInfoDouble(_Symbol, SYMBOL_MARGIN_INITIAL);

      // Calculate TP levels using locked TP prices and partial lots
      CalculatePartialExits(g_IdealCalc, pipValuePerLot, isLongTrade);

      // Copy to Conservative (same in management mode)
      g_ConservativeCalc = g_IdealCalc;

      break;  // Only one position per symbol on netting account
   }
}

//+------------------------------------------------------------------+
//| Read Dynamic Risk Data from RiskManager CSV File                 |
//+------------------------------------------------------------------+
bool ReadRiskFromFile(DynamicRiskData &riskData) {
    // Check cache - only read file based on user-configured cache duration
    if(inpRiskFileCacheSeconds > 0 &&
       TimeCurrent() - g_LastRiskFileCheck < inpRiskFileCacheSeconds &&
       riskData.fileReadSuccess) {
        return true;  // Use cached data
    }

    g_LastRiskFileCheck = TimeCurrent();

    int fileHandle = FileOpen(g_RiskFileName, FILE_READ | FILE_CSV | FILE_ANSI);
    if(fileHandle == INVALID_HANDLE) {
        riskData.fileReadSuccess = false;
        return false;
    }

    // Read CSV format: "riskPercent,lastUpdate,timestamp"
    if(!FileIsEnding(fileHandle)) {
        string line = FileReadString(fileHandle);
        FileClose(fileHandle);

        string fields[];
        int fieldCount = StringSplit(line, ',', fields);

        if(fieldCount >= 3) {
            riskData.currentRiskPercent = StringToDouble(fields[0]);
            riskData.lastUpdate = StringToTime(fields[1]);
            riskData.fileReadSuccess = true;
            riskData.lastReadTime = TimeCurrent();
            return true;
        }
    }

    FileClose(fileHandle);
    riskData.fileReadSuccess = false;
    return false;
}

//+------------------------------------------------------------------+
//| Show Popup Notification for Specific Error Types                  |
//+------------------------------------------------------------------+
void ShowRiskErrorPopup(string errorType, string details) {
    // Per-error-type throttling to allow different errors to show up
    static datetime lastFileNotFoundPopup = 0;
    static datetime lastFileCorruptionPopup = 0;
    static datetime lastInvalidRiskPopup = 0;
    static datetime lastAccountEquityPopup = 0;

    datetime lastPopup = 0;

    // Select the appropriate timer based on error type
    if(errorType == "File Not Found") {
        lastPopup = lastFileNotFoundPopup;
    }
    else if(errorType == "File Corruption") {
        lastPopup = lastFileCorruptionPopup;
    }
    else if(errorType == "Invalid Risk Range") {
        lastPopup = lastInvalidRiskPopup;
    }
    else if(errorType == "Account Equity Failure") {
        lastPopup = lastAccountEquityPopup;
    }

    // Show popup only once per hour per error type to avoid spam
    if(TimeCurrent() - lastPopup < 3600) return;

    string title = "RiskManager Error - " + errorType;
    string message = "";

    if(errorType == "File Not Found") {
        message = "RISKMANAGER FILE NOT FOUND\n\n";
        message += "Dynamic Risk is enabled but the RiskManager file cannot be found.\n\n";
        message += "File: " + g_RiskFileName + "\n\n";
        message += "Falling back to Manual Risk: " + DoubleToString(inpManualRiskPercent, 2) + "%\n\n";
        message += "Solutions:\n";
        message += "1. Ensure RiskManager indicator is running on your chart\n";
        message += "2. Check that MQL5/Files/RiskManager/ directory exists\n";
        message += "3. Verify file permissions\n";
        message += "4. Restart the RiskManager indicator";
    }
    else if(errorType == "File Corruption") {
        message = "RISKMANAGER FILE CORRUPTION\n\n";
        message += "The RiskManager file exists but appears to be corrupted.\n\n";
        message += "Details: " + details + "\n\n";
        message += "Falling back to Manual Risk: " + DoubleToString(inpManualRiskPercent, 2) + "%\n\n";
        message += "Solutions:\n";
        message += "1. Restart the RiskManager indicator\n";
        message += "2. Check for disk errors or file system issues\n";
        message += "3. Ensure no other programs are modifying the file";
    }
    else if(errorType == "Invalid Risk Range") {
        message = "INVALID RISK PERCENTAGE\n\n";
        message += "RiskManager provided an invalid risk percentage value.\n\n";
        message += "Invalid Risk%: " + details + "\n";
        message += "Valid Range: 0.01% to 10.0%\n\n";
        message += "Falling back to Manual Risk: " + DoubleToString(inpManualRiskPercent, 2) + "%\n\n";
        message += "Solutions:\n";
        message += "1. Restart the RiskManager indicator\n";
        message += "2. Check RiskManager indicator settings\n";
        message += "3. Verify RiskManager calculations are working correctly";
    }
    else if(errorType == "Account Equity Failure") {
        message = "ACCOUNT EQUITY ERROR\n\n";
        message += "Failed to retrieve real-time account equity from MT5.\n\n";
        message += "Error Details: " + details + "\n\n";
        message += "Falling back to Manual Account Size: $" + DoubleToString(inpManualAccountSize, 2) + "\n\n";
        message += "Solutions:\n";
        message += "1. Check MT5 connection to broker\n";
        message += "2. Verify account is properly connected\n";
        message += "3. Restart MT5 terminal\n";
        message += "4. Contact broker if issue persists";
    }

    // Show Alert notification only
    Alert(title + "\n" + message);

    // Update the appropriate timer based on error type
    if(errorType == "File Not Found") {
        lastFileNotFoundPopup = TimeCurrent();
    }
    else if(errorType == "File Corruption") {
        lastFileCorruptionPopup = TimeCurrent();
    }
    else if(errorType == "Invalid Risk Range") {
        lastInvalidRiskPopup = TimeCurrent();
    }
    else if(errorType == "Account Equity Failure") {
        lastAccountEquityPopup = TimeCurrent();
    }
}

//+------------------------------------------------------------------+
//| Validate Risk Data is Within Bounds (Stale Data Check Removed)    |
//+------------------------------------------------------------------+
bool ValidateRiskData(const DynamicRiskData &riskData) {
    if(!riskData.fileReadSuccess) return false;

    // STALE DATA CHECK REMOVED - RiskManager updates constantly

    // Validate risk% is within reasonable bounds (0.01% to 10%)
    if(riskData.currentRiskPercent < 0.01 || riskData.currentRiskPercent > 10.0) {
        Print("⚠️ Invalid risk% from RiskManager: ", riskData.currentRiskPercent);
        return false;
    }

    return true;
}

//+------------------------------------------------------------------+
//| Show Dialog When RiskManager Data is Unavailable                 |
//+------------------------------------------------------------------+
void ShowRiskDataErrorDialog() {
    static datetime lastWarning = 0;

    // Show warning only once per hour to avoid spam
    if(TimeCurrent() - lastWarning < 3600) return;

    string message = "⚠️ RISK MANAGER DATA UNAVAILABLE\n\n";
    message += "Dynamic Risk is enabled but RiskManager file cannot be read.\n";
    message += "Falling back to Manual Risk: " + DoubleToString(inpManualRiskPercent, 2) + "%\n\n";
    message += "File: " + g_RiskFileName + "\n\n";
    message += "Solutions:\n";
    message += "1. Ensure RiskManager indicator is running\n";
    message += "2. Check file permissions\n";
    message += "3. Disable Dynamic Risk in EA settings\n";

    Alert(message);
    lastWarning = TimeCurrent();
}

//+------------------------------------------------------------------+
//| Enhanced Get Effective Risk Percent with Specific Error Handling   |
//+------------------------------------------------------------------+
double GetEffectiveRiskPercent() {
    if(!inpUseDynamicRisk) {
        return inpManualRiskPercent;  // Manual mode
    }

    // Attempt to read dynamic risk
    if(ReadRiskFromFile(g_DynamicRisk) && ValidateRiskData(g_DynamicRisk)) {
        return g_DynamicRisk.currentRiskPercent;
    }

    // Determine specific error type and show appropriate popup
    if(!g_DynamicRisk.fileReadSuccess) {
        // Try to determine specific error
        int fileHandle = FileOpen(g_RiskFileName, FILE_READ | FILE_CSV | FILE_ANSI);
        if(fileHandle == INVALID_HANDLE) {
            // File not found or permission error
            ShowRiskErrorPopup("File Not Found", "");
        } else {
            // File exists but couldn't be read properly
            FileClose(fileHandle);
            ShowRiskErrorPopup("File Corruption", "File exists but reading failed");
        }
    } else {
        // File read succeeded but validation failed
        ShowRiskErrorPopup("Invalid Risk Range", DoubleToString(g_DynamicRisk.currentRiskPercent, 6));
    }

    // Fallback to manual if dynamic fails
    Print("⚠️ RiskManager unavailable - using manual risk: ", inpManualRiskPercent, "%");
    return inpManualRiskPercent;
}

//+------------------------------------------------------------------+
//| Enhanced Get Effective Account Size with Error Handling           |
//+------------------------------------------------------------------+
double GetEffectiveAccountSize() {
    if(inpUseDynamicAccountSize) {
        double equity = AccountInfoDouble(ACCOUNT_EQUITY);
        if(equity > 0) {
            return equity;
        } else {
            // Account equity retrieval failed
            string errorDetails = (equity == 0) ? "Equity returned 0" : "Equity returned negative value: " + DoubleToString(equity, 2);
            ShowRiskErrorPopup("Account Equity Failure", errorDetails);
            Print("⚠️ Failed to get account equity - using manual: ", inpManualAccountSize);
        }
    }
    return inpManualAccountSize;
}

//+------------------------------------------------------------------+
//| Calculate Risk and Lot Sizes                                     |
//+------------------------------------------------------------------+
void CalculateRisk()
{
   // Check if in Trade Management Mode (active position exists)
   bool isManagementMode = IsTradeManagementMode();

   if(isManagementMode)
   {
      // TRADE MANAGEMENT MODE: Use actual position data
      CalculateRiskManagementMode();
      return;
   }

   // PLANNING MODE: Calculate based on current price
   // Use close[0] logic from price-line.mq5 for entry line display
   double currentPrice = iClose(_Symbol, PERIOD_CURRENT, 0);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);

   //--- Determine SL distance in pips
   double slPips = 0;
   double slPrice = 0;
   bool isLongTrade = true;  // Determine trade direction
   
   if(inpSLMode == SL_MANUAL)
   {
      slPips = inpManualSLPips;

      // Auto-detect trade direction based on TP line position
      if(inpTradeDirection == TRADE_AUTO)
      {
         // Use TP1 position to determine direction
         if(g_PartialTP1Price > 0)
         {
            // If TP is above current price = Long, if below = Short
            isLongTrade = (g_PartialTP1Price > currentPrice);
         }
         else
         {
            // Default to Long if no TP set yet
            isLongTrade = true;
         }
      }
      else
      {
         isLongTrade = (inpTradeDirection == TRADE_BUY);
      }

      if(isLongTrade)
         slPrice = currentPrice - (slPips * g_PipValue);
      else
         slPrice = currentPrice + (slPips * g_PipValue);
   }
   else if(inpSLMode == SL_DYNAMIC)
   {
      // Auto-detect trade direction based on TP line position (consistent with other modes)
      if(inpTradeDirection == TRADE_AUTO)
      {
         // Use TP1 position to determine direction
         if(g_PartialTP1Price > 0)
         {
            // If TP is above current price = Long, if below = Short
            isLongTrade = (g_PartialTP1Price > currentPrice);
         }
         else
         {
            // Default to Long if no TP set yet
            isLongTrade = true;
         }
      }
      else
      {
         isLongTrade = (inpTradeDirection == TRADE_BUY);
      }

      // Use g_DynamicSLPrice if set, otherwise use manual SL pips as default
      if(g_DynamicSLPrice > 0)
      {
         slPrice = g_DynamicSLPrice;
         slPips = MathAbs(currentPrice - slPrice) / g_PipValue;
      }
      else
      {
         // Default: use manual SL pips distance (line will be created and user can drag it)
         slPips = inpManualSLPips;
         if(isLongTrade)
            slPrice = currentPrice - (slPips * g_PipValue);
         else
            slPrice = currentPrice + (slPips * g_PipValue);
      }
   }
   else // SL_HYBRID
   {
      slPips = inpManualSLPips;

      // Auto-detect trade direction based on TP line position
      if(inpTradeDirection == TRADE_AUTO)
      {
         if(g_PartialTP1Price > 0)
         {
            isLongTrade = (g_PartialTP1Price > currentPrice);
         }
         else
         {
            isLongTrade = true;
         }
      }
      else
      {
         isLongTrade = (inpTradeDirection == TRADE_BUY);
      }

      // Calculate reference SL (like manual mode)
      double referenceSL;
      if(isLongTrade)
         referenceSL = currentPrice - (slPips * g_PipValue);
      else
         referenceSL = currentPrice + (slPips * g_PipValue);

      g_ReferenceSLPrice = referenceSL;  // Store for display

      // Use dynamic SL for actual trading if set, otherwise use reference SL
      if(g_DynamicSLPrice > 0)
      {
         slPrice = g_DynamicSLPrice;
         slPips = MathAbs(currentPrice - slPrice) / g_PipValue;
      }
      else
      {
         // Default to reference SL
         slPrice = referenceSL;
      }
   }

   //--- Calculate Exit Slippage based on mode
   double exitSlippagePips;
   double spreadCostPips;

   if(inpExitSlippageMode == EXIT_SLIPPAGE_SPREAD_BASED)
   {
      // Spread-Based Mode: Real spread + user's slippage buffer
      spreadCostPips = GetCurrentSpreadPips();
      exitSlippagePips = inpExitSlippage;  // User's additional slippage buffer
   }
   else
   {
      // Manual Mode: User combines spread + slippage into one value
      spreadCostPips = 0;  // Not shown separately
      exitSlippagePips = inpExitSlippage;  // User's combined value
   }

   //--- IDEAL CALCULATION (No Entry Slippage)
   double idealTotalPips = slPips + spreadCostPips + exitSlippagePips;
   double effectiveRiskPercent = GetEffectiveRiskPercent();
   double effectiveAccountSize = GetEffectiveAccountSize();
   double riskAmount = effectiveAccountSize * (effectiveRiskPercent / 100.0);
   
   // Calculate pip value in USD for the lot size calculation
   double pipValuePerLot = (inpPipValueMode == PIP_MANUAL) ? inpManualPipValue : (g_PointValue * (g_PipValue / g_Point));
   
   g_IdealCalc.baseSLPips = slPips;  // Store base SL
   g_IdealCalc.slPips = slPips;
   g_IdealCalc.lotSize = riskAmount / ((idealTotalPips * pipValuePerLot) + inpCommissionPerLot);
   g_IdealCalc.commission = g_IdealCalc.lotSize * inpCommissionPerLot;
   g_IdealCalc.spreadCost = g_IdealCalc.lotSize * spreadCostPips * pipValuePerLot;
   g_IdealCalc.priceRisk = g_IdealCalc.lotSize * (slPips + exitSlippagePips) * pipValuePerLot;  // Price risk excludes spread cost
   g_IdealCalc.totalRisk = g_IdealCalc.priceRisk + g_IdealCalc.spreadCost + g_IdealCalc.commission;
   g_IdealCalc.riskPercent = (g_IdealCalc.totalRisk / effectiveAccountSize) * 100.0;
   g_IdealCalc.entryPrice = currentPrice;
   g_IdealCalc.slPrice = slPrice;
   
   // Break-even calculation
   double idealTotalFees = g_IdealCalc.commission + g_IdealCalc.spreadCost + (g_IdealCalc.lotSize * exitSlippagePips * pipValuePerLot);
   g_IdealCalc.breakEvenPips = idealTotalFees / (g_IdealCalc.lotSize * pipValuePerLot);

   // Pip distance calculation
   g_IdealCalc.dollarPerPip = g_IdealCalc.lotSize * pipValuePerLot;
   g_IdealCalc.tpPipDistance = (g_IdealCalc.dollarPerPip > 0) ? (g_IdealCalc.grossTP / g_IdealCalc.dollarPerPip) : 0;

   // Margin calculation
   double idealContractValue = g_IdealCalc.lotSize * 100000;
   double idealNotionalUSD = idealContractValue * currentPrice;
   g_IdealCalc.marginRequired = idealNotionalUSD * (inpMarginPercent / 100.0);
   g_IdealCalc.buyingPowerPercent = (g_IdealCalc.marginRequired / effectiveAccountSize) * 100.0;
   g_IdealCalc.returnOnMargin = g_IdealCalc.marginRequired > 0 ? (g_IdealCalc.netTP / g_IdealCalc.marginRequired) * 100.0 : 0;
   
   //--- CONSERVATIVE CALCULATION (With Entry Slippage)
   double effectiveSL = slPips + inpEntrySlippage;
   double conservativeTotalPips = effectiveSL + spreadCostPips + exitSlippagePips;
   
   g_ConservativeCalc.baseSLPips = slPips;  // Store base SL
   g_ConservativeCalc.slPips = effectiveSL;
   g_ConservativeCalc.lotSize = riskAmount / ((conservativeTotalPips * pipValuePerLot) + inpCommissionPerLot);
   g_ConservativeCalc.commission = g_ConservativeCalc.lotSize * inpCommissionPerLot;
   g_ConservativeCalc.spreadCost = g_ConservativeCalc.lotSize * spreadCostPips * pipValuePerLot;
   g_ConservativeCalc.priceRisk = g_ConservativeCalc.lotSize * (effectiveSL + exitSlippagePips) * pipValuePerLot;  // Price risk excludes spread cost
   g_ConservativeCalc.totalRisk = g_ConservativeCalc.priceRisk + g_ConservativeCalc.spreadCost + g_ConservativeCalc.commission;
   g_ConservativeCalc.riskPercent = (g_ConservativeCalc.totalRisk / effectiveAccountSize) * 100.0;
   // Entry price accounting for slippage based on direction
   g_ConservativeCalc.entryPrice = isLongTrade ? (currentPrice + (inpEntrySlippage * g_PipValue)) : (currentPrice - (inpEntrySlippage * g_PipValue));
   g_ConservativeCalc.slPrice = slPrice;
   
   // Break-even calculation
   double conservativeTotalFees = g_ConservativeCalc.commission + g_ConservativeCalc.spreadCost + (g_ConservativeCalc.lotSize * exitSlippagePips * pipValuePerLot);
   g_ConservativeCalc.breakEvenPips = conservativeTotalFees / (g_ConservativeCalc.lotSize * pipValuePerLot);

   // Pip distance calculation
   g_ConservativeCalc.dollarPerPip = g_ConservativeCalc.lotSize * pipValuePerLot;
   g_ConservativeCalc.tpPipDistance = (g_ConservativeCalc.dollarPerPip > 0) ? (g_ConservativeCalc.grossTP / g_ConservativeCalc.dollarPerPip) : 0;

   // Margin calculation
   double conservativeContractValue = g_ConservativeCalc.lotSize * 100000;
   double conservativeNotionalUSD = conservativeContractValue * currentPrice;
   g_ConservativeCalc.marginRequired = conservativeNotionalUSD * (inpMarginPercent / 100.0);
   g_ConservativeCalc.buyingPowerPercent = (g_ConservativeCalc.marginRequired / effectiveAccountSize) * 100.0;
   g_ConservativeCalc.returnOnMargin = g_ConservativeCalc.marginRequired > 0 ? (g_ConservativeCalc.netTP / g_ConservativeCalc.marginRequired) * 100.0 : 0;
   
   //--- PARTIAL EXITS CALCULATION
   CalculatePartialExits(g_IdealCalc, pipValuePerLot, isLongTrade);
   CalculatePartialExits(g_ConservativeCalc, pipValuePerLot, isLongTrade);

   //--- EXECUTION COST CALCULATION
   // Calculate total fees for each mode
   double idealTotalFeesForEC = g_IdealCalc.commission + g_IdealCalc.spreadCost + (g_IdealCalc.lotSize * exitSlippagePips * pipValuePerLot);
   double conservativeTotalFeesForEC = g_ConservativeCalc.commission + g_ConservativeCalc.spreadCost + (g_ConservativeCalc.lotSize * exitSlippagePips * pipValuePerLot);

   // Calculate execution cost as percentage of gross profit
   g_IdealCalc.executionCostPercent = (g_IdealCalc.grossTP > 0) ? (idealTotalFeesForEC / g_IdealCalc.grossTP) * 100.0 : 0;
   g_ConservativeCalc.executionCostPercent = (g_ConservativeCalc.grossTP > 0) ? (conservativeTotalFeesForEC / g_ConservativeCalc.grossTP) * 100.0 : 0;
}

//+------------------------------------------------------------------+
//| Calculate Panel Height (shared function)                         |
//+------------------------------------------------------------------+
int GetPanelHeight()
{
   // If manual height override is set, use it
   if(inpPanelHeight > 0)
      return inpPanelHeight;

   // Otherwise, auto-calculate based on number of levels and row height
   int baseRows = 24;
   int additionalRows = 0;

   if(inpNumberOfLevels == 3)
      additionalRows = 8;  // Partial Exits with 3 levels
   else
      additionalRows = 6;  // Partial Exits with 2 levels

   return (baseRows + additionalRows) * inpRowHeight + (inpPanelPadding * 2);
}

//+------------------------------------------------------------------+
//| Generate Divider Line (adjustable via settings)                  |
//+------------------------------------------------------------------+
string GetDivider()
{
   // Build divider string based on inpDividerLength parameter
   string divider = "";
   for(int i = 0; i < inpDividerLength; i++)
      divider += "─";

   return divider;
}

//+------------------------------------------------------------------+
//| Create Information Panel (REMOVED - Replaced by CAppDialog Framework)   |
//+------------------------------------------------------------------+
// CreatePanel() function removed - replaced by CForexTradeManagerDialog class

//+------------------------------------------------------------------+//| Update Information Panel (REMOVED - Replaced by CAppDialog Framework) |//+------------------------------------------------------------------+// UpdatePanel() function removed - replaced by CForexTradeManagerDialog::UpdateDisplay()

//+------------------------------------------------------------------+
//| Create Label Helper                                              |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+//| Create Label Helper (REMOVED - No longer needed with CAppDialog) |//+------------------------------------------------------------------+// CreateLabel() function removed - replaced by CLabel controls in dialog
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| Delete Panel (REMOVED - Replaced by CAppDialog Framework)          |
//+------------------------------------------------------------------+
// DeletePanel() function removed - replaced by ExtDialog.Destroy()

//+------------------------------------------------------------------+
//| Create Buy/Sell Buttons                                          |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+//| Create Buy/Sell Buttons (REMOVED - Replaced by CAppDialog Framework) |//+------------------------------------------------------------------+// CreateButtons() function removed - replaced by CButton controls in dialog
//+------------------------------------------------------------------+
//| Delete Buttons (REMOVED - Replaced by CAppDialog Framework)        |
//+------------------------------------------------------------------+
// DeleteButtons() function removed - replaced by ExtDialog.Destroy()

//+------------------------------------------------------------------+
//| Get Active TP Settings (runtime or input parameters)             |
//+------------------------------------------------------------------+

double GetActiveExitPercent1()
{
   return (g_ExitPercent1 > 0) ? g_ExitPercent1 : inpExitPercent1;
}

double GetActiveExitPercent2()
{
   return (g_ExitPercent2 > 0) ? g_ExitPercent2 : inpExitPercent2;
}

//+------------------------------------------------------------------+
//| Calculate Partial Exits                                          |
//+------------------------------------------------------------------+
void CalculatePartialExits(RiskCalculation &calc, double pipValuePerLot, bool isLongTrade)
{
   // Get active TP settings
   int numLevels = inpNumberOfLevels;
   double exitPct1 = GetActiveExitPercent1();
   double exitPct2 = GetActiveExitPercent2();

   // Check if Supertrend is managing the last level
   bool supertrendManagingLastLevel = inpUseSupertrendOnLastLevel;

   // Calculate exit percentages based on number of levels
   // If Supertrend is managing the last level, that level should not be calculated
   double exitPercent2 = (numLevels >= 2 && !(numLevels == 2 && supertrendManagingLastLevel)) ? exitPct2 : 0;
   double exitPercent3 = (numLevels == 3 && !supertrendManagingLastLevel) ? (100 - exitPct1 - exitPct2) : 0;
   if(exitPercent3 < 0) exitPercent3 = 0;

   // Calculate lot sizes for each level
   double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);

   calc.partialLots1 = calc.lotSize * (exitPct1 / 100.0);
   calc.partialLots1 = NormalizeDouble(MathFloor(calc.partialLots1 / lotStep) * lotStep, 2);

   calc.partialLots2 = (numLevels >= 2) ? calc.lotSize * (exitPercent2 / 100.0) : 0;
   if(calc.partialLots2 > 0)
      calc.partialLots2 = NormalizeDouble(MathFloor(calc.partialLots2 / lotStep) * lotStep, 2);

   calc.partialLots3 = (numLevels == 3) ? calc.lotSize * (exitPercent3 / 100.0) : 0;
   if(calc.partialLots3 > 0)
      calc.partialLots3 = NormalizeDouble(MathFloor(calc.partialLots3 / lotStep) * lotStep, 2);

   // NOTE: Partial lot sizes (g_PartialLots1/2/3) are NOT updated here during planning.
   // They are only calculated and saved when order is actually executed (ExecuteBuyOrder/ExecuteSellOrder).
   // calc.partialLots1/2/3 values above are for DISPLAY purposes only (panel, TP labels).
   // This ensures INI file only contains actual executed values, never theoretical planning values.

   // Always use draggable lines - Use global variables if set, otherwise use reasonable defaults
   if(g_PartialTP1Price > 0)
   {
      calc.partialTP1Price = g_PartialTP1Price;
   }
   else
   {
      // Default: 1x SL distance as starting point
      double tp1Pips = calc.slPips * 1.0;
      calc.partialTP1Price = isLongTrade ? (calc.entryPrice + (tp1Pips * g_PipValue)) : (calc.entryPrice - (tp1Pips * g_PipValue));
   }

   // TP2: Skip if it's the last level and Supertrend is managing it
   bool skipTP2 = (numLevels == 2 && supertrendManagingLastLevel);
   if(numLevels >= 2 && !skipTP2)
   {
      if(g_PartialTP2Price > 0)
      {
         calc.partialTP2Price = g_PartialTP2Price;
      }
      else
      {
         // Default: 1.5x SL distance
         double tp2Pips = calc.slPips * 1.5;
         calc.partialTP2Price = isLongTrade ? (calc.entryPrice + (tp2Pips * g_PipValue)) : (calc.entryPrice - (tp2Pips * g_PipValue));
      }
   }
   else
   {
      calc.partialTP2Price = 0;
   }

   // TP3: Skip if it's the last level and Supertrend is managing it
   bool skipTP3 = (numLevels == 3 && supertrendManagingLastLevel);
   if(numLevels == 3 && !skipTP3)
   {
      if(g_PartialTP3Price > 0)
      {
         calc.partialTP3Price = g_PartialTP3Price;
      }
      else
      {
         // Default: 2x SL distance
         double tp3Pips = calc.slPips * 2.0;
         calc.partialTP3Price = isLongTrade ? (calc.entryPrice + (tp3Pips * g_PipValue)) : (calc.entryPrice - (tp3Pips * g_PipValue));
      }
   }
   else
   {
      calc.partialTP3Price = 0;
   }

   // Calculate pips from manual prices
   if(isLongTrade)
   {
      calc.partialPips1 = (calc.partialTP1Price - calc.entryPrice) / g_PipValue;
      calc.partialPips2 = (numLevels >= 2 && !skipTP2) ? (calc.partialTP2Price - calc.entryPrice) / g_PipValue : 0;
      calc.partialPips3 = (numLevels == 3 && !skipTP3) ? (calc.partialTP3Price - calc.entryPrice) / g_PipValue : 0;
   }
   else
   {
      calc.partialPips1 = (calc.entryPrice - calc.partialTP1Price) / g_PipValue;
      calc.partialPips2 = (numLevels >= 2 && !skipTP2) ? (calc.entryPrice - calc.partialTP2Price) / g_PipValue : 0;
      calc.partialPips3 = (numLevels == 3 && !skipTP3) ? (calc.entryPrice - calc.partialTP3Price) / g_PipValue : 0;
   }

   // Calculate P&L for manual levels
   // Total fees includes: commission + spread cost (from calc) + exit slippage
   double totalFees = calc.commission + calc.spreadCost + (calc.lotSize * inpExitSlippage * pipValuePerLot);
   double partialFees1 = totalFees * (exitPct1 / 100.0);
   double partialFees2 = (numLevels >= 2 && !skipTP2) ? totalFees * (exitPercent2 / 100.0) : 0;
   double partialFees3 = (numLevels == 3 && !skipTP3) ? totalFees * (exitPercent3 / 100.0) : 0;

   calc.partialGrossPnL1 = calc.partialLots1 * calc.partialPips1 * pipValuePerLot;
   calc.partialGrossPnL2 = (numLevels >= 2 && !skipTP2) ? calc.partialLots2 * calc.partialPips2 * pipValuePerLot : 0;
   calc.partialGrossPnL3 = (numLevels == 3 && !skipTP3) ? calc.partialLots3 * calc.partialPips3 * pipValuePerLot : 0;

   calc.partialNetPnL1 = calc.partialGrossPnL1 - partialFees1;
   calc.partialNetPnL2 = (numLevels >= 2 && !skipTP2) ? calc.partialGrossPnL2 - partialFees2 : 0;
   calc.partialNetPnL3 = (numLevels == 3 && !skipTP3) ? calc.partialGrossPnL3 - partialFees3 : 0;

   calc.partialTotalNetPnL = (numLevels == 3 && !skipTP3) ?
      (calc.partialNetPnL1 + calc.partialNetPnL2 + calc.partialNetPnL3) :
      (numLevels == 2 && !skipTP2) ?
      (calc.partialNetPnL1 + calc.partialNetPnL2) :
      calc.partialNetPnL1;

   // Pip distance calculations (based on gross profit)
   double dollarPerPip = calc.lotSize * pipValuePerLot;
   calc.partialPipDistance1 = (dollarPerPip > 0) ? (calc.partialGrossPnL1 / dollarPerPip) : 0;
   calc.partialPipDistance2 = (numLevels >= 2 && !skipTP2 && dollarPerPip > 0) ? (calc.partialGrossPnL2 / dollarPerPip) : 0;
   calc.partialPipDistance3 = (numLevels == 3 && !skipTP3 && dollarPerPip > 0) ? (calc.partialGrossPnL3 / dollarPerPip) : 0;

   double totalGrossPnL = (numLevels == 3 && !skipTP3) ?
      (calc.partialGrossPnL1 + calc.partialGrossPnL2 + calc.partialGrossPnL3) :
      (numLevels == 2 && !skipTP2) ?
      (calc.partialGrossPnL1 + calc.partialGrossPnL2) :
      calc.partialGrossPnL1;
   calc.partialTotalPipDistance = (dollarPerPip > 0) ? (totalGrossPnL / dollarPerPip) : 0;

   // Store total gross profit for execution cost calculation
   calc.grossTP = totalGrossPnL;
   calc.netTP = calc.partialTotalNetPnL;
}

//+------------------------------------------------------------------+
//| Check if in Trade Management Mode (Active Position Exists)       |
//+------------------------------------------------------------------+
bool IsTradeManagementMode()
{
   // Check if there's an active position for this symbol
   for(int i = 0; i < PositionsTotal(); i++)
   {
      if(PositionGetSymbol(i) == _Symbol)
         return true;
   }
   return false;
}

//+------------------------------------------------------------------+
//| Calculate Break-Even Pips at Order Placement                     |
//+------------------------------------------------------------------+
double CalculateBEPipsForOrder(double lotSize)
{
   // Calculate actual commission for this position
   double actualCommission = lotSize * inpCommissionPerLot;

   // Calculate pip value
   double pipValuePerLot = (inpPipValueMode == PIP_MANUAL) ? inpManualPipValue : (g_PointValue * (g_PipValue / g_Point));

   // Calculate spread cost based on exit slippage mode
   double spreadCostDollars = 0;
   if(inpExitSlippageMode == EXIT_SLIPPAGE_SPREAD_BASED)
   {
      // Spread-based mode: Include actual spread cost
      double currentSpread = GetCurrentSpreadPips();
      spreadCostDollars = lotSize * currentSpread * pipValuePerLot;
   }
   // Manual mode: spreadCostDollars = 0 (user includes it in exit slippage)

   // Calculate actual exit slippage cost (user's buffer/slippage beyond spread)
   double actualExitSlippageCost = lotSize * inpExitSlippage * pipValuePerLot;

   // Calculate total fees (commission + spread cost + exit slippage)
   double actualTotalFees = actualCommission + spreadCostDollars + actualExitSlippageCost;

   // Calculate actual BE distance in pips
   double actualBEPips = actualTotalFees / (lotSize * pipValuePerLot);

   return actualBEPips;
}

//+------------------------------------------------------------------+
//| Get Execution Price Based on Mode                                |
//| Returns the price to use for checking if TP/SL levels are hit    |
//+------------------------------------------------------------------+
double GetExecutionPrice(ENUM_POSITION_TYPE posType, bool isClosingPosition)
{
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);

   // VISUAL mode: Use close[0] - this is what you SEE on the chart
   // This is where you visually expect the price to execute
   if(inpExecutionMode == EXECUTE_VISUAL)
   {
      double last = iClose(_Symbol, PERIOD_CURRENT, 0);
      return last;
   }

   // BIDASK mode: Use correct execution price accounting for spread
   // Broker only executes when BID or ASK touches the line (realistic)
   // For closing BUY position: Need to SELL, so use BID
   // For closing SELL position: Need to BUY, so use ASK
   if(isClosingPosition)
   {
      return (posType == POSITION_TYPE_BUY) ? bid : ask;
   }
   else
   {
      // For opening positions
      return (posType == POSITION_TYPE_BUY) ? ask : bid;
   }
}

//+------------------------------------------------------------------+
//| Check if New Candle Formed                                        |
//+------------------------------------------------------------------+
bool IsNewCandle()
{
   datetime currentCandleTime = iTime(_Symbol, PERIOD_CURRENT, 0);

   if(g_LastCandleTime == 0)
   {
      // First run - initialize
      g_LastCandleTime = currentCandleTime;
      return false;
   }

   if(currentCandleTime != g_LastCandleTime)
   {
      // New candle detected
      g_LastCandleTime = currentCandleTime;
      return true;
   }

   return false;
}

//+------------------------------------------------------------------+
//| Get Candle Close Time Remaining (formatted string)               |
//+------------------------------------------------------------------+
string GetCandleCloseTimeRemaining()
{
   datetime time[];
   if(CopyTime(_Symbol, PERIOD_CURRENT, 0, 1, time) <= 0)
      return "N/A";

   int leftTime = PeriodSeconds(PERIOD_CURRENT) - (int)(TimeCurrent() - time[0]);

   if(leftTime < 0)
      leftTime = 0;

   return TimeToString(leftTime, TIME_SECONDS);
}

//+------------------------------------------------------------------+
//| Manage Execute on Candle Close                                    |
//+------------------------------------------------------------------+
void ManageCandleCloseExecution()
{
   // Show timer and queue status if enabled
   if(inpExecuteOnCandleClose && inpShowCandleTimer)
   {
      string timerText = "Candle Close: " + GetCandleCloseTimeRemaining();

      if(g_CandleCloseOrderQueued)
      {
         string dirStr = g_QueuedOrderIsBuy ? "BUY" : "SELL";
         timerText += "\n⚠ " + dirStr + " order queued - waiting for candle close";
      }

      Comment(timerText);
   }

   // Exit if no order queued
   if(!g_CandleCloseOrderQueued)
      return;

   // Check if new candle formed
   if(IsNewCandle())
   {
      // New candle detected - check spread before executing
      string dirStr = g_QueuedOrderIsBuy ? "BUY" : "SELL";

      // Check spread condition before executing queued order
      if(!CheckSpreadCondition(dirStr))
      {
         // User cancelled due to high spread - clear queue
         g_CandleCloseOrderQueued = false;
         Print("Queued ", dirStr, " order cancelled by user due to high spread");
         return;
      }

      // Check margin condition before executing queued order
      if(!CheckMarginCondition(dirStr))
      {
         // User cancelled due to high margin usage - clear queue
         g_CandleCloseOrderQueued = false;
         Print("Queued ", dirStr, " order cancelled by user due to high margin usage");
         return;
      }

      // Check execution cost before executing queued order
      if(!CheckExecutionCost(dirStr))
      {
         // User cancelled due to high execution cost - clear queue
         g_CandleCloseOrderQueued = false;
         Print("Queued ", dirStr, " order cancelled by user due to high execution cost");
         return;
      }

      // All checks passed - proceed with execution
      Print("Candle closed - Executing queued ", dirStr, " order");

      // Show execution message in comment
      Comment("Candle closed - Executing " + dirStr + " order");

      // Alert popup if enabled
      if(inpCandleCloseAlert)
         Alert("Candle closed - Executing ", dirStr, " order");

      // Execute the order
      if(g_QueuedOrderIsBuy)
         ExecuteBuyOrder();
      else
         ExecuteSellOrder();

      // Reset queue
      g_CandleCloseOrderQueued = false;
   }
}

//+------------------------------------------------------------------+
//| Queue Order for Candle Close Execution (called from buttons)     |
//+------------------------------------------------------------------+
void QueueOrderForCandleClose(bool isBuy)
{
   // Check if already have active position
   if(g_ActivePositionTicket > 0 && PositionSelectByTicket(g_ActivePositionTicket))
   {
      Print("Cannot queue order: Active position already exists");
      Comment("Cannot queue order: Active position already exists");
      return;
   }

   // Queue the order (no validation - let ExecuteBuyOrder/ExecuteSellOrder handle it)
   g_CandleCloseOrderQueued = true;
   g_QueuedOrderIsBuy = isBuy;

   string dirStr = isBuy ? "BUY" : "SELL";
   Print(dirStr, " order queued - will execute on next candle close");

   // Show immediate feedback
   Comment(dirStr + " order queued\nWaiting for candle close...");
}

//+------------------------------------------------------------------+
//| Execute Buy Order                                                 |
//+------------------------------------------------------------------+
void ExecuteBuyOrder()
{
   // Check spread condition FIRST (before any calculations)
   if(!CheckSpreadCondition("BUY"))
      return;  // User cancelled due to high spread

   // Check margin condition SECOND
   if(!CheckMarginCondition("BUY"))
      return;  // User cancelled due to high margin usage

   // Check execution cost THIRD
   if(!CheckExecutionCost("BUY"))
      return;  // User cancelled due to high execution cost

   RiskCalculation calc = (inpDisplayMode == DISPLAY_CONSERVATIVE) ? g_ConservativeCalc : g_IdealCalc;

   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double sl = NormalizeDouble(calc.slPrice, g_Digits);
   double lots = NormalizeDouble(calc.lotSize, 2);

   // Validate lot size
   double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);

   if(lots < minLot) lots = minLot;
   if(lots > maxLot) lots = maxLot;
   lots = MathFloor(lots / lotStep) * lotStep;

   trade.SetExpertMagicNumber(123456);
   trade.SetDeviationInPoints(10);

   // Calculate and lock in BE pips at order placement
   double bePips = CalculateBEPipsForOrder(lots);
   string baseComment = (inpDisplayMode == DISPLAY_CONSERVATIVE) ? "RM_Buy_CONS" : "RM_Buy_IDEAL";
   string commentWithBE = baseComment + "|BE:" + DoubleToString(bePips, 2);

   bool result = false;

   // Determine broker SL based on user setting
   double brokerSL = inpPlaceSLOrder ? sl : 0;

   // Place main BUY order
   result = trade.Buy(lots, _Symbol, ask, brokerSL, 0, commentWithBE);

   if(result)
   {
      string slStatus = inpPlaceSLOrder ? ("SL = " + DoubleToString(sl, g_Digits)) : "No broker SL";
      Print("BUY Order Executed: Lot Size = ", lots, ", ", slStatus);

      // Lock trade direction and create Active SL line (only if EA managing SL)
      g_ActiveTradeDirection = true;  // BUY = true
      g_ActivePositionTicket = trade.ResultOrder();
      g_OriginalSLPrice = sl;  // Store original SL for 1/2 SL calculation
      g_OriginalTotalLots = lots;  // Store original total lot size for multi-instance coordination

      // Reset percentage-based trim tracking for new position
      g_SLTrimLevel1_Executed = false;
      g_SLTrimLevel2_Executed = false;
      g_SLTrimLevel3_Executed = false;

      // Reset TP/SL price change tracking for new position (prevent false executions)
      g_LastTP1Price = 0;
      g_LastTP2Price = 0;
      g_LastTP3Price = 0;
      g_LastActiveSLPriceCheck = 0;

      // Check if Supertrend will manage this position (entire position or last level)
      bool supertrendWillManage = (inpUseSupertrendOnLastLevel && inpNumberOfLevels == 1);

      // Only create Active SL line if EA is managing SL (not broker) AND Supertrend is NOT managing
      if(inpAutoExecuteSL && !supertrendWillManage)
      {
         CreateActiveSLLine(sl);
         Print("Active SL line created at ", DoubleToString(sl, g_Digits));
         Print("Original SL stored: ", DoubleToString(g_OriginalSLPrice, g_Digits), " (for 1/2 SL calculation)");
      }
      else if(supertrendWillManage)
      {
         Print("Active SL line NOT created - Supertrend managing entire position");
      }
      else
      {
         Print("Active SL line NOT created - using broker SL order (AutoExecuteSL is OFF)");
      }

      // Recalculate partial lots based on ACTUAL executed lot size
      // (Lot size may have changed since line drag due to price movement)
      // NOTE: We only calculate TP1 and TP2 lots. Last TP always closes remainder.
      // EXCEPTION: If only 1 level AND Supertrend is managing, no TP lots needed
      double exitPct1 = GetActiveExitPercent1();
      double exitPct2 = (inpNumberOfLevels >= 2) ? g_ExitPercent2 : 0;

      // Check if Supertrend is managing entire position (1 level + Supertrend enabled)
      bool supertrendManagingAll = (inpNumberOfLevels == 1 && inpUseSupertrendOnLastLevel);

      if(supertrendManagingAll)
      {
         // Supertrend manages entire position - no partial TP lots needed
         g_PartialLots1 = 0;
         g_PartialLots2 = 0;
         g_PartialLots3 = 0;
         Print("Supertrend managing entire position (", DoubleToString(lots, 2), " lots) - No TP levels needed");

         // Add position to Supertrend management immediately
         AddSupertrendManagedPosition(g_ActivePositionTicket, "Order placed - 1 level + Supertrend enabled");
      }
      else
      {
         // Calculate TP1 lots
         if(inpNumberOfLevels == 1)
         {
            // TP1 is LAST level - calculate as 100% of position (percentage setting doesn't matter)
            g_PartialLots1 = lots;
            g_PartialLots1 = NormalizeDouble(MathFloor(g_PartialLots1 / lotStep) * lotStep, 2);
         }
         else
         {
            // TP1 is NOT last level - calculate based on percentage setting
            g_PartialLots1 = lots * (exitPct1 / 100.0);
            g_PartialLots1 = NormalizeDouble(MathFloor(g_PartialLots1 / lotStep) * lotStep, 2);
         }

         // Calculate TP2 lots only if 3 levels
         if(inpNumberOfLevels == 3)
         {
            // TP2 is NOT last level - calculate based on percentage setting
            g_PartialLots2 = lots * (exitPct2 / 100.0);
            g_PartialLots2 = NormalizeDouble(MathFloor(g_PartialLots2 / lotStep) * lotStep, 2);
         }
         else if(inpNumberOfLevels == 2)
         {
            // TP2 is LAST level - calculate as 100% of remaining position
            // (But we don't calculate this since last TP always closes remainder)
            g_PartialLots2 = 0;
         }
         else
         {
            g_PartialLots2 = 0;  // Only 1 level - no TP2
         }

         // PartialLots3 is never needed - TP3 always closes entire remaining position
         g_PartialLots3 = 0;

         Print("Partial lots recalculated for executed size (", DoubleToString(lots, 2), " lots): ",
               "TP1=", DoubleToString(g_PartialLots1, 2),
               ", TP2=", DoubleToString(g_PartialLots2, 2),
               " (Last TP closes remainder)");
      }

      // Save updated partial lots to INI file
      SaveSettingsToFile();

      // Place TP limit orders if enabled (skip if Supertrend managing entire position)
      bool allLimitsPlaced = true;

      if(inpPlaceTPOrder && !supertrendManagingAll)
      {

         // TP1 - Use recalculated global values
         double tp1Lots = g_PartialLots1;
         if(tp1Lots < minLot) tp1Lots = minLot;
         if(tp1Lots > maxLot) tp1Lots = maxLot;
         tp1Lots = MathFloor(tp1Lots / lotStep) * lotStep;

         double tp1Price = NormalizeDouble(calc.partialTP1Price, g_Digits);
         bool tp1Result = trade.OrderOpen(_Symbol, ORDER_TYPE_SELL_LIMIT, tp1Lots, 0, tp1Price, 0, 0, ORDER_TIME_GTC, 0, "TP1 @ " + DoubleToString(calc.partialPips1, 1) + " pips");

         if(tp1Result)
            Print("TP1 SELL_LIMIT placed: ", tp1Lots, " lots @ ", tp1Price);
         else
         {
            Print("TP1 SELL_LIMIT failed: ", trade.ResultRetcodeDescription());
            allLimitsPlaced = false;
         }

         // TP2 (if 2 or more levels) - Use recalculated global values
         if(inpNumberOfLevels >= 2)
         {
            double tp2Lots = g_PartialLots2;
            if(tp2Lots < minLot) tp2Lots = minLot;
            if(tp2Lots > maxLot) tp2Lots = maxLot;
            tp2Lots = MathFloor(tp2Lots / lotStep) * lotStep;

            double tp2Price = NormalizeDouble(calc.partialTP2Price, g_Digits);
            bool tp2Result = trade.OrderOpen(_Symbol, ORDER_TYPE_SELL_LIMIT, tp2Lots, 0, tp2Price, 0, 0, ORDER_TIME_GTC, 0, "TP2 @ " + DoubleToString(calc.partialPips2, 1) + " pips");

            if(tp2Result)
               Print("TP2 SELL_LIMIT placed: ", tp2Lots, " lots @ ", tp2Price);
            else
            {
               Print("TP2 SELL_LIMIT failed: ", trade.ResultRetcodeDescription());
               allLimitsPlaced = false;
            }
         }

         // TP3 (if enabled) - Use recalculated global values
         if(inpNumberOfLevels == 3)
         {
            double tp3Lots = g_PartialLots3;
            if(tp3Lots < minLot) tp3Lots = minLot;
            if(tp3Lots > maxLot) tp3Lots = maxLot;
            tp3Lots = MathFloor(tp3Lots / lotStep) * lotStep;

            double tp3Price = NormalizeDouble(calc.partialTP3Price, g_Digits);
            bool tp3Result = trade.OrderOpen(_Symbol, ORDER_TYPE_SELL_LIMIT, tp3Lots, 0, tp3Price, 0, 0, ORDER_TIME_GTC, 0, "TP3 @ " + DoubleToString(calc.partialPips3, 1) + " pips");

            if(tp3Result)
               Print("TP3 SELL_LIMIT placed: ", tp3Lots, " lots @ ", tp3Price);
            else
            {
               Print("TP3 SELL_LIMIT failed: ", trade.ResultRetcodeDescription());
               allLimitsPlaced = false;
            }
         }
      }

      // Display appropriate comment
      string tpStatus;
      if(supertrendManagingAll)
         tpStatus = "Supertrend managing";
      else
         tpStatus = inpPlaceTPOrder ? (allLimitsPlaced ? "TP limits placed" : "Some TP limits failed") : "No TP limits";
      Comment("OK BUY Order Placed Successfully!\nLot Size: ", lots, "\nSL: ", slStatus, "\nTP: ", tpStatus);
   }
   else
   {
      Print("BUY Order Failed: ", trade.ResultRetcodeDescription());
      Comment("✗ BUY Order Failed: ", trade.ResultRetcodeDescription());
   }
}

//+------------------------------------------------------------------+
//| Execute Sell Order                                                |
//+------------------------------------------------------------------+
void ExecuteSellOrder()
{
   // Check spread condition FIRST (before any calculations)
   if(!CheckSpreadCondition("SELL"))
      return;  // User cancelled due to high spread

   // Check margin condition SECOND
   if(!CheckMarginCondition("SELL"))
      return;  // User cancelled due to high margin usage

   // Check execution cost THIRD
   if(!CheckExecutionCost("SELL"))
      return;  // User cancelled due to high execution cost

   RiskCalculation calc = (inpDisplayMode == DISPLAY_CONSERVATIVE) ? g_ConservativeCalc : g_IdealCalc;

   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double sl = NormalizeDouble(calc.slPrice, g_Digits);
   double lots = NormalizeDouble(calc.lotSize, 2);

   // Validate lot size
   double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);

   if(lots < minLot) lots = minLot;
   if(lots > maxLot) lots = maxLot;
   lots = MathFloor(lots / lotStep) * lotStep;

   trade.SetExpertMagicNumber(123456);
   trade.SetDeviationInPoints(10);

   // Calculate and lock in BE pips at order placement
   double bePips = CalculateBEPipsForOrder(lots);
   string baseComment = (inpDisplayMode == DISPLAY_CONSERVATIVE) ? "RM_Sell_CONS" : "RM_Sell_IDEAL";
   string commentWithBE = baseComment + "|BE:" + DoubleToString(bePips, 2);

   bool result = false;

   // Determine broker SL based on user setting
   double brokerSL = inpPlaceSLOrder ? sl : 0;

   // Place main SELL order
   result = trade.Sell(lots, _Symbol, bid, brokerSL, 0, commentWithBE);

   if(result)
   {
      string slStatus = inpPlaceSLOrder ? ("SL = " + DoubleToString(sl, g_Digits)) : "No broker SL";
      Print("SELL Order Executed: Lot Size = ", lots, ", ", slStatus);

      // Lock trade direction and create Active SL line (only if EA managing SL)
      g_ActiveTradeDirection = false;  // SELL = false
      g_ActivePositionTicket = trade.ResultOrder();
      g_OriginalSLPrice = sl;  // Store original SL for 1/2 SL calculation
      g_OriginalTotalLots = lots;  // Store original total lot size for multi-instance coordination

      // Reset percentage-based trim tracking for new position
      g_SLTrimLevel1_Executed = false;
      g_SLTrimLevel2_Executed = false;
      g_SLTrimLevel3_Executed = false;

      // Reset TP/SL price change tracking for new position (prevent false executions)
      g_LastTP1Price = 0;
      g_LastTP2Price = 0;
      g_LastTP3Price = 0;
      g_LastActiveSLPriceCheck = 0;

      // Check if Supertrend will manage this position (entire position or last level)
      bool supertrendWillManage = (inpUseSupertrendOnLastLevel && inpNumberOfLevels == 1);

      // Only create Active SL line if EA is managing SL (not broker) AND Supertrend is NOT managing
      if(inpAutoExecuteSL && !supertrendWillManage)
      {
         CreateActiveSLLine(sl);
         Print("Active SL line created at ", DoubleToString(sl, g_Digits));
         Print("Original SL stored: ", DoubleToString(g_OriginalSLPrice, g_Digits), " (for 1/2 SL calculation)");
      }
      else if(supertrendWillManage)
      {
         Print("Active SL line NOT created - Supertrend managing entire position");
      }
      else
      {
         Print("Active SL line NOT created - using broker SL order (AutoExecuteSL is OFF)");
      }

      // Recalculate partial lots based on ACTUAL executed lot size
      // (Lot size may have changed since line drag due to price movement)
      // NOTE: We only calculate TP1 and TP2 lots. Last TP always closes remainder.
      // EXCEPTION: If only 1 level AND Supertrend is managing, no TP lots needed
      double exitPct1 = GetActiveExitPercent1();
      double exitPct2 = (inpNumberOfLevels >= 2) ? g_ExitPercent2 : 0;

      // Check if Supertrend is managing entire position (1 level + Supertrend enabled)
      bool supertrendManagingAll = (inpNumberOfLevels == 1 && inpUseSupertrendOnLastLevel);

      if(supertrendManagingAll)
      {
         // Supertrend manages entire position - no partial TP lots needed
         g_PartialLots1 = 0;
         g_PartialLots2 = 0;
         g_PartialLots3 = 0;
         Print("Supertrend managing entire position (", DoubleToString(lots, 2), " lots) - No TP levels needed");

         // Add position to Supertrend management immediately
         AddSupertrendManagedPosition(g_ActivePositionTicket, "Order placed - 1 level + Supertrend enabled");
      }
      else
      {
         // Calculate TP1 lots
         if(inpNumberOfLevels == 1)
         {
            // TP1 is LAST level - calculate as 100% of position (percentage setting doesn't matter)
            g_PartialLots1 = lots;
            g_PartialLots1 = NormalizeDouble(MathFloor(g_PartialLots1 / lotStep) * lotStep, 2);
         }
         else
         {
            // TP1 is NOT last level - calculate based on percentage setting
            g_PartialLots1 = lots * (exitPct1 / 100.0);
            g_PartialLots1 = NormalizeDouble(MathFloor(g_PartialLots1 / lotStep) * lotStep, 2);
         }

         // Calculate TP2 lots only if 3 levels
         if(inpNumberOfLevels == 3)
         {
            // TP2 is NOT last level - calculate based on percentage setting
            g_PartialLots2 = lots * (exitPct2 / 100.0);
            g_PartialLots2 = NormalizeDouble(MathFloor(g_PartialLots2 / lotStep) * lotStep, 2);
         }
         else if(inpNumberOfLevels == 2)
         {
            // TP2 is LAST level - calculate as 100% of remaining position
            // (But we don't calculate this since last TP always closes remainder)
            g_PartialLots2 = 0;
         }
         else
         {
            g_PartialLots2 = 0;  // Only 1 level - no TP2
         }

         // PartialLots3 is never needed - TP3 always closes entire remaining position
         g_PartialLots3 = 0;

         Print("Partial lots recalculated for executed size (", DoubleToString(lots, 2), " lots): ",
               "TP1=", DoubleToString(g_PartialLots1, 2),
               ", TP2=", DoubleToString(g_PartialLots2, 2),
               " (Last TP closes remainder)");
      }

      // Save updated partial lots to INI file
      SaveSettingsToFile();

      // Place TP limit orders if enabled (skip if Supertrend managing entire position)
      bool allLimitsPlaced = true;

      if(inpPlaceTPOrder && !supertrendManagingAll)
      {

         // TP1 - Use recalculated global values
         double tp1Lots = g_PartialLots1;
         if(tp1Lots < minLot) tp1Lots = minLot;
         if(tp1Lots > maxLot) tp1Lots = maxLot;
         tp1Lots = MathFloor(tp1Lots / lotStep) * lotStep;

         double tp1Price = NormalizeDouble(calc.partialTP1Price, g_Digits);
         bool tp1Result = trade.OrderOpen(_Symbol, ORDER_TYPE_BUY_LIMIT, tp1Lots, 0, tp1Price, 0, 0, ORDER_TIME_GTC, 0, "TP1 @ " + DoubleToString(calc.partialPips1, 1) + " pips");

         if(tp1Result)
            Print("TP1 BUY_LIMIT placed: ", tp1Lots, " lots @ ", tp1Price);
         else
         {
            Print("TP1 BUY_LIMIT failed: ", trade.ResultRetcodeDescription());
            allLimitsPlaced = false;
         }

         // TP2 (if 2 or more levels) - Use recalculated global values
         if(inpNumberOfLevels >= 2)
         {
            double tp2Lots = g_PartialLots2;
            if(tp2Lots < minLot) tp2Lots = minLot;
            if(tp2Lots > maxLot) tp2Lots = maxLot;
            tp2Lots = MathFloor(tp2Lots / lotStep) * lotStep;

            double tp2Price = NormalizeDouble(calc.partialTP2Price, g_Digits);
            bool tp2Result = trade.OrderOpen(_Symbol, ORDER_TYPE_BUY_LIMIT, tp2Lots, 0, tp2Price, 0, 0, ORDER_TIME_GTC, 0, "TP2 @ " + DoubleToString(calc.partialPips2, 1) + " pips");

            if(tp2Result)
               Print("TP2 BUY_LIMIT placed: ", tp2Lots, " lots @ ", tp2Price);
            else
            {
               Print("TP2 BUY_LIMIT failed: ", trade.ResultRetcodeDescription());
               allLimitsPlaced = false;
            }
         }

         // TP3 (if enabled) - Use recalculated global values
         if(inpNumberOfLevels == 3)
         {
            double tp3Lots = g_PartialLots3;
            if(tp3Lots < minLot) tp3Lots = minLot;
            if(tp3Lots > maxLot) tp3Lots = maxLot;
            tp3Lots = MathFloor(tp3Lots / lotStep) * lotStep;

            double tp3Price = NormalizeDouble(calc.partialTP3Price, g_Digits);
            bool tp3Result = trade.OrderOpen(_Symbol, ORDER_TYPE_BUY_LIMIT, tp3Lots, 0, tp3Price, 0, 0, ORDER_TIME_GTC, 0, "TP3 @ " + DoubleToString(calc.partialPips3, 1) + " pips");

            if(tp3Result)
               Print("TP3 BUY_LIMIT placed: ", tp3Lots, " lots @ ", tp3Price);
            else
            {
               Print("TP3 BUY_LIMIT failed: ", trade.ResultRetcodeDescription());
               allLimitsPlaced = false;
            }
         }
      }

      // Display appropriate comment
      string tpStatus;
      if(supertrendManagingAll)
         tpStatus = "Supertrend managing";
      else
         tpStatus = inpPlaceTPOrder ? (allLimitsPlaced ? "TP limits placed" : "Some TP limits failed") : "No TP limits";
      Comment("OK SELL Order Placed Successfully!\nLot Size: ", lots, "\nSL: ", slStatus, "\nTP: ", tpStatus);
   }
   else
   {
      Print("SELL Order Failed: ", trade.ResultRetcodeDescription());
      Comment("✗ SELL Order Failed: ", trade.ResultRetcodeDescription());
   }
}

//+------------------------------------------------------------------+
//| Move Stop Loss to Break-Even for all open positions              |
//+------------------------------------------------------------------+
void MoveSLToBreakEven()
{
   int total = PositionsTotal();
   int movedCount = 0;
   int failedCount = 0;

   if(total == 0)
   {
      Comment("No open positions to move to Break-Even");
      Print("Move to BE: No open positions");
      return;
   }

   for(int i = total - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket > 0 && PositionGetString(POSITION_SYMBOL) == _Symbol)
      {
         double entryPrice = PositionGetDouble(POSITION_PRICE_OPEN);
         double currentSL = PositionGetDouble(POSITION_SL);
         double currentTP = PositionGetDouble(POSITION_TP);
         ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
         string comment = PositionGetString(POSITION_COMMENT);

         // Parse BE pips from comment (locked in at order placement)
         double actualBEPips = 0;
         int bePos = StringFind(comment, "|BE:");
         if(bePos >= 0)
         {
            // Extract BE value from comment
            string beStr = StringSubstr(comment, bePos + 4);  // Skip "|BE:"
            actualBEPips = StringToDouble(beStr);
         }
         else
         {
            // Fallback: Calculate BE for positions without BE in comment
            double actualLotSize = PositionGetDouble(POSITION_VOLUME);
            actualBEPips = CalculateBEPipsForOrder(actualLotSize);
         }

         // Add user's desired offset
         double totalBEPips = actualBEPips + inpBEOffsetPips;

         // Calculate BE price based on actual entry
         double bePrice;
         if(posType == POSITION_TYPE_BUY)
            bePrice = entryPrice + (totalBEPips * g_PipValue);
         else // POSITION_TYPE_SELL
            bePrice = entryPrice - (totalBEPips * g_PipValue);

         bePrice = NormalizeDouble(bePrice, g_Digits);

         // Only modify if BE is better than current SL
         bool shouldModify = false;
         if(posType == POSITION_TYPE_BUY)
         {
            if(currentSL < bePrice || currentSL == 0)
               shouldModify = true;
         }
         else // SELL
         {
            if(currentSL > bePrice || currentSL == 0)
               shouldModify = true;
         }

         if(shouldModify)
         {
            // Validate stop level distance (broker requirements)
            long stopLevel = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
            double minDistance = stopLevel * g_Point;
            double currentPrice = (posType == POSITION_TYPE_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_BID) : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
            double actualDistance = (posType == POSITION_TYPE_BUY) ? (currentPrice - bePrice) : (bePrice - currentPrice);

            // Check if SL is far enough from current price
            if(actualDistance < minDistance)
            {
               Print("WARNING: Cannot move #", ticket, " to BE - too close to market (",
                     DoubleToString(actualDistance / g_Point, 0), " points, min: ", stopLevel, " points)");
               failedCount++;
               continue;
            }

            bool result = trade.PositionModify(ticket, bePrice, currentTP);

            if(result)
            {
               movedCount++;
               Print("Position #", ticket, " SL moved to BE: ", DoubleToString(actualBEPips, 2),
                     " + ", DoubleToString(inpBEOffsetPips, 1), " offset = ", DoubleToString(totalBEPips, 2), " pips at price ", bePrice);
            }
            else
            {
               failedCount++;
               Print("Failed to move position #", ticket, " to BE: ", trade.ResultRetcodeDescription());
            }
         }
      }
   }

   // Display result
   if(movedCount > 0)
      Comment("✓ Moved ", movedCount, " position(s) to Break-Even");
   else if(failedCount > 0)
      Comment("✗ Failed to move ", failedCount, " position(s) to BE");
   else
      Comment("All positions already at or better than Break-Even");

   Print("Move to BE completed: ", movedCount, " moved, ", failedCount, " failed");
}

//+------------------------------------------------------------------+
//| Close All Open Positions and Cancel Pending Orders              |
//+------------------------------------------------------------------+
void CloseAllTrades()
{
   int positionsTotal = PositionsTotal();
   int ordersTotal = OrdersTotal();
   int closedCount = 0;
   int canceledCount = 0;
   int failedCount = 0;

   if(positionsTotal == 0 && ordersTotal == 0)
   {
      Comment("No open positions or pending orders");
      Print("Close All: Nothing to close");
      return;
   }

   // Close all open positions
   for(int i = positionsTotal - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket > 0 && PositionGetString(POSITION_SYMBOL) == _Symbol)
      {
         bool result = trade.PositionClose(ticket);

         if(result)
         {
            closedCount++;
            Print("✓ Position #", ticket, " closed successfully");
         }
         else
         {
            failedCount++;
            Print("✗ Failed to close position #", ticket, ": ", trade.ResultRetcodeDescription());
         }
      }
   }

   // Cancel all pending orders (TP limit orders, etc.)
   for(int i = ordersTotal - 1; i >= 0; i--)
   {
      ulong ticket = OrderGetTicket(i);
      if(ticket > 0 && OrderGetString(ORDER_SYMBOL) == _Symbol)
      {
         bool result = trade.OrderDelete(ticket);

         if(result)
         {
            canceledCount++;
            string orderType = "";
            ENUM_ORDER_TYPE type = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
            if(type == ORDER_TYPE_BUY_LIMIT) orderType = "BUY_LIMIT";
            else if(type == ORDER_TYPE_SELL_LIMIT) orderType = "SELL_LIMIT";
            else if(type == ORDER_TYPE_BUY_STOP) orderType = "BUY_STOP";
            else if(type == ORDER_TYPE_SELL_STOP) orderType = "SELL_STOP";

            Print("✓ Pending order #", ticket, " (", orderType, ") canceled successfully");
         }
         else
         {
            failedCount++;
            Print("✗ Failed to cancel order #", ticket, ": ", trade.ResultRetcodeDescription());
         }
      }
   }

   // Display result
   string msg = "";
   if(closedCount > 0 && canceledCount > 0)
      msg = StringFormat("✓ Closed %d position(s), Canceled %d order(s)", closedCount, canceledCount);
   else if(closedCount > 0)
      msg = StringFormat("✓ Closed %d position(s)", closedCount);
   else if(canceledCount > 0)
      msg = StringFormat("✓ Canceled %d order(s)", canceledCount);
   else if(failedCount > 0)
      msg = StringFormat("✗ Failed: %d error(s)", failedCount);
   else
      msg = "Nothing was closed";

   Comment(msg);
   Print("Close All completed: ", closedCount, " positions closed, ", canceledCount, " orders canceled, ", failedCount, " failed");
}

//+------------------------------------------------------------------+
//| Update label position and text (for draggable lines)             |
//+------------------------------------------------------------------+
void UpdateLabelPosition(string labelName, double price, string text)
{
   datetime labelTime;
   int anchor;
   double labelPrice = price;

   // Calculate label position based on user setting
   if(inpLabelPosition == LABEL_RIGHT)
   {
      // Position to the right
      labelTime = TimeCurrent() + PeriodSeconds(PERIOD_CURRENT) * 5;
      anchor = ANCHOR_LEFT;
   }
   else if(inpLabelPosition == LABEL_ABOVE)
   {
      // Position above the line
      labelTime = TimeCurrent();
      anchor = ANCHOR_LEFT_LOWER;
      labelPrice = price + (1 * g_Point);  // 1 point above
   }
   else  // LABEL_BELOW
   {
      // Position below the line
      labelTime = TimeCurrent();
      anchor = ANCHOR_LEFT_UPPER;
      labelPrice = price - (1 * g_Point);  // 1 point below
   }

   // Update position
   ObjectSetInteger(0, labelName, OBJPROP_TIME, labelTime);
   ObjectSetDouble(0, labelName, OBJPROP_PRICE, labelPrice);
   ObjectSetInteger(0, labelName, OBJPROP_ANCHOR, anchor);
   ObjectSetString(0, labelName, OBJPROP_TEXT, text);
}

//+------------------------------------------------------------------+
//| Update Reference Lines                                            |
//+------------------------------------------------------------------+
void UpdateLines()
{
   if(!inpShowLines) return;

   RiskCalculation calc = (inpDisplayMode == DISPLAY_CONSERVATIVE) ? g_ConservativeCalc : g_IdealCalc;
   
   datetime currentTime = TimeCurrent();
   datetime futureTime = currentTime + PeriodSeconds(PERIOD_CURRENT) * 100;
   
   // Stop Loss Line
   bool isDynamicSL = (inpSLMode == SL_DYNAMIC);
   bool isHybridSL = (inpSLMode == SL_HYBRID);

   // Check if in Trade Management Mode with Active SL
   bool hasActiveSL = (g_ActivePositionTicket > 0 && g_ActiveSLPrice > 0 && inpAutoExecuteSL);

   // Only draw Dynamic/Manual SL lines when NOT in Trade Management Mode with Active SL
   // (Active SL line is the only SL shown during active trades)
   if(!hasActiveSL)
   {
      // In Hybrid mode, draw both reference SL and dynamic SL lines
      if(isHybridSL)
      {
         double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);

      // Draw Reference SL Line (non-draggable, dashed, shows manual SL calculation)
      if(g_ReferenceSLPrice > 0)
      {
         if(ObjectFind(0, g_SLRefLineName) < 0)
         {
            ObjectCreate(0, g_SLRefLineName, OBJ_TREND, 0, currentTime, g_ReferenceSLPrice, futureTime, g_ReferenceSLPrice);
            ObjectSetInteger(0, g_SLRefLineName, OBJPROP_COLOR, inpSLLineColor);
            ObjectSetInteger(0, g_SLRefLineName, OBJPROP_WIDTH, 1);
            ObjectSetInteger(0, g_SLRefLineName, OBJPROP_STYLE, STYLE_DASH);
            ObjectSetInteger(0, g_SLRefLineName, OBJPROP_RAY_RIGHT, true);
            ObjectSetInteger(0, g_SLRefLineName, OBJPROP_SELECTABLE, false);
            ObjectSetString(0, g_SLRefLineName, OBJPROP_TEXT, "SL Ref (Manual)");
         }
         else
         {
            ObjectMove(0, g_SLRefLineName, 0, currentTime, g_ReferenceSLPrice);
            ObjectMove(0, g_SLRefLineName, 1, futureTime, g_ReferenceSLPrice);
         }
      }

      // Delete reference SL label if it exists (not needed - user knows the setting)
      if(ObjectFind(0, "SLRefLabel") >= 0)
         ObjectDelete(0, "SLRefLabel");

      // Draw Dynamic SL Line (draggable, solid, actual SL for trading)
      if(ObjectFind(0, g_SLLineName) < 0)
      {
         ObjectCreate(0, g_SLLineName, OBJ_TREND, 0, currentTime, calc.slPrice, futureTime, calc.slPrice);
         ObjectSetInteger(0, g_SLLineName, OBJPROP_COLOR, inpSLLineColor);
         ObjectSetInteger(0, g_SLLineName, OBJPROP_WIDTH, 2);
         ObjectSetInteger(0, g_SLLineName, OBJPROP_STYLE, STYLE_SOLID);
         ObjectSetInteger(0, g_SLLineName, OBJPROP_RAY_RIGHT, true);
         ObjectSetInteger(0, g_SLLineName, OBJPROP_SELECTABLE, true);
         ObjectSetString(0, g_SLLineName, OBJPROP_TEXT, "SL (Dynamic)");
      }
      else
      {
         ObjectMove(0, g_SLLineName, 0, currentTime, calc.slPrice);
         ObjectMove(0, g_SLLineName, 1, futureTime, calc.slPrice);
      }

      // Add text label for dynamic SL
      double slPips = MathAbs(currentPrice - calc.slPrice) / g_PipValue;
      string slLabel = "SL: " + DoubleToString(slPips, 1) + " pips";

      if(ObjectFind(0, g_SLLabelName) < 0)
      {
         ObjectCreate(0, g_SLLabelName, OBJ_TEXT, 0, TimeCurrent(), calc.slPrice);
         ObjectSetInteger(0, g_SLLabelName, OBJPROP_COLOR, inpSLLineColor);
         ObjectSetInteger(0, g_SLLabelName, OBJPROP_FONTSIZE, 8);
      }
      UpdateLabelPosition(g_SLLabelName, calc.slPrice, slLabel);
   }
   else
   {
      // Standard mode (Manual or Dynamic)

      // Delete reference SL line if it exists (cleanup from Hybrid mode)
      if(ObjectFind(0, g_SLRefLineName) >= 0)
         ObjectDelete(0, g_SLRefLineName);
      if(ObjectFind(0, "SLRefLabel") >= 0)
         ObjectDelete(0, "SLRefLabel");

      if(ObjectFind(0, g_SLLineName) < 0)
      {
         ObjectCreate(0, g_SLLineName, OBJ_TREND, 0, currentTime, calc.slPrice, futureTime, calc.slPrice);
         ObjectSetInteger(0, g_SLLineName, OBJPROP_COLOR, inpSLLineColor);
         ObjectSetInteger(0, g_SLLineName, OBJPROP_WIDTH, 2);
         ObjectSetInteger(0, g_SLLineName, OBJPROP_STYLE, STYLE_SOLID);
         ObjectSetInteger(0, g_SLLineName, OBJPROP_RAY_RIGHT, true);
         ObjectSetString(0, g_SLLineName, OBJPROP_TEXT, "SL: " + DoubleToString(calc.slPips, 1) + " pips");
      }
      else
      {
         ObjectMove(0, g_SLLineName, 0, currentTime, calc.slPrice);
         ObjectMove(0, g_SLLineName, 1, futureTime, calc.slPrice);
      }

      // Make line draggable in Dynamic mode
      ObjectSetInteger(0, g_SLLineName, OBJPROP_SELECTABLE, isDynamicSL);

      // Add text label showing pip count (for both Manual and Dynamic modes)
      double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      double slPips = MathAbs(currentPrice - calc.slPrice) / g_PipValue;
      string slLabel = "SL: " + DoubleToString(slPips, 1) + " pips";

      if(ObjectFind(0, g_SLLabelName) < 0)
      {
         ObjectCreate(0, g_SLLabelName, OBJ_TEXT, 0, TimeCurrent(), calc.slPrice);
         ObjectSetInteger(0, g_SLLabelName, OBJPROP_COLOR, inpSLLineColor);
         ObjectSetInteger(0, g_SLLabelName, OBJPROP_FONTSIZE, 8);
      }
      UpdateLabelPosition(g_SLLabelName, calc.slPrice, slLabel);
      }
   }
   else
   {
      // In Trade Management Mode with Active SL - hide Dynamic/Manual SL lines
      if(ObjectFind(0, g_SLLineName) >= 0)
         ObjectDelete(0, g_SLLineName);
      if(ObjectFind(0, g_SLLabelName) >= 0)
         ObjectDelete(0, g_SLLabelName);
      if(ObjectFind(0, g_SLRefLineName) >= 0)
         ObjectDelete(0, g_SLRefLineName);
      if(ObjectFind(0, "SLRefLabel") >= 0)
         ObjectDelete(0, "SLRefLabel");
   }

   // Take Profit Line(s)
   // Skip TP lines if Supertrend is managing entire position (1 level + Supertrend enabled)
   bool supertrendManagingAll = (inpNumberOfLevels == 1 && inpUseSupertrendOnLastLevel);

   if(inpShowTP && !supertrendManagingAll)
   {
      // Draw partial exit lines (always draggable)
      double exitPercent3 = (inpNumberOfLevels == 3) ? (100 - inpExitPercent1 - inpExitPercent2) : 0;

      // Level 1
      if(ObjectFind(0, g_PartialTP1LineName) < 0)
      {
         ObjectCreate(0, g_PartialTP1LineName, OBJ_TREND, 0, currentTime, calc.partialTP1Price, futureTime, calc.partialTP1Price);
         ObjectSetInteger(0, g_PartialTP1LineName, OBJPROP_COLOR, inpTPLineColor);
         ObjectSetInteger(0, g_PartialTP1LineName, OBJPROP_WIDTH, 2);
         ObjectSetInteger(0, g_PartialTP1LineName, OBJPROP_STYLE, STYLE_SOLID);
         ObjectSetInteger(0, g_PartialTP1LineName, OBJPROP_RAY_RIGHT, true);
         ObjectSetString(0, g_PartialTP1LineName, OBJPROP_TEXT, "TP1: " + DoubleToString(inpExitPercent1, 0) + "% @ +" + DoubleToString(calc.partialPips1, 1) + " pips");
      }
      else
      {
         ObjectMove(0, g_PartialTP1LineName, 0, currentTime, calc.partialTP1Price);
         ObjectMove(0, g_PartialTP1LineName, 1, futureTime, calc.partialTP1Price);
         ObjectSetString(0, g_PartialTP1LineName, OBJPROP_TEXT, "TP1: " + DoubleToString(inpExitPercent1, 0) + "% @ +" + DoubleToString(calc.partialPips1, 1) + " pips");
      }

      // Make line always draggable
      ObjectSetInteger(0, g_PartialTP1LineName, OBJPROP_SELECTABLE, true);

      // Add text label for TP1
      // Calculate RR using actual gross profit from partial position
      double rr1 = (calc.totalRisk > 0) ? (calc.partialGrossPnL1 / calc.totalRisk) : 0;
      string tp1Label = "TP1: " + DoubleToString(GetActiveExitPercent1(), 0) + "% (" + DoubleToString(calc.partialLots1, 2) + " lots) @ " + DoubleToString(calc.partialPips1, 1) + " pips";
      if(inpShowRR && rr1 > 0) tp1Label += " | RR: " + DoubleToString(rr1, 2);

      if(ObjectFind(0, g_PartialTP1LabelName) < 0)
      {
         ObjectCreate(0, g_PartialTP1LabelName, OBJ_TEXT, 0, TimeCurrent(), calc.partialTP1Price);
         ObjectSetInteger(0, g_PartialTP1LabelName, OBJPROP_COLOR, inpTPLineColor);
         ObjectSetInteger(0, g_PartialTP1LabelName, OBJPROP_FONTSIZE, 8);
      }
      UpdateLabelPosition(g_PartialTP1LabelName, calc.partialTP1Price, tp1Label);

      // Level 2 (if 2 or more levels)
      // Skip TP2 if it's the last level AND Supertrend is managing last level
      bool skipTP2 = (inpNumberOfLevels == 2 && inpUseSupertrendOnLastLevel);

      if(inpNumberOfLevels >= 2 && !skipTP2)
      {
         if(ObjectFind(0, g_PartialTP2LineName) < 0)
         {
            ObjectCreate(0, g_PartialTP2LineName, OBJ_TREND, 0, currentTime, calc.partialTP2Price, futureTime, calc.partialTP2Price);
            ObjectSetInteger(0, g_PartialTP2LineName, OBJPROP_COLOR, inpTPLineColor);
            ObjectSetInteger(0, g_PartialTP2LineName, OBJPROP_WIDTH, 2);
            ObjectSetInteger(0, g_PartialTP2LineName, OBJPROP_STYLE, STYLE_SOLID);
            ObjectSetInteger(0, g_PartialTP2LineName, OBJPROP_RAY_RIGHT, true);
            ObjectSetString(0, g_PartialTP2LineName, OBJPROP_TEXT, "TP2: " + DoubleToString(inpExitPercent2, 0) + "% @ +" + DoubleToString(calc.partialPips2, 1) + " pips");
         }
         else
         {
            ObjectMove(0, g_PartialTP2LineName, 0, currentTime, calc.partialTP2Price);
            ObjectMove(0, g_PartialTP2LineName, 1, futureTime, calc.partialTP2Price);
            ObjectSetString(0, g_PartialTP2LineName, OBJPROP_TEXT, "TP2: " + DoubleToString(inpExitPercent2, 0) + "% @ +" + DoubleToString(calc.partialPips2, 1) + " pips");
         }

         // Make line always draggable
         ObjectSetInteger(0, g_PartialTP2LineName, OBJPROP_SELECTABLE, true);

         // Add text label for TP2
         // Calculate RR using actual gross profit from partial position
         double rr2 = (calc.totalRisk > 0) ? (calc.partialGrossPnL2 / calc.totalRisk) : 0;
         string tp2Label = "TP2: " + DoubleToString(GetActiveExitPercent2(), 0) + "% (" + DoubleToString(calc.partialLots2, 2) + " lots) @ " + DoubleToString(calc.partialPips2, 1) + " pips";
         if(inpShowRR && rr2 > 0) tp2Label += " | RR: " + DoubleToString(rr2, 2);

         if(ObjectFind(0, g_PartialTP2LabelName) < 0)
         {
            ObjectCreate(0, g_PartialTP2LabelName, OBJ_TEXT, 0, TimeCurrent(), calc.partialTP2Price);
            ObjectSetInteger(0, g_PartialTP2LabelName, OBJPROP_COLOR, inpTPLineColor);
            ObjectSetInteger(0, g_PartialTP2LabelName, OBJPROP_FONTSIZE, 8);
         }
         UpdateLabelPosition(g_PartialTP2LabelName, calc.partialTP2Price, tp2Label);
      }
      else if(skipTP2)
      {
         // Delete TP2 line and label when Supertrend is managing last level (2 levels config)
         if(ObjectFind(0, g_PartialTP2LineName) >= 0)
            ObjectDelete(0, g_PartialTP2LineName);
         if(ObjectFind(0, g_PartialTP2LabelName) >= 0)
            ObjectDelete(0, g_PartialTP2LabelName);
      }

      // Level 3 (if enabled)
      // Skip TP3 if it's the last level AND Supertrend is managing last level
      bool skipTP3 = (inpNumberOfLevels == 3 && inpUseSupertrendOnLastLevel);

      if(inpNumberOfLevels == 3 && !skipTP3)
      {
         if(ObjectFind(0, g_PartialTP3LineName) < 0)
         {
            ObjectCreate(0, g_PartialTP3LineName, OBJ_TREND, 0, currentTime, calc.partialTP3Price, futureTime, calc.partialTP3Price);
            ObjectSetInteger(0, g_PartialTP3LineName, OBJPROP_COLOR, inpTPLineColor);
            ObjectSetInteger(0, g_PartialTP3LineName, OBJPROP_WIDTH, 2);
            ObjectSetInteger(0, g_PartialTP3LineName, OBJPROP_STYLE, STYLE_DASH);
            ObjectSetInteger(0, g_PartialTP3LineName, OBJPROP_RAY_RIGHT, true);
            ObjectSetString(0, g_PartialTP3LineName, OBJPROP_TEXT, "TP3: " + DoubleToString(exitPercent3, 0) + "% @ +" + DoubleToString(calc.partialPips3, 1) + " pips");
         }
         else
         {
            ObjectMove(0, g_PartialTP3LineName, 0, currentTime, calc.partialTP3Price);
            ObjectMove(0, g_PartialTP3LineName, 1, futureTime, calc.partialTP3Price);
            ObjectSetString(0, g_PartialTP3LineName, OBJPROP_TEXT, "TP3: " + DoubleToString(exitPercent3, 0) + "% @ +" + DoubleToString(calc.partialPips3, 1) + " pips");
         }

         // Make line always draggable
         ObjectSetInteger(0, g_PartialTP3LineName, OBJPROP_SELECTABLE, true);

         // Add text label for TP3
         // Calculate RR using actual gross profit from partial position
         double rr3 = (calc.totalRisk > 0) ? (calc.partialGrossPnL3 / calc.totalRisk) : 0;
         string tp3Label = "TP3: " + DoubleToString(exitPercent3, 0) + "% (" + DoubleToString(calc.partialLots3, 2) + " lots) @ " + DoubleToString(calc.partialPips3, 1) + " pips";
         if(inpShowRR && rr3 > 0) tp3Label += " | RR: " + DoubleToString(rr3, 2);

         if(ObjectFind(0, g_PartialTP3LabelName) < 0)
         {
            ObjectCreate(0, g_PartialTP3LabelName, OBJ_TEXT, 0, TimeCurrent(), calc.partialTP3Price);
            ObjectSetInteger(0, g_PartialTP3LabelName, OBJPROP_COLOR, inpTPLineColor);
            ObjectSetInteger(0, g_PartialTP3LabelName, OBJPROP_FONTSIZE, 8);
         }
         UpdateLabelPosition(g_PartialTP3LabelName, calc.partialTP3Price, tp3Label);
      }
      else if(skipTP3 || inpNumberOfLevels < 3)
      {
         // Delete TP3 line and label if:
         // 1. Supertrend managing last level (3 levels config), OR
         // 2. Less than 3 levels selected
         if(ObjectFind(0, g_PartialTP3LineName) >= 0)
            ObjectDelete(0, g_PartialTP3LineName);
         if(ObjectFind(0, g_PartialTP3LabelName) >= 0)
            ObjectDelete(0, g_PartialTP3LabelName);
      }

      // Delete standard TP line and label if they exist (cleanup from old version)
      if(ObjectFind(0, g_TPLineName) >= 0)
         ObjectDelete(0, g_TPLineName);
      if(ObjectFind(0, g_TPLabelName) >= 0)
         ObjectDelete(0, g_TPLabelName);
   }
   else if(supertrendManagingAll)
   {
      // Supertrend managing entire position - delete all TP lines
      if(ObjectFind(0, g_PartialTP1LineName) >= 0)
         ObjectDelete(0, g_PartialTP1LineName);
      if(ObjectFind(0, g_PartialTP1LabelName) >= 0)
         ObjectDelete(0, g_PartialTP1LabelName);
      if(ObjectFind(0, g_PartialTP2LineName) >= 0)
         ObjectDelete(0, g_PartialTP2LineName);
      if(ObjectFind(0, g_PartialTP2LabelName) >= 0)
         ObjectDelete(0, g_PartialTP2LabelName);
      if(ObjectFind(0, g_PartialTP3LineName) >= 0)
         ObjectDelete(0, g_PartialTP3LineName);
      if(ObjectFind(0, g_PartialTP3LabelName) >= 0)
         ObjectDelete(0, g_PartialTP3LabelName);
      if(ObjectFind(0, g_TPLineName) >= 0)
         ObjectDelete(0, g_TPLineName);
      if(ObjectFind(0, g_TPLabelName) >= 0)
         ObjectDelete(0, g_TPLabelName);
   }

   // Entry Line
   if(inpShowEntryLine)
   {
      if(ObjectFind(0, g_EntryLineName) < 0)
      {
         ObjectCreate(0, g_EntryLineName, OBJ_TREND, 0, currentTime, calc.entryPrice, futureTime, calc.entryPrice);
         ObjectSetInteger(0, g_EntryLineName, OBJPROP_COLOR, inpEntryLineColor);
         ObjectSetInteger(0, g_EntryLineName, OBJPROP_WIDTH, 2);
         ObjectSetInteger(0, g_EntryLineName, OBJPROP_STYLE, STYLE_DOT);
         ObjectSetInteger(0, g_EntryLineName, OBJPROP_RAY_RIGHT, true);
         ObjectSetInteger(0, g_EntryLineName, OBJPROP_SELECTABLE, false);
         string entryLabel = (inpDisplayMode == DISPLAY_CONSERVATIVE) ? "Entry (w/ Slippage)" : "Entry";
         ObjectSetString(0, g_EntryLineName, OBJPROP_TEXT, entryLabel);
      }
      else
      {
         ObjectMove(0, g_EntryLineName, 0, currentTime, calc.entryPrice);
         ObjectMove(0, g_EntryLineName, 1, futureTime, calc.entryPrice);
      }
   }

   // Restore Active SL line if there's an active position and line is missing
   // (Handles EA reload, timeframe changes, or any deletion)
   // Only restore if EA is managing SL (not broker)
   if(inpAutoExecuteSL && g_ActiveSLPrice > 0 && g_ActivePositionTicket > 0)
   {
      // Check if line exists
      if(ObjectFind(0, g_ActiveSLLineName) < 0 || ObjectFind(0, g_ActiveSLLabelName) < 0)
      {
         // Verify position still exists before recreating line
         if(PositionSelectByTicket(g_ActivePositionTicket))
         {
            if(PositionGetString(POSITION_SYMBOL) == _Symbol)
            {
               CreateActiveSLLine(g_ActiveSLPrice);
            }
            else
            {
               // Position is for different symbol, clear Active SL
               g_ActiveSLPrice = 0;
               g_OriginalSLPrice = 0;
               g_ActivePositionTicket = 0;
            }
         }
         else
         {
            // Position no longer exists, clear Active SL
            g_ActiveSLPrice = 0;
            g_OriginalSLPrice = 0;
            g_ActivePositionTicket = 0;
         }
      }
   }
   else if(!inpAutoExecuteSL && (ObjectFind(0, g_ActiveSLLineName) >= 0 || ObjectFind(0, g_ActiveSLLabelName) >= 0))
   {
      // Auto-execute SL is OFF but line exists - delete it
      DeleteActiveSLLine();
   }
}

//+------------------------------------------------------------------+
//| Create/Update Active SL Line                                      |
//+------------------------------------------------------------------+
void CreateActiveSLLine(double price)
{
   if(price <= 0) return;

   // Create or update Active SL line (horizontal line spans entire chart)
   if(ObjectFind(0, g_ActiveSLLineName) < 0)
   {
      ObjectCreate(0, g_ActiveSLLineName, OBJ_HLINE, 0, 0, price);
      ObjectSetInteger(0, g_ActiveSLLineName, OBJPROP_COLOR, inpActiveSLLineColor);
      ObjectSetInteger(0, g_ActiveSLLineName, OBJPROP_WIDTH, 2);
      ObjectSetInteger(0, g_ActiveSLLineName, OBJPROP_STYLE, STYLE_SOLID);
      ObjectSetInteger(0, g_ActiveSLLineName, OBJPROP_SELECTABLE, true);
      ObjectSetInteger(0, g_ActiveSLLineName, OBJPROP_BACK, false);
      ObjectSetString(0, g_ActiveSLLineName, OBJPROP_TEXT, "Active SL");
   }
   else
   {
      // Update price and color (HLINE automatically spans the chart)
      ObjectSetDouble(0, g_ActiveSLLineName, OBJPROP_PRICE, price);
      ObjectSetInteger(0, g_ActiveSLLineName, OBJPROP_COLOR, inpActiveSLLineColor);
   }

   // Create or update label - anchored to RIGHT edge of visible chart, ON TOP of line
   string labelText = "Active SL";

   // Get the last visible bar time (right edge of chart)
   int firstVisibleBar = (int)ChartGetInteger(0, CHART_FIRST_VISIBLE_BAR);
   int visibleBars = (int)ChartGetInteger(0, CHART_VISIBLE_BARS);
   int lastVisibleBar = MathMax(0, firstVisibleBar - visibleBars + 1);
   datetime rightEdgeTime = iTime(_Symbol, PERIOD_CURRENT, lastVisibleBar);

   if(ObjectFind(0, g_ActiveSLLabelName) < 0)
   {
      ObjectCreate(0, g_ActiveSLLabelName, OBJ_TEXT, 0, rightEdgeTime, price);
      ObjectSetInteger(0, g_ActiveSLLabelName, OBJPROP_COLOR, inpActiveSLLineColor);
      ObjectSetInteger(0, g_ActiveSLLabelName, OBJPROP_FONTSIZE, 8);
      ObjectSetInteger(0, g_ActiveSLLabelName, OBJPROP_ANCHOR, ANCHOR_RIGHT_LOWER);
   }
   else
   {
      // Update position to always stay at right edge
      ObjectSetInteger(0, g_ActiveSLLabelName, OBJPROP_TIME, rightEdgeTime);
      ObjectSetDouble(0, g_ActiveSLLabelName, OBJPROP_PRICE, price);
      ObjectSetInteger(0, g_ActiveSLLabelName, OBJPROP_COLOR, inpActiveSLLineColor);
   }
   ObjectSetString(0, g_ActiveSLLabelName, OBJPROP_TEXT, labelText);

   // Update global price tracker
   g_ActiveSLPrice = price;
}

//+------------------------------------------------------------------+
//| Delete Active SL Line                                             |
//+------------------------------------------------------------------+
void DeleteActiveSLLine()
{
   ObjectDelete(0, g_ActiveSLLineName);
   ObjectDelete(0, g_ActiveSLLabelName);
   g_ActiveSLPrice = 0;
   g_OriginalSLPrice = 0;  // Clear original SL
   g_ActivePositionTicket = 0;
}

//+------------------------------------------------------------------+
//| Create/Update Pending Order Line                                 |
//+------------------------------------------------------------------+
void CreatePendingOrderLine(double price)
{
   if(price <= 0) return;

   // Create or update Pending Order line (horizontal line spans entire chart)
   if(ObjectFind(0, g_PendingOrderLineName) < 0)
   {
      ObjectCreate(0, g_PendingOrderLineName, OBJ_HLINE, 0, 0, price);
      ObjectSetInteger(0, g_PendingOrderLineName, OBJPROP_COLOR, inpPendingOrderLineColor);
      ObjectSetInteger(0, g_PendingOrderLineName, OBJPROP_WIDTH, 2);
      ObjectSetInteger(0, g_PendingOrderLineName, OBJPROP_STYLE, STYLE_DASHDOTDOT);
      ObjectSetInteger(0, g_PendingOrderLineName, OBJPROP_SELECTABLE, true);
      ObjectSetInteger(0, g_PendingOrderLineName, OBJPROP_BACK, false);
      ObjectSetString(0, g_PendingOrderLineName, OBJPROP_TEXT, "Pending Order");
   }
   else
   {
      // Update price and color (HLINE automatically spans the chart)
      ObjectSetDouble(0, g_PendingOrderLineName, OBJPROP_PRICE, price);
      ObjectSetInteger(0, g_PendingOrderLineName, OBJPROP_COLOR, inpPendingOrderLineColor);
   }

   // Create or update label - anchored to RIGHT edge of visible chart
   // Determine direction based on TRADE SETUP (TP1/SL positioning), not line position
   double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   bool isLongTrade = true;  // Default

   // Check if trade setup is defined via TP1 position (most reliable)
   if(g_PartialTP1Price > 0)
   {
      isLongTrade = (g_PartialTP1Price > currentPrice);  // TP above = LONG, TP below = SHORT
   }
   // Fallback: Check Dynamic SL position if TP1 not set
   else if(g_DynamicSLPrice > 0)
   {
      isLongTrade = (g_DynamicSLPrice < currentPrice);  // SL below = LONG, SL above = SHORT
   }
   // Last resort: Use input parameter if configured
   else if(inpTradeDirection != TRADE_AUTO)
   {
      isLongTrade = (inpTradeDirection == TRADE_BUY);
   }

   string direction = isLongTrade ? "BUY" : "SELL";
   string labelText = "Pending " + direction + " Order";

   // Get the last visible bar time (right edge of chart)
   int firstVisibleBar = (int)ChartGetInteger(0, CHART_FIRST_VISIBLE_BAR);
   int visibleBars = (int)ChartGetInteger(0, CHART_VISIBLE_BARS);
   int lastVisibleBar = MathMax(0, firstVisibleBar - visibleBars + 1);
   datetime rightEdgeTime = iTime(_Symbol, PERIOD_CURRENT, lastVisibleBar);

   if(ObjectFind(0, g_PendingOrderLabelName) < 0)
   {
      ObjectCreate(0, g_PendingOrderLabelName, OBJ_TEXT, 0, rightEdgeTime, price);
      ObjectSetInteger(0, g_PendingOrderLabelName, OBJPROP_COLOR, inpPendingOrderLineColor);
      ObjectSetInteger(0, g_PendingOrderLabelName, OBJPROP_FONTSIZE, 8);
      ObjectSetInteger(0, g_PendingOrderLabelName, OBJPROP_ANCHOR, ANCHOR_RIGHT_LOWER);
   }
   else
   {
      // Update position to always stay at right edge
      ObjectSetInteger(0, g_PendingOrderLabelName, OBJPROP_TIME, rightEdgeTime);
      ObjectSetDouble(0, g_PendingOrderLabelName, OBJPROP_PRICE, price);
      ObjectSetInteger(0, g_PendingOrderLabelName, OBJPROP_COLOR, inpPendingOrderLineColor);
   }
   ObjectSetString(0, g_PendingOrderLabelName, OBJPROP_TEXT, labelText);

   // Update global price tracker and mark as active
   g_PendingOrderPrice = price;
   g_PendingOrderActive = true;
}

//+------------------------------------------------------------------+
//| Delete Pending Order Line                                         |
//+------------------------------------------------------------------+
void DeletePendingOrderLine()
{
   ObjectDelete(0, g_PendingOrderLineName);
   ObjectDelete(0, g_PendingOrderLabelName);
   // Don't clear g_PendingOrderPrice - preserve it so line can be restored later
   // g_PendingOrderPrice = 0;  // REMOVED - keep the price for restoration
   g_PendingOrderActive = false;
}

//+------------------------------------------------------------------+
//| Permanently Delete Pending Order Line (clear all state)          |
//+------------------------------------------------------------------+
void PermanentlyDeletePendingOrderLine()
{
   ObjectDelete(0, g_PendingOrderLineName);
   ObjectDelete(0, g_PendingOrderLabelName);
   g_PendingOrderPrice = 0;  // Clear price permanently
   g_PendingOrderActive = false;
}

//+------------------------------------------------------------------+
//| Manage Pending Order Line Execution (Touch to Execute)           |
//+------------------------------------------------------------------+
void ManagePendingOrderExecution()
{
   // Exit if pending order line is disabled or not active
   if(!inpUsePendingOrderLine)
   {
      // Feature disabled, permanently delete line if it exists
      if(g_PendingOrderActive)
         PermanentlyDeletePendingOrderLine();
      return;
   }

   // Exit if currently reloading from file (prevent false executions during sync)
   if(g_IsReloadingFromFile)
      return;

   if(!g_PendingOrderActive)
      return;

   // Exit if pending order price not set
   if(g_PendingOrderPrice <= 0)
      return;

   // Get current BID price
   double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);

   // Determine order direction based on TRADE SETUP (TP1/SL positioning), not line position
   bool isLongTrade = true;  // Default
   bool hasTradeSetup = false;
   string setupSource = "default";

   // Check if trade setup is defined via TP1 position (most reliable)
   if(g_PartialTP1Price > 0)
   {
      isLongTrade = (g_PartialTP1Price > currentPrice);  // TP above = LONG, TP below = SHORT
      hasTradeSetup = true;
      setupSource = "TP1";
   }
   // Fallback: Check Dynamic SL position if TP1 not set
   else if(g_DynamicSLPrice > 0)
   {
      isLongTrade = (g_DynamicSLPrice < currentPrice);  // SL below = LONG, SL above = SHORT
      hasTradeSetup = true;
      setupSource = "SL";
   }
   // Last resort: Use input parameter if configured
   else if(inpTradeDirection != TRADE_AUTO)
   {
      isLongTrade = (inpTradeDirection == TRADE_BUY);
      hasTradeSetup = true;
      setupSource = "input";
   }

   // Direction is now based on trade setup, not line position
   bool isBuyOrder = isLongTrade;
   bool isSellOrder = !isLongTrade;
   string direction = isBuyOrder ? "BUY" : "SELL";

   // Get execution price using centralized function (respects inpExecutionMode)
   ENUM_POSITION_TYPE orderType = isBuyOrder ? POSITION_TYPE_BUY : POSITION_TYPE_SELL;
   double executionPrice = GetExecutionPrice(orderType, false);  // false = opening position

   // Check if price has touched the line
   bool priceTouched = false;

   // Use user-defined tolerance (in pips)
   double tolerance = inpPendingOrderTolerance * g_PipValue;

   // Execute when price is AT the line (within user-defined tolerance)
   // This works for both BUY and SELL - just checking if price reached the line
   if(MathAbs(executionPrice - g_PendingOrderPrice) <= tolerance)
   {
      priceTouched = true;
   }

   // Execute order if price touched
   if(priceTouched)
   {
      string modeStr = (inpExecutionMode == EXECUTE_VISUAL) ? "VISUAL" : "BID/ASK";
      Print("✓ Pending Order Line touched at ", DoubleToString(g_PendingOrderPrice, g_Digits),
            " - Executing ", direction, " order (Mode: ", modeStr, ")");

      // Execute the order using existing execution functions
      bool orderExecuted = false;
      if(direction == "BUY")
      {
         ExecuteBuyOrder();
         orderExecuted = true;
      }
      else if(direction == "SELL")
      {
         ExecuteSellOrder();
         orderExecuted = true;
      }

      if(orderExecuted)
      {
         // Delete the pending order line after execution
         DeletePendingOrderLine();

         // Notifications
         if(inpPendingOrderEnableAlert)
            Alert("Pending ", direction, " Order executed for ", _Symbol, " at ", DoubleToString(g_PendingOrderPrice, g_Digits));

         if(inpPendingOrderEnableSound)
            PlaySound(inpPendingOrderSoundFile);

         if(inpPendingOrderEnablePush)
            SendNotification("Pending " + direction + " Order executed for " + _Symbol + " at " + DoubleToString(g_PendingOrderPrice, g_Digits));

         if(inpPendingOrderEnableEmail)
         {
            string subject = "MT5 Alert: Pending Order Executed - " + _Symbol;
            string body = "Pending " + direction + " Order executed!\n\n" +
                         "Symbol: " + _Symbol + "\n" +
                         "Order Type: " + direction + "\n" +
                         "Line Price: " + DoubleToString(g_PendingOrderPrice, g_Digits) + "\n" +
                         "Execution Mode: " + modeStr + "\n" +
                         "Time: " + TimeToString(TimeCurrent(), TIME_DATE | TIME_SECONDS);
            SendMail(subject, body);
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Delete Lines                                                      |
//+------------------------------------------------------------------+
void DeleteLines()
{
   ObjectDelete(0, g_SLLineName);
   ObjectDelete(0, g_TPLineName);
   ObjectDelete(0, g_EntryLineName);
   ObjectDelete(0, g_BELineName);
   ObjectDelete(0, g_PartialTP1LineName);
   ObjectDelete(0, g_PartialTP2LineName);
   ObjectDelete(0, g_PartialTP3LineName);
   ObjectDelete(0, g_ActiveSLLineName);
   ObjectDelete(0, g_PendingOrderLineName);
   // Delete all TP line labels
   ObjectDelete(0, g_SLLabelName);
   ObjectDelete(0, g_TPLabelName);
   ObjectDelete(0, g_PartialTP1LabelName);
   ObjectDelete(0, g_PartialTP2LabelName);
   ObjectDelete(0, g_PartialTP3LabelName);
   ObjectDelete(0, g_ActiveSLLabelName);
   ObjectDelete(0, g_PendingOrderLabelName);
}

//+------------------------------------------------------------------+
//| Load Global Variables From INI File (Auto-sync)                  |
//| loadPercentages: true = load all, false = skip percentage settings |
//+------------------------------------------------------------------+
void LoadSettingsFromFile(bool loadPercentages = true)
{
   if(inpExportDirectory == "")
      return;

   string filename = inpExportDirectory + "\\FRTM-GlobalVars-" + _Symbol + ".ini";

   int fileHandle = FileOpen(filename, FILE_READ|FILE_TXT|FILE_COMMON);
   if(fileHandle == INVALID_HANDLE)
      return;  // File doesn't exist yet (first run)

   string section = "";
   int linesRead = 0;

   while(!FileIsEnding(fileHandle))
   {
      string line = FileReadString(fileHandle);
      StringTrimLeft(line);
      StringTrimRight(line);

      // Skip empty lines and comments
      if(line == "" || StringFind(line, "#") == 0)
         continue;

      // Parse section header [Section]
      if(StringFind(line, "[") == 0)
      {
         int endPos = StringFind(line, "]");
         if(endPos > 1)
            section = StringSubstr(line, 1, endPos - 1);
         continue;
      }

      // Parse key=value
      int equalPos = StringFind(line, "=");
      if(equalPos > 0 && section == "GlobalVariables")
      {
         string key = StringSubstr(line, 0, equalPos);
         string value = StringSubstr(line, equalPos + 1);
         StringTrimLeft(key);
         StringTrimRight(key);

         // Load global variables only - these update immediately
         if(key == "DynamicSLPrice")
            g_DynamicSLPrice = StringToDouble(value);
         else if(key == "DynamicTPPrice")
            g_DynamicTPPrice = StringToDouble(value);
         else if(key == "PartialTP1Price")
            g_PartialTP1Price = StringToDouble(value);
         else if(key == "PartialTP2Price")
            g_PartialTP2Price = StringToDouble(value);
         else if(key == "PartialTP3Price")
            g_PartialTP3Price = StringToDouble(value);
         else if(key == "PartialLots1")
            g_PartialLots1 = StringToDouble(value);
         else if(key == "PartialLots2")
            g_PartialLots2 = StringToDouble(value);
         // PartialLots3 not loaded - last TP always closes entire remaining position
         else if(key == "OriginalTotalLots")
            g_OriginalTotalLots = StringToDouble(value);
         else if(loadPercentages && key == "ExitPercent1")
            g_ExitPercent1 = StringToDouble(value);
         else if(loadPercentages && key == "ExitPercent2")
            g_ExitPercent2 = StringToDouble(value);
         else if(key == "ActiveSLPrice")
            g_ActiveSLPrice = StringToDouble(value);
         else if(key == "OriginalSLPrice")
            g_OriginalSLPrice = StringToDouble(value);
         else if(key == "ActivePositionTicket")
            g_ActivePositionTicket = (ulong)StringToInteger(value);
         else if(key == "ActiveTradeDirection")
            g_ActiveTradeDirection = (StringToInteger(value) == 1) ? true : false;

         linesRead++;
      }
   }

   FileClose(fileHandle);
   if(linesRead > 0)
   {
      string loadMode = loadPercentages ? "all values" : "prices/SL only (percentages skipped)";
      Print("Global variables loaded: ", linesRead, " from ", filename, " (", loadMode, ")");
   }
}

//+------------------------------------------------------------------+
//| Save Global Variables To INI File (Auto-sync)                    |
//+------------------------------------------------------------------+
void SaveSettingsToFile()
{
   if(inpExportDirectory == "")
      return;

   // Prevent circular saves during file reload
   if(g_IsReloadingFromFile)
      return;

   string filename = inpExportDirectory + "\\FRTM-GlobalVars-" + _Symbol + ".ini";

   int fileHandle = FileOpen(filename, FILE_WRITE|FILE_TXT|FILE_COMMON);
   if(fileHandle == INVALID_HANDLE)
   {
      Print("Failed to save global variables: ", filename, " Error: ", GetLastError());
      return;
   }

   // Write header
   FileWriteString(fileHandle, "# FRTM-MT5 Global Variables (Auto-Sync)\n");
   FileWriteString(fileHandle, "# Draggable line positions, TP settings, and Active SL state\n");
   FileWriteString(fileHandle, "# Last saved: " + TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS) + "\n");
   FileWriteString(fileHandle, "# Symbol: " + _Symbol + "\n\n");

   // [GlobalVariables] - Draggable line prices, TP settings, and Active SL state
   FileWriteString(fileHandle, "[GlobalVariables]\n");
   FileWriteString(fileHandle, "DynamicSLPrice=" + DoubleToString(g_DynamicSLPrice, _Digits) + "\n");
   FileWriteString(fileHandle, "DynamicTPPrice=" + DoubleToString(g_DynamicTPPrice, _Digits) + "\n");
   FileWriteString(fileHandle, "PartialTP1Price=" + DoubleToString(g_PartialTP1Price, _Digits) + "\n");
   FileWriteString(fileHandle, "PartialTP2Price=" + DoubleToString(g_PartialTP2Price, _Digits) + "\n");
   FileWriteString(fileHandle, "PartialTP3Price=" + DoubleToString(g_PartialTP3Price, _Digits) + "\n");
   FileWriteString(fileHandle, "PartialLots1=" + DoubleToString(g_PartialLots1, 2) + "\n");
   FileWriteString(fileHandle, "PartialLots2=" + DoubleToString(g_PartialLots2, 2) + "\n");
   // PartialLots3 not saved - last TP always closes entire remaining position
   FileWriteString(fileHandle, "OriginalTotalLots=" + DoubleToString(g_OriginalTotalLots, 2) + "\n");
   FileWriteString(fileHandle, "ExitPercent1=" + DoubleToString(g_ExitPercent1, 2) + "\n");
   FileWriteString(fileHandle, "ExitPercent2=" + DoubleToString(g_ExitPercent2, 2) + "\n");
   FileWriteString(fileHandle, "ActiveSLPrice=" + DoubleToString(g_ActiveSLPrice, _Digits) + "\n");
   FileWriteString(fileHandle, "OriginalSLPrice=" + DoubleToString(g_OriginalSLPrice, _Digits) + "\n");
   FileWriteString(fileHandle, "ActivePositionTicket=" + IntegerToString(g_ActivePositionTicket) + "\n");
   FileWriteString(fileHandle, "ActiveTradeDirection=" + IntegerToString(g_ActiveTradeDirection ? 1 : 0) + "\n");

   FileClose(fileHandle);
}

//+------------------------------------------------------------------+
//| Check File For Changes and Reload                                 |
//+------------------------------------------------------------------+
void CheckAndReloadSettings()
{
   if(inpExportDirectory == "")
      return;

   string filename = inpExportDirectory + "\\FRTM-GlobalVars-" + _Symbol + ".ini";

   // Get file modification time
   long modifyTime = FileGetInteger(filename, FILE_MODIFY_DATE, true);
   if(modifyTime <= 0)
      return;

   datetime fileTime = (datetime)modifyTime;

   if(fileTime > g_LastFileModifyTime)
   {
      // Set flag to prevent SaveSettingsToFile() from being called during reload
      g_IsReloadingFromFile = true;

      LoadSettingsFromFile(true);  // true = load all settings including percentages (remote sync)
      g_LastFileModifyTime = fileTime;

      // Restore Active SL line if data exists and EA is managing SL
      if(inpAutoExecuteSL && g_ActiveSLPrice > 0 && g_ActivePositionTicket > 0)
      {
         // Verify the position still exists
         if(PositionSelectByTicket(g_ActivePositionTicket))
         {
            if(PositionGetString(POSITION_SYMBOL) == _Symbol)
            {
               // Only create line if it doesn't already exist
               if(ObjectFind(0, g_ActiveSLLineName) < 0)
               {
                  CreateActiveSLLine(g_ActiveSLPrice);
                  Print("✓ Active SL line restored from file sync: ", DoubleToString(g_ActiveSLPrice, g_Digits));
               }
               else
               {
                  // Line exists, just update its price
                  ObjectSetDouble(0, g_ActiveSLLineName, OBJPROP_PRICE, g_ActiveSLPrice);
               }

               // Initialize SL price tracker to prevent false execution after sync
               g_LastActiveSLPriceCheck = g_ActiveSLPrice;
            }
         }
      }

      CalculateRisk();   // Recalculate to apply loaded global variables
      UpdateLines();     // Update line positions

      // Initialize TP price trackers to prevent false execution after sync
      // Must be AFTER CalculateRisk() which sets calc.partialTPX prices
      RiskCalculation calc = (inpDisplayMode == DISPLAY_CONSERVATIVE) ? g_ConservativeCalc : g_IdealCalc;
      g_LastTP1Price = calc.partialTP1Price;
      g_LastTP2Price = calc.partialTP2Price;
      g_LastTP3Price = calc.partialTP3Price;

      Print("Global variables reloaded from file at ", TimeToString(fileTime));
      Print("Price trackers initialized - TP1:", DoubleToString(g_LastTP1Price, g_Digits),
            ", TP2:", DoubleToString(g_LastTP2Price, g_Digits),
            ", TP3:", DoubleToString(g_LastTP3Price, g_Digits),
            ", ActiveSL:", DoubleToString(g_LastActiveSLPriceCheck, g_Digits));

      // Clear flag after reload complete
      g_IsReloadingFromFile = false;
   }
}

//+------------------------------------------------------------------+
//| Save Settings to .set File (MT5 Native Format)                   |
//+------------------------------------------------------------------+
void SaveToSetFile()
{
   if(inpExportDirectory == "")
   {
      Print("Export directory not configured");
      return;
   }

   // Generate filename with timestamp
   string timestamp = TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS);
   StringReplace(timestamp, ":", "-");
   StringReplace(timestamp, ".", "-");
   StringReplace(timestamp, " ", "_");

   string filename = inpExportDirectory + "\\FRTM-MT5_Settings_" + timestamp + ".set";

   int fileHandle = FileOpen(filename, FILE_WRITE|FILE_TXT|FILE_COMMON);
   if(fileHandle == INVALID_HANDLE)
   {
      Print("Failed to create .set file: ", filename, " Error: ", GetLastError());
      Comment("✗ Failed to create .set file");
      return;
   }

   // Header
   FileWriteString(fileHandle, "; saved automatically on " + TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS) + "\n");
   FileWriteString(fileHandle, "; this file contains input parameters for FRTM-MT5 EA\n");
   FileWriteString(fileHandle, ";\n");

   // Trade Management
   FileWriteString(fileHandle, "inpAccountMode=" + IntegerToString(inpAccountMode) + "||Y\n");
   FileWriteString(fileHandle, "inpPlaceSLOrder=" + (inpPlaceSLOrder ? "1" : "0") + "||Y\n");
   FileWriteString(fileHandle, "inpPlaceTPOrder=" + (inpPlaceTPOrder ? "1" : "0") + "||Y\n");
   FileWriteString(fileHandle, "inpBEOffsetPips=" + DoubleToString(inpBEOffsetPips, 2) + "||Y\n");
   FileWriteString(fileHandle, "inpTrailSLToNextTP=" + (inpTrailSLToNextTP ? "1" : "0") + "||Y\n");

   // Execute on Candle Close
   FileWriteString(fileHandle, "inpExecuteOnCandleClose=" + (inpExecuteOnCandleClose ? "1" : "0") + "||Y\n");
   FileWriteString(fileHandle, "inpCandleCloseAlert=" + (inpCandleCloseAlert ? "1" : "0") + "||Y\n");
   FileWriteString(fileHandle, "inpShowCandleTimer=" + (inpShowCandleTimer ? "1" : "0") + "||Y\n");

   // Stop Loss
   FileWriteString(fileHandle, "inpSLMode=" + IntegerToString(inpSLMode) + "||Y\n");
   FileWriteString(fileHandle, "inpManualSLPips=" + DoubleToString(inpManualSLPips, 1) + "||Y\n");
   FileWriteString(fileHandle, "inpTradeDirection=" + IntegerToString(inpTradeDirection) + "||Y\n");

   // Take Profit
   FileWriteString(fileHandle, "inpShowTP=" + (inpShowTP ? "1" : "0") + "||Y\n");

   // Partial Exits
   FileWriteString(fileHandle, "inpNumberOfLevels=" + IntegerToString(inpNumberOfLevels) + "||Y\n");
   FileWriteString(fileHandle, "inpExitPercent1=" + DoubleToString(inpExitPercent1, 1) + "||Y\n");
   FileWriteString(fileHandle, "inpExitPercent2=" + DoubleToString(inpExitPercent2, 1) + "||Y\n");

   // Account & Risk - Dynamic Risk Settings
   FileWriteString(fileHandle, "inpUseDynamicRisk=" + (inpUseDynamicRisk ? "1" : "0") + "||Y\n");
   FileWriteString(fileHandle, "inpUseDynamicAccountSize=" + (inpUseDynamicAccountSize ? "1" : "0") + "||Y\n");
   FileWriteString(fileHandle, "inpRiskFileCacheSeconds=" + IntegerToString(inpRiskFileCacheSeconds) + "||Y\n");
   FileWriteString(fileHandle, "inpManualRiskPercent=" + DoubleToString(inpManualRiskPercent, 2) + "||Y\n");
   FileWriteString(fileHandle, "inpManualAccountSize=" + DoubleToString(inpManualAccountSize, 2) + "||Y\n");
   FileWriteString(fileHandle, "inpMarginPercent=" + DoubleToString(inpMarginPercent, 2) + "||Y\n");
   FileWriteString(fileHandle, "inpCommissionPerLot=" + DoubleToString(inpCommissionPerLot, 2) + "||Y\n");
   FileWriteString(fileHandle, "inpPipValueMode=" + IntegerToString(inpPipValueMode) + "||Y\n");
   FileWriteString(fileHandle, "inpManualPipValue=" + DoubleToString(inpManualPipValue, 2) + "||Y\n");
   FileWriteString(fileHandle, "inpShowPipValue=" + (inpShowPipValue ? "1" : "0") + "||Y\n");

   // Slippage
   FileWriteString(fileHandle, "inpEntrySlippage=" + DoubleToString(inpEntrySlippage, 2) + "||Y\n");
   FileWriteString(fileHandle, "inpExitSlippage=" + DoubleToString(inpExitSlippage, 2) + "||Y\n");
   FileWriteString(fileHandle, "inpDisplayMode=" + IntegerToString(inpDisplayMode) + "||Y\n");
   FileWriteString(fileHandle, "inpShowAlternateLotSize=" + (inpShowAlternateLotSize ? "1" : "0") + "||Y\n");

   // Display
   FileWriteString(fileHandle, "inpShowPanel=" + (inpShowPanel ? "1" : "0") + "||Y\n");
   FileWriteString(fileHandle, "inpShowLines=" + (inpShowLines ? "1" : "0") + "||Y\n");
   FileWriteString(fileHandle, "inpShowEntryLine=" + (inpShowEntryLine ? "1" : "0") + "||Y\n");
   FileWriteString(fileHandle, "inpShowReturnOnMargin=" + (inpShowReturnOnMargin ? "1" : "0") + "||Y\n");

   // Panel Layout
   FileWriteString(fileHandle, "inpPanelX=" + IntegerToString(inpPanelX) + "||Y\n");
   FileWriteString(fileHandle, "inpPanelY=" + IntegerToString(inpPanelY) + "||Y\n");
   FileWriteString(fileHandle, "inpPanelWidth=" + IntegerToString(inpPanelWidth) + "||Y\n");
   FileWriteString(fileHandle, "inpPanelHeight=" + IntegerToString(inpPanelHeight) + "||Y\n");
   FileWriteString(fileHandle, "inpPanelPadding=" + IntegerToString(inpPanelPadding) + "||Y\n");
   FileWriteString(fileHandle, "inpRowHeight=" + IntegerToString(inpRowHeight) + "||Y\n");
   FileWriteString(fileHandle, "inpDividerLength=" + IntegerToString(inpDividerLength) + "||Y\n");
   FileWriteString(fileHandle, "inpFontSizeBold=" + IntegerToString(inpFontSizeBold) + "||Y\n");
   FileWriteString(fileHandle, "inpFontSizeNormal=" + IntegerToString(inpFontSizeNormal) + "||Y\n");

   // Colors
   FileWriteString(fileHandle, "inpPanelBgColor=" + IntegerToString(inpPanelBgColor) + "||Y\n");
   FileWriteString(fileHandle, "inpPanelTextColor=" + IntegerToString(inpPanelTextColor) + "||Y\n");
   FileWriteString(fileHandle, "inpSLLineColor=" + IntegerToString(inpSLLineColor) + "||Y\n");
   FileWriteString(fileHandle, "inpTPLineColor=" + IntegerToString(inpTPLineColor) + "||Y\n");
   FileWriteString(fileHandle, "inpEntryLineColor=" + IntegerToString(inpEntryLineColor) + "||Y\n");
   FileWriteString(fileHandle, "inpBELineColor=" + IntegerToString(inpBELineColor) + "||Y\n");
   FileWriteString(fileHandle, "inpActiveSLLineColor=" + IntegerToString(inpActiveSLLineColor) + "||Y\n");
   FileWriteString(fileHandle, "inpLabelPosition=" + IntegerToString(inpLabelPosition) + "||Y\n");

   // Buttons
   FileWriteString(fileHandle, "inpButtonWidth=" + IntegerToString(inpButtonWidth) + "||Y\n");
   FileWriteString(fileHandle, "inpButtonHeight=" + IntegerToString(inpButtonHeight) + "||Y\n");
   FileWriteString(fileHandle, "inpButtonSpacing=" + IntegerToString(inpButtonSpacing) + "||Y\n");
   FileWriteString(fileHandle, "inpBuyButtonColor=" + IntegerToString(inpBuyButtonColor) + "||Y\n");
   FileWriteString(fileHandle, "inpSellButtonColor=" + IntegerToString(inpSellButtonColor) + "||Y\n");
   FileWriteString(fileHandle, "inpMoveToBEButtonColor=" + IntegerToString(inpMoveToBEButtonColor) + "||Y\n");
   FileWriteString(fileHandle, "inpCloseAllButtonColor=" + IntegerToString(inpCloseAllButtonColor) + "||Y\n");

   // Export Directory
   FileWriteString(fileHandle, "inpExportDirectory=" + inpExportDirectory + "||Y\n");

   FileClose(fileHandle);

   string path = TerminalInfoString(TERMINAL_COMMONDATA_PATH) + "\\Files\\" + filename;
   Print("✓ Settings exported to .set file: ", path);
   Comment("✓ Settings exported to .set file!\n\n",
           "File: ", filename, "\n",
           "Location: MQL5\\Files\\Common\\\n\n",
           "To load:\n",
           "1. Right-click EA → Properties\n",
           "2. Click 'Load' button\n",
           "3. Select: ", filename);
}

//+------------------------------------------------------------------+
//| Draw Actual Order Lines (Entry & BE for placed orders)           |
//+------------------------------------------------------------------+
void DrawActualOrderLines()
{
   datetime currentTime = TimeCurrent();
   datetime futureTime = currentTime + PeriodSeconds(PERIOD_CURRENT) * 100;

   // Track which tickets we're drawing
   string existingTickets = "";

   // Loop through all positions
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket <= 0) continue;

      // Filter: only process positions for this symbol and magic number
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if(PositionGetInteger(POSITION_MAGIC) != 123456) continue;

      // Get position details
      double actualEntry = PositionGetDouble(POSITION_PRICE_OPEN);
      ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      string comment = PositionGetString(POSITION_COMMENT);

      // Parse BE pips from comment
      double actualBEPips = 0;
      int bePos = StringFind(comment, "|BE:");
      if(bePos >= 0)
      {
         string beStr = StringSubstr(comment, bePos + 4);
         actualBEPips = StringToDouble(beStr);
      }
      else
      {
         // Fallback: Calculate BE for old orders
         double actualLotSize = PositionGetDouble(POSITION_VOLUME);
         actualBEPips = CalculateBEPipsForOrder(actualLotSize);
      }

      // Add offset to BE
      double totalBEPips = actualBEPips + inpBEOffsetPips;

      // Calculate BE price
      double bePrice;
      if(posType == POSITION_TYPE_BUY)
         bePrice = actualEntry + (totalBEPips * g_PipValue);
      else
         bePrice = actualEntry - (totalBEPips * g_PipValue);

      // Create unique line names
      string entryLineName = "ActualEntry_" + IntegerToString(ticket);
      string beLineName = "ActualBE_" + IntegerToString(ticket);
      string entryLabelName = "ActualEntryLabel_" + IntegerToString(ticket);
      string beLabelName = "ActualBELabel_" + IntegerToString(ticket);

      existingTickets += IntegerToString(ticket) + ",";

      // Draw Actual Entry Line
      if(ObjectFind(0, entryLineName) < 0)
      {
         ObjectCreate(0, entryLineName, OBJ_TREND, 0, currentTime, actualEntry, futureTime, actualEntry);
         ObjectSetInteger(0, entryLineName, OBJPROP_COLOR, clrDodgerBlue);
         ObjectSetInteger(0, entryLineName, OBJPROP_WIDTH, 2);
         ObjectSetInteger(0, entryLineName, OBJPROP_STYLE, STYLE_SOLID);
         ObjectSetInteger(0, entryLineName, OBJPROP_RAY_RIGHT, true);
         ObjectSetInteger(0, entryLineName, OBJPROP_SELECTABLE, false);
         string typeStr = (posType == POSITION_TYPE_BUY) ? "BUY" : "SELL";
         ObjectSetString(0, entryLineName, OBJPROP_TEXT, "Entry #" + IntegerToString(ticket) + " (" + typeStr + ")");
      }
      else
      {
         ObjectMove(0, entryLineName, 0, currentTime, actualEntry);
         ObjectMove(0, entryLineName, 1, futureTime, actualEntry);
      }

      // Draw Entry Label
      if(ObjectFind(0, entryLabelName) < 0)
      {
         ObjectCreate(0, entryLabelName, OBJ_TEXT, 0, currentTime, actualEntry);
         ObjectSetInteger(0, entryLabelName, OBJPROP_COLOR, clrDodgerBlue);
         ObjectSetInteger(0, entryLabelName, OBJPROP_FONTSIZE, 8);
      }
      // Update label position and text using label position setting
      UpdateLabelPosition(entryLabelName, actualEntry, "ENTRY");

      // Draw Actual BE Line
      if(ObjectFind(0, beLineName) < 0)
      {
         ObjectCreate(0, beLineName, OBJ_TREND, 0, currentTime, bePrice, futureTime, bePrice);
         ObjectSetInteger(0, beLineName, OBJPROP_COLOR, clrGold);
         ObjectSetInteger(0, beLineName, OBJPROP_WIDTH, 2);
         ObjectSetInteger(0, beLineName, OBJPROP_STYLE, STYLE_DOT);
         ObjectSetInteger(0, beLineName, OBJPROP_RAY_RIGHT, true);
         ObjectSetInteger(0, beLineName, OBJPROP_SELECTABLE, false);
         ObjectSetString(0, beLineName, OBJPROP_TEXT, "BE #" + IntegerToString(ticket) + " (" + DoubleToString(totalBEPips, 2) + " pips)");
      }
      else
      {
         ObjectMove(0, beLineName, 0, currentTime, bePrice);
         ObjectMove(0, beLineName, 1, futureTime, bePrice);
      }

      // Draw BE Label
      if(ObjectFind(0, beLabelName) < 0)
      {
         ObjectCreate(0, beLabelName, OBJ_TEXT, 0, currentTime, bePrice);
         ObjectSetInteger(0, beLabelName, OBJPROP_COLOR, clrGold);
         ObjectSetInteger(0, beLabelName, OBJPROP_FONTSIZE, 8);
      }
      // Update BE label position and text using label position setting
      UpdateLabelPosition(beLabelName, bePrice, "BE");
   }

   // Clean up lines for closed positions
   for(int i = ObjectsTotal(0, 0, OBJ_TREND) - 1; i >= 0; i--)
   {
      string objName = ObjectName(0, i, 0, OBJ_TREND);

      // Check if it's an actual order line
      if(StringFind(objName, "ActualEntry_") == 0 || StringFind(objName, "ActualBE_") == 0)
      {
         // Extract ticket from name
         string ticketStr = "";
         if(StringFind(objName, "ActualEntry_") == 0)
            ticketStr = StringSubstr(objName, 12);  // Skip "ActualEntry_"
         else
            ticketStr = StringSubstr(objName, 9);   // Skip "ActualBE_"

         // If ticket not in existing list, delete the line
         if(StringFind(existingTickets, ticketStr + ",") < 0)
         {
            ObjectDelete(0, objName);
         }
      }
   }

   // Clean up labels for closed positions
   for(int i = ObjectsTotal(0, 0, OBJ_TEXT) - 1; i >= 0; i--)
   {
      string objName = ObjectName(0, i, 0, OBJ_TEXT);

      // Check if it's an actual order label
      if(StringFind(objName, "ActualEntryLabel_") == 0 || StringFind(objName, "ActualBELabel_") == 0)
      {
         // Extract ticket from name
         string ticketStr = "";
         if(StringFind(objName, "ActualEntryLabel_") == 0)
            ticketStr = StringSubstr(objName, 17);  // Skip "ActualEntryLabel_"
         else
            ticketStr = StringSubstr(objName, 14);  // Skip "ActualBELabel_"

         // If ticket not in existing list, delete the label
         if(StringFind(existingTickets, ticketStr + ",") < 0)
         {
            ObjectDelete(0, objName);
         }
      }
   }
}

//+------------------------------------------------------------------+
//| SUPERTREND FUNCTIONS - Last Level Management                     |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Calculate Supertrend values                                      |
//+------------------------------------------------------------------+
void CalculateSupertrend()
{
   if(!inpUseSupertrendOnLastLevel)
      return;

   //--- Get price data
   double high[], low[], close[];
   ArraySetAsSeries(high, true);
   ArraySetAsSeries(low, true);
   ArraySetAsSeries(close, true);

   if(CopyHigh(_Symbol, PERIOD_CURRENT, 0, inpSupertrendBarsToCalculate, high) <= 0) return;
   if(CopyLow(_Symbol, PERIOD_CURRENT, 0, inpSupertrendBarsToCalculate, low) <= 0) return;
   if(CopyClose(_Symbol, PERIOD_CURRENT, 0, inpSupertrendBarsToCalculate, close) <= 0) return;

   //--- Get ATR data
   double atr[];
   ArraySetAsSeries(atr, true);
   if(CopyBuffer(g_SupertrendATRHandle, 0, 0, inpSupertrendBarsToCalculate, atr) <= 0) return;

   //--- Calculate Supertrend
   for(int i = inpSupertrendBarsToCalculate - 1; i >= 0; i--)
   {
      double medianPrice = (high[i] + low[i]) / 2.0;

      // Calculate basic bands
      g_SupertrendUp[i] = medianPrice + (inpSupertrendATRMultiplier * atr[i]);
      g_SupertrendDn[i] = medianPrice - (inpSupertrendATRMultiplier * atr[i]);

      // Initialize trend for first bar
      if(i == inpSupertrendBarsToCalculate - 1)
      {
         g_SupertrendTrend[i] = 1;
      }
      else
      {
         // Determine trend direction
         if(close[i] > g_SupertrendUp[i + 1])
            g_SupertrendTrend[i] = 1;  // Uptrend
         else if(close[i] < g_SupertrendDn[i + 1])
            g_SupertrendTrend[i] = -1;  // Downtrend
         else if(g_SupertrendTrend[i + 1] == 1)
            g_SupertrendTrend[i] = 1;  // Continue uptrend
         else if(g_SupertrendTrend[i + 1] == -1)
            g_SupertrendTrend[i] = -1;  // Continue downtrend
         else
            g_SupertrendTrend[i] = 1;  // Default to uptrend

         // Apply trailing logic to bands
         bool trendChangedToDown = (g_SupertrendTrend[i] < 0) && (g_SupertrendTrend[i + 1] > 0);
         bool trendChangedToUp = (g_SupertrendTrend[i] > 0) && (g_SupertrendTrend[i + 1] < 0);

         // In uptrend: lower band trails up (never down)
         if((g_SupertrendTrend[i] > 0) && (g_SupertrendDn[i] < g_SupertrendDn[i + 1]))
            g_SupertrendDn[i] = g_SupertrendDn[i + 1];

         // In downtrend: upper band trails down (never up)
         if((g_SupertrendTrend[i] < 0) && (g_SupertrendUp[i] > g_SupertrendUp[i + 1]))
            g_SupertrendUp[i] = g_SupertrendUp[i + 1];

         // Reset bands on trend change
         if(trendChangedToDown)
            g_SupertrendUp[i] = medianPrice + (inpSupertrendATRMultiplier * atr[i]);

         if(trendChangedToUp)
            g_SupertrendDn[i] = medianPrice - (inpSupertrendATRMultiplier * atr[i]);
      }

      // Store the Supertrend value to plot
      if(g_SupertrendTrend[i] == 1)
         g_SupertrendValue[i] = g_SupertrendDn[i];  // Uptrend: plot lower band
      else
         g_SupertrendValue[i] = g_SupertrendUp[i];  // Downtrend: plot upper band
   }
}

//+------------------------------------------------------------------+
//| Check for positions that need immediate Supertrend management   |
//| (e.g., when 1 TP level configured, position managed from start) |
//+------------------------------------------------------------------+
void CheckPositionsForSupertrendManagement()
{
   // Only applies when TP1 is the last (and only) level AND auto-execute is enabled
   if(inpNumberOfLevels != 1 || !inpAutoExecuteTP)
      return;

   // Loop through all positions
   for(int i = 0; i < PositionsTotal(); i++)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket <= 0) continue;

      // Filter: only process positions for this symbol
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;

      // Check if already in Supertrend management
      bool alreadyManaged = false;
      int managedCount = ArraySize(g_SupertrendManagedPositions);
      for(int idx = 0; idx < managedCount; idx++)
      {
         if(g_SupertrendManagedPositions[idx] == ticket)
         {
            alreadyManaged = true;
            break;
         }
      }

      // If not already managed and TP1 hasn't been executed yet, add to Supertrend management
      if(!alreadyManaged && !HasExecutedTPLevel(ticket, 1))
      {
         AddSupertrendManagedPosition(ticket, "Immediate management (1 TP level configured)");
      }
   }
}

//+------------------------------------------------------------------+
//| Check for trend reversal and send BUY/SELL signals              |
//| Called only when a new bar forms (candle closed)                |
//+------------------------------------------------------------------+
void CheckSupertrendReversal()
{
   if(!inpUseSupertrendOnLastLevel)
      return;

   // Check the just-closed bar's trend (bar 1)
   int currentTrend = (int)g_SupertrendTrend[1];

   // Skip if this is first calculation
   if(g_SupertrendLastTrend == 0)
   {
      g_SupertrendLastTrend = currentTrend;
      return;
   }

   // Check if trend has changed on the closed candle
   if(currentTrend != g_SupertrendLastTrend)
   {
      // Auto-close opposing positions if in Auto-Close mode
      // Only notifications sent are from CloseSupertrendManagedPositions() when positions actually close
      if(!inpSupertrendTrailingStop)
      {
         CloseSupertrendManagedPositions(currentTrend);
      }

      // Update last trend
      g_SupertrendLastTrend = currentTrend;
   }
}

//+------------------------------------------------------------------+
//| Process Supertrend trailing stop (Broker-Based mode)            |
//+------------------------------------------------------------------+
void ProcessSupertrendTrailing()
{
   if(!inpUseSupertrendOnLastLevel || !inpSupertrendTrailingStop)
      return;

   // Get current Supertrend value (bar 0)
   double currentSupertrendValue = g_SupertrendValue[0];
   int currentTrend = (int)g_SupertrendTrend[0];

   if(currentSupertrendValue <= 0)
      return;

   //--- Loop through Supertrend-managed positions
   int managedCount = ArraySize(g_SupertrendManagedPositions);
   for(int idx = 0; idx < managedCount; idx++)
   {
      ulong ticket = g_SupertrendManagedPositions[idx];

      if(!PositionSelectByTicket(ticket))
         continue;

      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;

      ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      double currentSL = PositionGetDouble(POSITION_SL);
      double currentTP = PositionGetDouble(POSITION_TP);

      // Only trail positions in correct trend direction
      if(posType == POSITION_TYPE_BUY && currentTrend != 1)
         continue;  // Only trail BUY in uptrend

      if(posType == POSITION_TYPE_SELL && currentTrend != -1)
         continue;  // Only trail SELL in downtrend

      // New SL is the Supertrend value
      double newSL = NormalizeDouble(currentSupertrendValue, g_Digits);

      //--- Validate broker constraints
      double currentPrice;
      if(posType == POSITION_TYPE_BUY)
         currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      else
         currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_ASK);

      double stopLevel = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * SymbolInfoDouble(_Symbol, SYMBOL_POINT);

      if(posType == POSITION_TYPE_BUY)
      {
         // BUY: New SL must be below current price and above old SL
         if(newSL >= currentPrice - stopLevel)
            continue;

         if(currentSL > 0 && newSL <= currentSL)
            continue;
      }
      else
      {
         // SELL: New SL must be above current price and below old SL
         if(newSL <= currentPrice + stopLevel)
            continue;

         if(currentSL > 0 && newSL >= currentSL)
            continue;
      }

      //--- Modify position
      if(trade.PositionModify(ticket, newSL, currentTP))
      {
         double distancePips = MathAbs(currentPrice - newSL) / g_PipValue;
         Print("✓ Supertrend SL updated: ", _Symbol, " #", ticket,
               " | New SL: ", DoubleToString(newSL, g_Digits),
               " | Distance: ", DoubleToString(distancePips, 1), " pips",
               " | Trend: ", (currentTrend == 1 ? "UP" : "DOWN"));
      }
   }
}

//+------------------------------------------------------------------+
//| Close Supertrend-managed positions on reversal (Auto-Close mode)|
//+------------------------------------------------------------------+
void CloseSupertrendManagedPositions(int newTrend)
{
   int closedCount = 0;
   double totalVolume = 0;

   // Determine which position type to close
   ENUM_POSITION_TYPE typeToClose;
   string signalType;

   if(newTrend == 1)
   {
      // BUY signal - close SELL positions
      typeToClose = POSITION_TYPE_SELL;
      signalType = "BUY";
   }
   else
   {
      // SELL signal - close BUY positions
      typeToClose = POSITION_TYPE_BUY;
      signalType = "SELL";
   }

   // Loop through Supertrend-managed positions (backwards since we're closing)
   int managedCount = ArraySize(g_SupertrendManagedPositions);
   for(int idx = managedCount - 1; idx >= 0; idx--)
   {
      ulong ticket = g_SupertrendManagedPositions[idx];

      if(!PositionSelectByTicket(ticket))
         continue;

      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;

      ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      double volume = PositionGetDouble(POSITION_VOLUME);

      // Only close positions of the opposing type
      if(posType != typeToClose)
         continue;

      // Close the position
      if(trade.PositionClose(ticket))
      {
         closedCount++;
         totalVolume += volume;

         Print("✓ Closed ", (posType == POSITION_TYPE_BUY ? "BUY" : "SELL"),
               " position #", ticket, " | ", _Symbol,
               " | Volume: ", DoubleToString(volume, 2), " lots");

         // Remove from managed array
         RemoveSupertrendManagedPosition(ticket);
      }
      else
      {
         Print("✗ Failed to close position #", ticket, " | Error: ", trade.ResultRetcodeDescription());
      }
   }

   if(closedCount > 0)
   {
      Print("──────────────────────────────────────");
      Print("SUPERTREND AUTO-CLOSE SUMMARY:");
      Print("  Signal: ", signalType);
      Print("  Positions Closed: ", closedCount);
      Print("  Total Volume: ", DoubleToString(totalVolume, 2), " lots");
      Print("──────────────────────────────────────");

      // Send notification about auto-close (only when positions actually closed)
      if(inpSupertrendEnableNotifications)
      {
         string message = "🔄 SUPERTREND CLOSED " + IntegerToString(closedCount) + " position(s) | " +
                         _Symbol + " | " + signalType + " signal" +
                         " | Volume: " + DoubleToString(totalVolume, 2) + " lots";

         if(inpSupertrendSendAlert)
            Alert(message);

         if(inpSupertrendSendPush)
            SendNotification(message);

         if(inpSupertrendSendEmail)
            SendMail("Supertrend Closed Trade - " + _Symbol, message);
      }
   }
   // No notification if no positions were closed (silent operation)
}

//+------------------------------------------------------------------+
//| Draw Supertrend line on chart                                    |
//+------------------------------------------------------------------+
void DrawSupertrendLine()
{
   if(!inpUseSupertrendOnLastLevel || !inpShowSupertrendLine)
      return;

   // Delete old line objects
   DeleteSupertrendLines();

   datetime time[];
   ArraySetAsSeries(time, true);
   if(CopyTime(_Symbol, PERIOD_CURRENT, 0, inpSupertrendBarsToCalculate, time) <= 0)
      return;

   // Draw line segments connecting Supertrend points
   int drawBars = MathMin(inpSupertrendBarsToCalculate, 100); // Limit to recent 100 bars for performance

   for(int i = drawBars - 1; i > 0; i--)
   {
      string objName = g_SupertrendLinePrefix + IntegerToString(i);

      // Determine color based on trend
      color lineColor = (g_SupertrendTrend[i] == 1) ? inpSupertrendUptrendColor : inpSupertrendDowntrendColor;

      // Create trend line segment
      if(ObjectCreate(0, objName, OBJ_TREND, 0, time[i], g_SupertrendValue[i], time[i-1], g_SupertrendValue[i-1]))
      {
         ObjectSetInteger(0, objName, OBJPROP_COLOR, lineColor);
         ObjectSetInteger(0, objName, OBJPROP_WIDTH, inpSupertrendLineWidth);
         ObjectSetInteger(0, objName, OBJPROP_STYLE, STYLE_SOLID);
         ObjectSetInteger(0, objName, OBJPROP_RAY_RIGHT, false);
         ObjectSetInteger(0, objName, OBJPROP_RAY_LEFT, false);
         ObjectSetInteger(0, objName, OBJPROP_BACK, false);
         ObjectSetInteger(0, objName, OBJPROP_SELECTABLE, false);
         ObjectSetInteger(0, objName, OBJPROP_HIDDEN, true);
      }
   }
}

//+------------------------------------------------------------------+
//| Delete all Supertrend line objects                               |
//+------------------------------------------------------------------+
void DeleteSupertrendLines()
{
   for(int i = ObjectsTotal(0, 0, OBJ_TREND) - 1; i >= 0; i--)
   {
      string objName = ObjectName(0, i, 0, OBJ_TREND);
      if(StringFind(objName, g_SupertrendLinePrefix) == 0)
         ObjectDelete(0, objName);
   }
}

//+------------------------------------------------------------------+
//| Check if position is managed by Supertrend                       |
//+------------------------------------------------------------------+
bool IsPositionManagedBySupertrend(ulong ticket)
{
   int size = ArraySize(g_SupertrendManagedPositions);
   for(int i = 0; i < size; i++)
   {
      if(g_SupertrendManagedPositions[i] == ticket)
         return true;
   }
   return false;
}

//+------------------------------------------------------------------+
//| Add position to Supertrend management array                      |
//+------------------------------------------------------------------+
void AddSupertrendManagedPosition(ulong ticket, string reason = "")
{
   int size = ArraySize(g_SupertrendManagedPositions);

   // Check if already in array
   for(int i = 0; i < size; i++)
   {
      if(g_SupertrendManagedPositions[i] == ticket)
         return;
   }

   // Add to array
   ArrayResize(g_SupertrendManagedPositions, size + 1);
   g_SupertrendManagedPositions[size] = ticket;

   Print("✓ Position #", ticket, " added to Supertrend management", (reason != "" ? " - " + reason : ""));
   Print("  Current TP Levels: ", inpNumberOfLevels, " | Auto-Execute: ", (inpAutoExecuteTP ? "ON" : "OFF"));
}

//+------------------------------------------------------------------+
//| Remove position from Supertrend management array                 |
//+------------------------------------------------------------------+
void RemoveSupertrendManagedPosition(ulong ticket)
{
   int size = ArraySize(g_SupertrendManagedPositions);

   for(int i = 0; i < size; i++)
   {
      if(g_SupertrendManagedPositions[i] == ticket)
      {
         // Shift remaining elements
         for(int j = i; j < size - 1; j++)
         {
            g_SupertrendManagedPositions[j] = g_SupertrendManagedPositions[j + 1];
         }

         // Resize array
         ArrayResize(g_SupertrendManagedPositions, size - 1);
         Print("✓ Position #", ticket, " removed from Supertrend management");
         return;
      }
   }
}

//+------------------------------------------------------------------+
//| Clean up closed positions from Supertrend management array      |
//+------------------------------------------------------------------+
void CleanupClosedSupertrendPositions()
{
   int size = ArraySize(g_SupertrendManagedPositions);

   // Loop backwards to safely remove items during iteration
   for(int i = size - 1; i >= 0; i--)
   {
      ulong ticket = g_SupertrendManagedPositions[i];

      // Check if position still exists
      if(!PositionSelectByTicket(ticket))
      {
         // Position closed - remove from array
         RemoveSupertrendManagedPosition(ticket);
      }
   }
}

//+------------------------------------------------------------------+
//| CForexTradeManagerDialog Implementation                           |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Create Dialog and Controls                                       |
//+------------------------------------------------------------------+
bool CForexTradeManagerDialog::Create(const long chart, const string name, const int subwin,
                                        const int x1, const int y1, const int x2, const int y2)
{
    // Create the dialog base
    if(!CAppDialog::Create(chart, name, subwin, x1, y1, x2, y2))
        return false;

    // Set dialog caption
    Caption("FOREX TRADE MANAGER");

    // Create all controls
    if(!CreateControls())
        return false;

    // Run the dialog
    Run();

    // Initialize state as visible after creation
    m_isDialogVisible = true;

    return true;
}

//+------------------------------------------------------------------+
//| Event Handler                                                     |
//+------------------------------------------------------------------+
bool CForexTradeManagerDialog::OnEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
{
    // Handle button clicks
    if(id == CHARTEVENT_CUSTOM + ON_CLICK)
    {
        if(lparam == m_btn_buy.Id())
        {
            Print("Buy button clicked in dialog");
            m_buyRequested = true;
            return true;
        }
        else if(lparam == m_btn_sell.Id())
        {
            Print("Sell button clicked in dialog");
            m_sellRequested = true;
            return true;
        }
        else if(lparam == m_btn_breakeven.Id())
        {
            Print("Breakeven button clicked in dialog");
            m_breakevenRequested = true;
            return true;
        }
        else if(lparam == m_btn_closeAll.Id())
        {
            Print("Close All button clicked in dialog");
            m_closeAllRequested = true;
            return true;
        }
    }

    // Let base class handle other events (including dragging)
    return CAppDialog::OnEvent(id, lparam, dparam, sparam);
}

//+------------------------------------------------------------------+
//| Override OnShow to ensure proper visibility management            |
//+------------------------------------------------------------------+
bool CForexTradeManagerDialog::OnShow(void)
{
    // Call base class method first
    bool result = CAppDialog::OnShow();

    if(result) {
        m_isDialogVisible = true;
        // Ensure all controls are properly visible when dialog is shown
        RefreshDisplay();
    }

    return result;
}

//+------------------------------------------------------------------+
//| Override OnHide to ensure proper cleanup when dialog is hidden     |
//+------------------------------------------------------------------+
bool CForexTradeManagerDialog::OnHide(void)
{
    // Mark dialog as hidden
    m_isDialogVisible = false;

    // Hide all controls to prevent artifacts on chart
    HideAllControls();

    // Call base class method
    return CAppDialog::OnHide();
}

//+------------------------------------------------------------------+
//| Override OnChange to handle size changes                           |
//+------------------------------------------------------------------+
bool CForexTradeManagerDialog::OnChange(void)
{
    // Call base class method first
    bool result = CAppDialog::OnChange();

    if(result && m_isDialogVisible) {
        // Refresh display when dialog size changes
        RefreshDisplay();
    }

    return result;
}

//+------------------------------------------------------------------+
//| Hide all controls to prevent artifacts when dialog is hidden       |
//+------------------------------------------------------------------+
void CForexTradeManagerDialog::HideAllControls(void)
{
    // Hide all label controls
    m_label_lotSize.Hide();
    m_label_lotSizeValue.Hide();
    m_label_riskSource.Hide();
    m_label_riskSourceValue.Hide();
    m_label_accountSource.Hide();
    m_label_accountSourceValue.Hide();
    m_label_divider1.Hide();
    m_label_sl.Hide();
    m_label_slValue.Hide();
    m_label_totalRiskPips.Hide();
    m_label_totalRiskPipsValue.Hide();
    m_label_breakeven.Hide();
    m_label_breakevenValue.Hide();
    m_label_divider2.Hide();
    m_label_totalRisk.Hide();
    m_label_totalRiskValue.Hide();
    m_label_riskPercent.Hide();
    m_label_riskPercentValue.Hide();

    // Hide Phase 2 controls
    m_label_altLotSize.Hide();
    m_label_altLotSizeValue.Hide();
    m_label_pipValue.Hide();
    m_label_pipValueValue.Hide();
    m_label_tp.Hide();
    m_label_tpValue.Hide();
    m_label_partialTitle.Hide();
    m_label_level1Label.Hide();
    m_label_level1Pips.Hide();
    m_label_level1Net.Hide();
    m_label_level2Label.Hide();
    m_label_level2Pips.Hide();
    m_label_level2Net.Hide();
    m_label_level3Label.Hide();
    m_label_level3Pips.Hide();
    m_label_level3Net.Hide();
    m_label_partialTotalLabel.Hide();
    m_label_partialTotalValue.Hide();
    m_label_priceRisk.Hide();
    m_label_priceRiskValue.Hide();
    m_label_commission.Hide();
    m_label_commissionValue.Hide();
    m_label_spreadCost.Hide();
    m_label_spreadCostValue.Hide();
    m_label_divider3.Hide();
    m_label_margin.Hide();
    m_label_marginValue.Hide();
    m_label_buyingPower.Hide();
    m_label_buyingPowerValue.Hide();
    m_label_rom.Hide();
    m_label_romValue.Hide();
}

//+------------------------------------------------------------------+
//| Show all controls that should be visible                           |
//+------------------------------------------------------------------+
void CForexTradeManagerDialog::ShowAllControls(void)
{
    // Show all controls based on current settings
    // This will be handled by UpdateDisplay method
    RefreshDisplay();
}

//+------------------------------------------------------------------+
//| Refresh display with current data and settings                     |
//+------------------------------------------------------------------+
void CForexTradeManagerDialog::RefreshDisplay(void)
{
    if(!m_isDialogVisible) return;

    // Update display with current data
    if(IsTradeManagementMode()) {
        UpdateDisplay(g_IdealCalc, true);
    } else {
        UpdateDisplay(g_IdealCalc, false);
    }
}

//+------------------------------------------------------------------+
//| Create Controls                                                   |
//+------------------------------------------------------------------+
bool CForexTradeManagerDialog::CreateControls()
{
    if(!CreateLabels()) return false;
    if(!CreateButtons()) return false;
    return true;
}

//+------------------------------------------------------------------+
//| Create Labels                                                     |
//+------------------------------------------------------------------+
bool CForexTradeManagerDialog::CreateLabels()
{
    int yPos = 10;
    int lineHeight = 18;
    int xPos = 10;
    int labelWidth = 170;
    int valueWidth = 100;
    int valueXPos = xPos + labelWidth + 10;

    // Lot Size
    if(!m_label_lotSize.Create(m_chart_id, m_name + "LblLotSize", m_subwin, xPos, yPos, xPos + labelWidth, yPos + 15))
        return false;
    m_label_lotSize.Text("Lot Size:");
    m_label_lotSize.FontSize(inpFontSizeBold);
    m_label_lotSize.Color(inpPanelTextColor);
    if(!Add(m_label_lotSize)) return false;

    if(!m_label_lotSizeValue.Create(m_chart_id, m_name + "LblLotSizeValue", m_subwin, valueXPos, yPos, valueXPos + valueWidth, yPos + 15))
        return false;
    m_label_lotSizeValue.Text("0.00");
    m_label_lotSizeValue.FontSize(inpFontSizeBold);
    m_label_lotSizeValue.Color(clrBlue);
    if(!Add(m_label_lotSizeValue)) return false;
    yPos += lineHeight;

    // Risk Source
    if(!m_label_riskSource.Create(m_chart_id, m_name + "LblRiskSource", m_subwin, xPos, yPos, xPos + labelWidth, yPos + 15))
        return false;
    m_label_riskSource.Text("Risk Source:");
    m_label_riskSource.FontSize(inpFontSizeNormal);
    m_label_riskSource.Color(inpPanelTextColor);
    if(!Add(m_label_riskSource)) return false;

    if(!m_label_riskSourceValue.Create(m_chart_id, m_name + "LblRiskSourceValue", m_subwin, valueXPos, yPos, valueXPos + valueWidth, yPos + 15))
        return false;
    m_label_riskSourceValue.Text("Manual");
    m_label_riskSourceValue.FontSize(inpFontSizeNormal);
    m_label_riskSourceValue.Color(clrDodgerBlue);
    if(!Add(m_label_riskSourceValue)) return false;
    yPos += lineHeight;

    // Account Source
    if(!m_label_accountSource.Create(m_chart_id, m_name + "LblAccountSource", m_subwin, xPos, yPos, xPos + labelWidth, yPos + 15))
        return false;
    m_label_accountSource.Text("Account Source:");
    m_label_accountSource.FontSize(inpFontSizeNormal);
    m_label_accountSource.Color(inpPanelTextColor);
    if(!Add(m_label_accountSource)) return false;

    if(!m_label_accountSourceValue.Create(m_chart_id, m_name + "LblAccountSourceValue", m_subwin, valueXPos, yPos, valueXPos + valueWidth, yPos + 15))
        return false;
    m_label_accountSourceValue.Text("Manual");
    m_label_accountSourceValue.FontSize(inpFontSizeNormal);
    m_label_accountSourceValue.Color(clrDodgerBlue);
    if(!Add(m_label_accountSourceValue)) return false;
    yPos += lineHeight;

    // Divider 1
    yPos += lineHeight/2;  // Extra spacing
    if(!m_label_divider1.Create(m_chart_id, m_name + "LblDivider1", m_subwin, xPos, yPos, xPos + labelWidth + valueWidth + 10, yPos + 15))
        return false;
    m_label_divider1.Text("────────────");
    m_label_divider1.FontSize(inpFontSizeNormal);
    m_label_divider1.Color(clrGray);
    if(!Add(m_label_divider1)) return false;
    yPos += lineHeight;

    // Base SL
    if(!m_label_sl.Create(m_chart_id, m_name + "LblSL", m_subwin, xPos, yPos, xPos + labelWidth, yPos + 15))
        return false;
    m_label_sl.Text("Base SL:");
    m_label_sl.FontSize(inpFontSizeNormal);
    m_label_sl.Color(inpPanelTextColor);
    if(!Add(m_label_sl)) return false;

    if(!m_label_slValue.Create(m_chart_id, m_name + "LblSLValue", m_subwin, valueXPos, yPos, valueXPos + valueWidth, yPos + 15))
        return false;
    m_label_slValue.Text("0.0 pips");
    m_label_slValue.FontSize(inpFontSizeNormal);
    m_label_slValue.Color(clrRed);
    if(!Add(m_label_slValue)) return false;
    yPos += lineHeight;

    // Total Risk Distance
    if(!m_label_totalRiskPips.Create(m_chart_id, m_name + "LblTotalRiskPips", m_subwin, xPos, yPos, xPos + labelWidth, yPos + 15))
        return false;
    m_label_totalRiskPips.Text("Total Risk Distance:");
    m_label_totalRiskPips.FontSize(inpFontSizeNormal);
    m_label_totalRiskPips.Color(inpPanelTextColor);
    if(!Add(m_label_totalRiskPips)) return false;

    if(!m_label_totalRiskPipsValue.Create(m_chart_id, m_name + "LblTotalRiskPipsValue", m_subwin, valueXPos, yPos, valueXPos + valueWidth, yPos + 15))
        return false;
    m_label_totalRiskPipsValue.Text("0.0 pips");
    m_label_totalRiskPipsValue.FontSize(inpFontSizeNormal);
    m_label_totalRiskPipsValue.Color(clrRed);
    if(!Add(m_label_totalRiskPipsValue)) return false;
    yPos += lineHeight;

    // Break-even
    if(!m_label_breakeven.Create(m_chart_id, m_name + "LblBE", m_subwin, xPos, yPos, xPos + labelWidth, yPos + 15))
        return false;
    m_label_breakeven.Text("Break-even:");
    m_label_breakeven.FontSize(inpFontSizeNormal);
    m_label_breakeven.Color(inpPanelTextColor);
    if(!Add(m_label_breakeven)) return false;

    if(!m_label_breakevenValue.Create(m_chart_id, m_name + "LblBEValue", m_subwin, valueXPos, yPos, valueXPos + valueWidth, yPos + 15))
        return false;
    m_label_breakevenValue.Text("0.0 pips");
    m_label_breakevenValue.FontSize(inpFontSizeNormal);
    m_label_breakevenValue.Color(inpPanelTextColor);
    if(!Add(m_label_breakevenValue)) return false;
    yPos += lineHeight;

    // Divider 2
    yPos += lineHeight/2;  // Extra spacing
    if(!m_label_divider2.Create(m_chart_id, m_name + "LblDivider2", m_subwin, xPos, yPos, xPos + labelWidth + valueWidth + 10, yPos + 15))
        return false;
    m_label_divider2.Text("────────────");
    m_label_divider2.FontSize(inpFontSizeNormal);
    m_label_divider2.Color(clrGray);
    if(!Add(m_label_divider2)) return false;
    yPos += lineHeight;

    // Total Risk
    if(!m_label_totalRisk.Create(m_chart_id, m_name + "LblTotalRisk", m_subwin, xPos, yPos, xPos + labelWidth, yPos + 15))
        return false;
    m_label_totalRisk.Text("Total Risk:");
    m_label_totalRisk.FontSize(inpFontSizeBold);
    m_label_totalRisk.Color(inpPanelTextColor);
    if(!Add(m_label_totalRisk)) return false;

    if(!m_label_totalRiskValue.Create(m_chart_id, m_name + "LblTotalRiskValue", m_subwin, valueXPos, yPos, valueXPos + valueWidth, yPos + 15))
        return false;
    m_label_totalRiskValue.Text("$0.00");
    m_label_totalRiskValue.FontSize(inpFontSizeBold);
    m_label_totalRiskValue.Color(clrRed);
    if(!Add(m_label_totalRiskValue)) return false;
    yPos += lineHeight;

    // Risk Percent
    if(!m_label_riskPercent.Create(m_chart_id, m_name + "LblRiskPercent", m_subwin, xPos, yPos, xPos + labelWidth, yPos + 15))
        return false;
    m_label_riskPercent.Text("Actual Risk %:");
    m_label_riskPercent.FontSize(inpFontSizeNormal);
    m_label_riskPercent.Color(inpPanelTextColor);
    if(!Add(m_label_riskPercent)) return false;

    if(!m_label_riskPercentValue.Create(m_chart_id, m_name + "LblRiskPercentValue", m_subwin, valueXPos, yPos, valueXPos + valueWidth, yPos + 15))
        return false;
    m_label_riskPercentValue.Text("0.00%");
    m_label_riskPercentValue.FontSize(inpFontSizeNormal);
    m_label_riskPercentValue.Color(clrRed);
    if(!Add(m_label_riskPercentValue)) return false;

    // Phase 2: Create Additional Controls (~35 labels)

    // Alternate Lot Size (Conditional on inpShowAlternateLotSize)
    if(!m_label_altLotSize.Create(m_chart_id, m_name + "LblAltLotSize", m_subwin, xPos, yPos, xPos + labelWidth, yPos + 15))
        return false;
    m_label_altLotSize.Text("Lot Size (Alternate):");
    m_label_altLotSize.FontSize(inpFontSizeNormal);
    m_label_altLotSize.Color(inpPanelTextColor);
    if(!Add(m_label_altLotSize)) return false;

    if(!m_label_altLotSizeValue.Create(m_chart_id, m_name + "LblAltLotSizeValue", m_subwin, valueXPos, yPos, valueXPos + valueWidth, yPos + 15))
        return false;
    m_label_altLotSizeValue.Text("0.00");
    m_label_altLotSizeValue.FontSize(inpFontSizeNormal);
    m_label_altLotSizeValue.Color(inpPanelTextColor);
    if(!Add(m_label_altLotSizeValue)) return false;
    yPos += lineHeight;

    // Pip Value (Conditional on inpShowPipValue)
    if(!m_label_pipValue.Create(m_chart_id, m_name + "LblPipValue", m_subwin, xPos, yPos, xPos + labelWidth, yPos + 15))
        return false;
    m_label_pipValue.Text("Pip Value:");
    m_label_pipValue.FontSize(inpFontSizeNormal);
    m_label_pipValue.Color(inpPanelTextColor);
    if(!Add(m_label_pipValue)) return false;

    if(!m_label_pipValueValue.Create(m_chart_id, m_name + "LblPipValueValue", m_subwin, valueXPos, yPos, valueXPos + valueWidth, yPos + 15))
        return false;
    m_label_pipValueValue.Text("$0.00");
    m_label_pipValueValue.FontSize(inpFontSizeNormal);
    m_label_pipValueValue.Color(inpPanelTextColor);
    if(!Add(m_label_pipValueValue)) return false;
    yPos += lineHeight;

    // Partial Exits Summary (Conditional on inpShowTP)
    if(!m_label_tp.Create(m_chart_id, m_name + "LblTP", m_subwin, xPos, yPos, xPos + labelWidth, yPos + 15))
        return false;
    m_label_tp.Text("Partial Exits:");
    m_label_tp.FontSize(inpFontSizeNormal);
    m_label_tp.Color(inpPanelTextColor);
    if(!Add(m_label_tp)) return false;

    if(!m_label_tpValue.Create(m_chart_id, m_name + "LblTPValue", m_subwin, valueXPos, yPos, valueXPos + valueWidth, yPos + 15))
        return false;
    m_label_tpValue.Text("0 Levels");
    m_label_tpValue.FontSize(inpFontSizeNormal);
    m_label_tpValue.Color(clrGreen);
    if(!Add(m_label_tpValue)) return false;
    yPos += lineHeight;

    // Partial Exits Detailed Breakdown (Conditional on inpShowTP)
    if(!m_label_partialTitle.Create(m_chart_id, m_name + "LblPartialTitle", m_subwin, xPos, yPos + 5, xPos + labelWidth + valueWidth + 10, yPos + 15))
        return false;
    m_label_partialTitle.Text("Partial Exits Breakdown:");
    m_label_partialTitle.FontSize(inpFontSizeNormal);
    m_label_partialTitle.Color(inpPanelTextColor);
    if(!Add(m_label_partialTitle)) return false;
    yPos += lineHeight + 5;

    // Level 1 (always shown when TP is enabled)
    if(!m_label_level1Label.Create(m_chart_id, m_name + "LblLevel1Label", m_subwin, xPos + 20, yPos, xPos + 120, yPos + 15))
        return false;
    m_label_level1Label.Text("L1:");
    m_label_level1Label.FontSize(inpFontSizeNormal);
    m_label_level1Label.Color(inpPanelTextColor);
    if(!Add(m_label_level1Label)) return false;

    if(!m_label_level1Pips.Create(m_chart_id, m_name + "LblLevel1Pips", m_subwin, xPos + 90, yPos, xPos + 150, yPos + 15))
        return false;
    m_label_level1Pips.Text("0 pips");
    m_label_level1Pips.FontSize(inpFontSizeNormal);
    m_label_level1Pips.Color(inpPanelTextColor);
    if(!Add(m_label_level1Pips)) return false;

    if(!m_label_level1Net.Create(m_chart_id, m_name + "LblLevel1Net", m_subwin, valueXPos, yPos, valueXPos + valueWidth, yPos + 15))
        return false;
    m_label_level1Net.Text("$0.00");
    m_label_level1Net.FontSize(inpFontSizeNormal);
    m_label_level1Net.Color(clrGreen);
    if(!Add(m_label_level1Net)) return false;
    yPos += lineHeight;

    // Level 2 (Conditional on inpNumberOfLevels >= 2)
    if(!m_label_level2Label.Create(m_chart_id, m_name + "LblLevel2Label", m_subwin, xPos + 20, yPos, xPos + 120, yPos + 15))
        return false;
    m_label_level2Label.Text("L2:");
    m_label_level2Label.FontSize(inpFontSizeNormal);
    m_label_level2Label.Color(inpPanelTextColor);
    if(!Add(m_label_level2Label)) return false;

    if(!m_label_level2Pips.Create(m_chart_id, m_name + "LblLevel2Pips", m_subwin, xPos + 90, yPos, xPos + 150, yPos + 15))
        return false;
    m_label_level2Pips.Text("0 pips");
    m_label_level2Pips.FontSize(inpFontSizeNormal);
    m_label_level2Pips.Color(inpPanelTextColor);
    if(!Add(m_label_level2Pips)) return false;

    if(!m_label_level2Net.Create(m_chart_id, m_name + "LblLevel2Net", m_subwin, valueXPos, yPos, valueXPos + valueWidth, yPos + 15))
        return false;
    m_label_level2Net.Text("$0.00");
    m_label_level2Net.FontSize(inpFontSizeNormal);
    m_label_level2Net.Color(clrGreen);
    if(!Add(m_label_level2Net)) return false;
    yPos += lineHeight;

    // Level 3 (Conditional on inpNumberOfLevels == 3)
    if(!m_label_level3Label.Create(m_chart_id, m_name + "LblLevel3Label", m_subwin, xPos + 20, yPos, xPos + 120, yPos + 15))
        return false;
    m_label_level3Label.Text("L3:");
    m_label_level3Label.FontSize(inpFontSizeNormal);
    m_label_level3Label.Color(inpPanelTextColor);
    if(!Add(m_label_level3Label)) return false;

    if(!m_label_level3Pips.Create(m_chart_id, m_name + "LblLevel3Pips", m_subwin, xPos + 90, yPos, xPos + 150, yPos + 15))
        return false;
    m_label_level3Pips.Text("0 pips");
    m_label_level3Pips.FontSize(inpFontSizeNormal);
    m_label_level3Pips.Color(inpPanelTextColor);
    if(!Add(m_label_level3Pips)) return false;

    if(!m_label_level3Net.Create(m_chart_id, m_name + "LblLevel3Net", m_subwin, valueXPos, yPos, valueXPos + valueWidth, yPos + 15))
        return false;
    m_label_level3Net.Text("$0.00");
    m_label_level3Net.FontSize(inpFontSizeNormal);
    m_label_level3Net.Color(clrGreen);
    if(!Add(m_label_level3Net)) return false;
    yPos += lineHeight;

    // Partial Total
    if(!m_label_partialTotalLabel.Create(m_chart_id, m_name + "LblPartialTotalLabel", m_subwin, xPos, yPos, xPos + labelWidth, yPos + 15))
        return false;
    m_label_partialTotalLabel.Text("Total Net P&L:");
    m_label_partialTotalLabel.FontSize(inpFontSizeBold);
    m_label_partialTotalLabel.Color(inpPanelTextColor);
    if(!Add(m_label_partialTotalLabel)) return false;

    if(!m_label_partialTotalValue.Create(m_chart_id, m_name + "LblPartialTotalValue", m_subwin, valueXPos, yPos, valueXPos + valueWidth, yPos + 15))
        return false;
    m_label_partialTotalValue.Text("$0.00");
    m_label_partialTotalValue.FontSize(inpFontSizeBold);
    m_label_partialTotalValue.Color(clrGreen);
    if(!Add(m_label_partialTotalValue)) return false;
    yPos += lineHeight;

    // Additional Risk Details
    if(!m_label_priceRisk.Create(m_chart_id, m_name + "LblPriceRisk", m_subwin, xPos, yPos, xPos + labelWidth, yPos + 15))
        return false;
    m_label_priceRisk.Text("Price Risk:");
    m_label_priceRisk.FontSize(inpFontSizeNormal);
    m_label_priceRisk.Color(inpPanelTextColor);
    if(!Add(m_label_priceRisk)) return false;

    if(!m_label_priceRiskValue.Create(m_chart_id, m_name + "LblPriceRiskValue", m_subwin, valueXPos, yPos, valueXPos + valueWidth, yPos + 15))
        return false;
    m_label_priceRiskValue.Text("$0.00");
    m_label_priceRiskValue.FontSize(inpFontSizeNormal);
    m_label_priceRiskValue.Color(inpPanelTextColor);
    if(!Add(m_label_priceRiskValue)) return false;
    yPos += lineHeight;

    if(!m_label_commission.Create(m_chart_id, m_name + "LblComm", m_subwin, xPos, yPos, xPos + labelWidth, yPos + 15))
        return false;
    m_label_commission.Text("Commission:");
    m_label_commission.FontSize(inpFontSizeNormal);
    m_label_commission.Color(inpPanelTextColor);
    if(!Add(m_label_commission)) return false;

    if(!m_label_commissionValue.Create(m_chart_id, m_name + "LblCommValue", m_subwin, valueXPos, yPos, valueXPos + valueWidth, yPos + 15))
        return false;
    m_label_commissionValue.Text("$0.00");
    m_label_commissionValue.FontSize(inpFontSizeNormal);
    m_label_commissionValue.Color(inpPanelTextColor);
    if(!Add(m_label_commissionValue)) return false;

    // Spread Cost (Conditional on inpShowSpreadCost)
    if(!m_label_spreadCost.Create(m_chart_id, m_name + "LblSpreadCost", m_subwin, xPos, yPos, xPos + labelWidth, yPos + 15))
        return false;
    m_label_spreadCost.Text("Spread Cost:");
    m_label_spreadCost.FontSize(inpFontSizeNormal);
    m_label_spreadCost.Color(inpPanelTextColor);
    if(!Add(m_label_spreadCost)) return false;

    if(!m_label_spreadCostValue.Create(m_chart_id, m_name + "LblSpreadCostValue", m_subwin, valueXPos, yPos, valueXPos + valueWidth, yPos + 15))
        return false;
    m_label_spreadCostValue.Text("$0.00");
    m_label_spreadCostValue.FontSize(inpFontSizeNormal);
    m_label_spreadCostValue.Color(inpPanelTextColor);
    if(!Add(m_label_spreadCostValue)) return false;
    yPos += lineHeight;

    // Margin Information
    yPos += lineHeight/2;  // Extra spacing before divider
    if(!m_label_divider3.Create(m_chart_id, m_name + "LblDivider3", m_subwin, xPos, yPos, xPos + labelWidth + valueWidth + 10, yPos + 15))
        return false;
    m_label_divider3.Text("────────────");
    m_label_divider3.FontSize(inpFontSizeNormal);
    m_label_divider3.Color(clrGray);
    if(!Add(m_label_divider3)) return false;
    yPos += lineHeight;

    if(!m_label_margin.Create(m_chart_id, m_name + "LblMargin", m_subwin, xPos, yPos, xPos + labelWidth, yPos + 15))
        return false;
    m_label_margin.Text("Margin Required:");
    m_label_margin.FontSize(inpFontSizeNormal);
    m_label_margin.Color(inpPanelTextColor);
    if(!Add(m_label_margin)) return false;

    if(!m_label_marginValue.Create(m_chart_id, m_name + "LblMarginValue", m_subwin, valueXPos, yPos, valueXPos + valueWidth, yPos + 15))
        return false;
    m_label_marginValue.Text("$0.00");
    m_label_marginValue.FontSize(inpFontSizeNormal);
    m_label_marginValue.Color(inpPanelTextColor);
    if(!Add(m_label_marginValue)) return false;
    yPos += lineHeight;

    if(!m_label_buyingPower.Create(m_chart_id, m_name + "LblBuyingPower", m_subwin, xPos, yPos, xPos + labelWidth, yPos + 15))
        return false;
    m_label_buyingPower.Text("Buying Power:");
    m_label_buyingPower.FontSize(inpFontSizeNormal);
    m_label_buyingPower.Color(inpPanelTextColor);
    if(!Add(m_label_buyingPower)) return false;

    if(!m_label_buyingPowerValue.Create(m_chart_id, m_name + "LblBuyingPowerValue", m_subwin, valueXPos, yPos, valueXPos + valueWidth, yPos + 15))
        return false;
    m_label_buyingPowerValue.Text("0.0%");
    m_label_buyingPowerValue.FontSize(inpFontSizeNormal);
    m_label_buyingPowerValue.Color(clrGreen);
    if(!Add(m_label_buyingPowerValue)) return false;
    yPos += lineHeight;

    // Return on Margin (Conditional on inpShowROM)
    if(!m_label_rom.Create(m_chart_id, m_name + "LblROM", m_subwin, xPos, yPos, xPos + labelWidth, yPos + 15))
        return false;
    m_label_rom.Text("Return on Margin:");
    m_label_rom.FontSize(inpFontSizeNormal);
    m_label_rom.Color(inpPanelTextColor);
    if(!Add(m_label_rom)) return false;

    if(!m_label_romValue.Create(m_chart_id, m_name + "LblROMValue", m_subwin, valueXPos, yPos, valueXPos + valueWidth, yPos + 15))
        return false;
    m_label_romValue.Text("0.0%");
    m_label_romValue.FontSize(inpFontSizeNormal);
    m_label_romValue.Color(inpPanelTextColor);
    if(!Add(m_label_romValue)) return false;

    // Phase 2: Initially hide all conditional labels based on input parameters
    // These will be shown/hidden in UpdateDisplay() method based on settings

    // Alternate Lot Size (Conditional on inpShowAlternateLotSize)
    if(!inpShowAlternateLotSize) {
        m_label_altLotSize.Hide();
        m_label_altLotSizeValue.Hide();
    }

    // Pip Value (Conditional on inpShowPipValue)
    if(!inpShowPipValue) {
        m_label_pipValue.Hide();
        m_label_pipValueValue.Hide();
    }

    // Partial Exits (Conditional on inpShowTP)
    if(!inpShowTP) {
        m_label_tp.Hide();
        m_label_tpValue.Hide();
        m_label_partialTitle.Hide();
        m_label_level1Label.Hide();
        m_label_level1Pips.Hide();
        m_label_level1Net.Hide();
        m_label_level2Label.Hide();
        m_label_level2Pips.Hide();
        m_label_level2Net.Hide();
        m_label_level3Label.Hide();
        m_label_level3Pips.Hide();
        m_label_level3Net.Hide();
        m_label_partialTotalLabel.Hide();
        m_label_partialTotalValue.Hide();
    } else {
        // Handle individual level visibility based on inpNumberOfLevels
        if(inpNumberOfLevels < 2) {
            m_label_level2Label.Hide();
            m_label_level2Pips.Hide();
            m_label_level2Net.Hide();
        }
        if(inpNumberOfLevels < 3) {
            m_label_level3Label.Hide();
            m_label_level3Pips.Hide();
            m_label_level3Net.Hide();
        }
        // Handle Supertrend last level logic (hide last level if Supertrend will manage it)
        if(inpUseSupertrendOnLastLevel) {
            if(inpNumberOfLevels == 1) {
                m_label_level1Label.Hide();
                m_label_level1Pips.Hide();
                m_label_level1Net.Hide();
            } else if(inpNumberOfLevels == 2) {
                m_label_level2Label.Hide();
                m_label_level2Pips.Hide();
                m_label_level2Net.Hide();
            } else if(inpNumberOfLevels == 3) {
                m_label_level3Label.Hide();
                m_label_level3Pips.Hide();
                m_label_level3Net.Hide();
            }
        }
    }

    // Price Risk, Commission, Spread Cost, Margin, and Buying Power labels
    // are always shown and updated in UpdateDisplay() method

    // Return on Margin (Conditional on inpShowReturnOnMargin)
    if(!inpShowReturnOnMargin) {
        m_label_rom.Hide();
        m_label_romValue.Hide();
    }

    return true;
}

//+------------------------------------------------------------------+
//| Create Buttons                                                   |
//+------------------------------------------------------------------+
bool CForexTradeManagerDialog::CreateButtons()
{
    int buttonWidth = 110;
    int buttonHeight = 30;
    int buttonSpacing = 10;
    int buttonY = 550;  // Position below visible labels with proper spacing
    int buttonX1 = 10;
    int buttonX2 = buttonX1 + buttonWidth + buttonSpacing;

    // Buy Button (top-left)
    if(!m_btn_buy.Create(m_chart_id, m_name + "BtnBuy", m_subwin, buttonX1, buttonY, buttonX1 + buttonWidth, buttonY + buttonHeight))
        return false;
    m_btn_buy.Text("BUY");
    m_btn_buy.FontSize(10);
    m_btn_buy.Color(clrWhite);
    m_btn_buy.ColorBackground(inpBuyButtonColor);
    if(!Add(m_btn_buy)) return false;

    // Sell Button (top-right)
    if(!m_btn_sell.Create(m_chart_id, m_name + "BtnSell", m_subwin, buttonX2, buttonY, buttonX2 + buttonWidth, buttonY + buttonHeight))
        return false;
    m_btn_sell.Text("SELL");
    m_btn_sell.FontSize(10);
    m_btn_sell.Color(clrWhite);
    m_btn_sell.ColorBackground(inpSellButtonColor);
    if(!Add(m_btn_sell)) return false;

    // Breakeven Button (bottom-left)
    int buttonY2 = buttonY + buttonHeight + buttonSpacing;
    if(!m_btn_breakeven.Create(m_chart_id, m_name + "BtnBE", m_subwin, buttonX1, buttonY2, buttonX1 + buttonWidth, buttonY2 + buttonHeight))
        return false;
    m_btn_breakeven.Text("BREAKEVEN");
    m_btn_breakeven.FontSize(9);
    m_btn_breakeven.Color(clrWhite);
    m_btn_breakeven.ColorBackground(inpMoveToBEButtonColor);
    if(!Add(m_btn_breakeven)) return false;

    // Close All Button (bottom-right)
    if(!m_btn_closeAll.Create(m_chart_id, m_name + "BtnCloseAll", m_subwin, buttonX2, buttonY2, buttonX2 + buttonWidth, buttonY2 + buttonHeight))
        return false;
    m_btn_closeAll.Text("CLOSE ALL");
    m_btn_closeAll.FontSize(10);
    m_btn_closeAll.Color(clrWhite);
    m_btn_closeAll.ColorBackground(inpCloseAllButtonColor);
    if(!Add(m_btn_closeAll)) return false;

    return true;
}

//+------------------------------------------------------------------+
//| Update Display Method                                            |
//+------------------------------------------------------------------+
void CForexTradeManagerDialog::UpdateDisplay(RiskCalculation &calc, bool isManagementMode)
{
    // Calculate pip value per lot (needed for Phase 2 labels)
    double pipValuePerLot = (inpPipValueMode == PIP_MANUAL) ? inpManualPipValue : (g_PointValue * (g_PipValue / g_Point));

    // Lot Size
    m_label_lotSizeValue.Text(DoubleToString(calc.lotSize, 2));

    // Risk Source Display
    string riskSource = inpUseDynamicRisk ? "Dynamic" : "Manual";
    color riskSourceColor = inpUseDynamicRisk ? (g_DynamicRisk.fileReadSuccess ? clrGreen : clrOrange) : clrDodgerBlue;
    m_label_riskSourceValue.Text(riskSource);
    m_label_riskSourceValue.Color(riskSourceColor);

    // Account Source Display
    string accountSource = inpUseDynamicAccountSize ? "Equity" : "Manual";
    color accountSourceColor = inpUseDynamicAccountSize ? clrGreen : clrDodgerBlue;
    m_label_accountSourceValue.Text(accountSource);
    m_label_accountSourceValue.Color(accountSourceColor);

    // Base SL
    m_label_slValue.Text(DoubleToString(calc.baseSLPips, 1) + " pips");

    // Total Risk Distance
    double totalRiskPips = calc.slPips + inpExitSlippage;
    m_label_totalRiskPipsValue.Text(DoubleToString(totalRiskPips, 1) + " pips");

    // Break-even
    m_label_breakevenValue.Text(DoubleToString(calc.breakEvenPips, 2) + " pips");

    // Total Risk
    m_label_totalRiskValue.Text("$" + DoubleToString(calc.totalRisk, 2));

    // Risk Percent
    m_label_riskPercentValue.Text(DoubleToString(calc.riskPercent, 2) + "%");

    // Phase 2: Update all conditional labels based on input parameters

    // Alternate Lot Size Display (Conditional on inpShowAlternateLotSize)
    if(inpShowAlternateLotSize) {
        // Use same lot size as primary since alternate calculation not implemented
        m_label_altLotSizeValue.Text(DoubleToString(calc.lotSize, 2));
        m_label_altLotSize.Show();
        m_label_altLotSizeValue.Show();
    } else {
        m_label_altLotSize.Hide();
        m_label_altLotSizeValue.Hide();
    }

    // Pip Value Display (Conditional on inpShowPipValue)
    if(inpShowPipValue) {
        m_label_pipValueValue.Text("$" + DoubleToString(pipValuePerLot, 2));
        m_label_pipValue.Show();
        m_label_pipValueValue.Show();
    } else {
        m_label_pipValue.Hide();
        m_label_pipValueValue.Hide();
    }

    // Partial Exits Display (Conditional on inpShowTP)
    if(inpShowTP) {
        m_label_tp.Show();
        m_label_tpValue.Show();
        m_label_partialTitle.Show();
        m_label_partialTotalLabel.Show();
        m_label_partialTotalValue.Show();

        // Update TP summary
        m_label_tpValue.Text(IntegerToString(inpNumberOfLevels) + " Levels");

        // Calculate and update partial exits details
        RiskCalculation displayCalc = (inpDisplayMode == DISPLAY_CONSERVATIVE) ? g_ConservativeCalc : g_IdealCalc;
        double currentLotSize = displayCalc.lotSize;

        // Get exit percentages using global variables directly
        double exitPct1 = (g_ExitPercent1 > 0) ? g_ExitPercent1 : inpExitPercent1;
        double exitPct2 = (g_ExitPercent2 > 0) ? g_ExitPercent2 : inpExitPercent2;

        // Level 1 (always shown when TP is enabled, unless hidden by Supertrend logic)
        bool showLevel1 = true;
        if(inpUseSupertrendOnLastLevel && inpNumberOfLevels == 1) {
            showLevel1 = false;  // Supertrend will manage entire position
        }

        if(showLevel1) {
            double tp1Pips = displayCalc.partialPips1;
            double tp1Profit = (currentLotSize * tp1Pips * pipValuePerLot * exitPct1) / 100.0;

            m_label_level1Label.Text("L1 (" + IntegerToString((int)exitPct1) + "%):");
            m_label_level1Pips.Text(DoubleToString(tp1Pips, 1) + " pips");
            m_label_level1Net.Text("$" + DoubleToString(tp1Profit, 2));
            m_label_level1Label.Show();
            m_label_level1Pips.Show();
            m_label_level1Net.Show();
        } else {
            m_label_level1Label.Hide();
            m_label_level1Pips.Hide();
            m_label_level1Net.Hide();
        }

        // Level 2 (Conditional on inpNumberOfLevels >= 2)
        if(inpNumberOfLevels >= 2) {
            bool showLevel2 = true;
            if(inpUseSupertrendOnLastLevel && inpNumberOfLevels == 2) {
                showLevel2 = false;  // Supertrend will manage last level
            }

            if(showLevel2) {
                double tp2Pips = displayCalc.partialPips2;
                double remainingAfterTP1 = currentLotSize * (100.0 - exitPct1) / 100.0;
                double tp2Profit = (remainingAfterTP1 * tp2Pips * pipValuePerLot * exitPct2) / 100.0;

                m_label_level2Label.Text("L2 (" + IntegerToString((int)exitPct2) + "%):");
                m_label_level2Pips.Text(DoubleToString(tp2Pips, 1) + " pips");
                m_label_level2Net.Text("$" + DoubleToString(tp2Profit, 2));
                m_label_level2Label.Show();
                m_label_level2Pips.Show();
                m_label_level2Net.Show();
            } else {
                m_label_level2Label.Hide();
                m_label_level2Pips.Hide();
                m_label_level2Net.Hide();
            }
        } else {
            m_label_level2Label.Hide();
            m_label_level2Pips.Hide();
            m_label_level2Net.Hide();
        }

        // Level 3 (Conditional on inpNumberOfLevels == 3)
        if(inpNumberOfLevels == 3) {
            bool showLevel3 = true;
            if(inpUseSupertrendOnLastLevel && inpNumberOfLevels == 3) {
                showLevel3 = false;  // Supertrend will manage last level
            }

            if(showLevel3) {
                double tp3Pips = displayCalc.partialPips3;
                double remainingAfterTP2 = currentLotSize * (100.0 - exitPct1 - exitPct2) / 100.0;
                double tp3Profit = remainingAfterTP2 * tp3Pips * pipValuePerLot;  // 100% of remaining

                m_label_level3Label.Text("L3 (100%):");
                m_label_level3Pips.Text(DoubleToString(tp3Pips, 1) + " pips");
                m_label_level3Net.Text("$" + DoubleToString(tp3Profit, 2));
                m_label_level3Label.Show();
                m_label_level3Pips.Show();
                m_label_level3Net.Show();
            } else {
                m_label_level3Label.Hide();
                m_label_level3Pips.Hide();
                m_label_level3Net.Hide();
            }
        } else {
            m_label_level3Label.Hide();
            m_label_level3Pips.Hide();
            m_label_level3Net.Hide();
        }

        // Calculate total net P&L for all visible levels
        double totalNet = 0;
        if(showLevel1) {
            double tp1Pips = displayCalc.partialPips1;
            totalNet += (currentLotSize * tp1Pips * pipValuePerLot * exitPct1) / 100.0;
        }
        if(inpNumberOfLevels >= 2 && !(inpUseSupertrendOnLastLevel && inpNumberOfLevels == 2)) {
            double tp2Pips = displayCalc.partialPips2;
            double remainingAfterTP1 = currentLotSize * (100.0 - exitPct1) / 100.0;
            totalNet += (remainingAfterTP1 * tp2Pips * pipValuePerLot * exitPct2) / 100.0;
        }
        if(inpNumberOfLevels == 3 && !(inpUseSupertrendOnLastLevel && inpNumberOfLevels == 3)) {
            double tp3Pips = displayCalc.partialPips3;
            double remainingAfterTP2 = currentLotSize * (100.0 - exitPct1 - exitPct2) / 100.0;
            totalNet += remainingAfterTP2 * tp3Pips * pipValuePerLot;
        }

        m_label_partialTotalValue.Text("$" + DoubleToString(totalNet, 2));

    } else {
        // Hide all partial exit related labels when TP is disabled
        m_label_tp.Hide();
        m_label_tpValue.Hide();
        m_label_partialTitle.Hide();
        m_label_level1Label.Hide();
        m_label_level1Pips.Hide();
        m_label_level1Net.Hide();
        m_label_level2Label.Hide();
        m_label_level2Pips.Hide();
        m_label_level2Net.Hide();
        m_label_level3Label.Hide();
        m_label_level3Pips.Hide();
        m_label_level3Net.Hide();
        m_label_partialTotalLabel.Hide();
        m_label_partialTotalValue.Hide();
    }

    // Price Risk, Commission, and Spread Cost Labels (always update)
    m_label_priceRiskValue.Text("$" + DoubleToString(calc.priceRisk, 2));
    m_label_commissionValue.Text("$" + DoubleToString(calc.commission, 2));
    m_label_spreadCostValue.Text("$" + DoubleToString(calc.spreadCost, 2));

    // Margin and Buying Power Labels (always update)
    m_label_marginValue.Text("$" + DoubleToString(calc.marginRequired, 2));
    m_label_buyingPowerValue.Text(DoubleToString(calc.buyingPowerPercent, 1) + "%");

    // Return on Margin (Conditional on inpShowReturnOnMargin)
    if(inpShowReturnOnMargin) {
        RiskCalculation displayCalc = (inpDisplayMode == DISPLAY_CONSERVATIVE) ? g_ConservativeCalc : g_IdealCalc;
        double marginRequired = displayCalc.marginRequired;
        double totalNet = 0;

        // Get exit percentages using global variables directly
        double exitPct1 = (g_ExitPercent1 > 0) ? g_ExitPercent1 : inpExitPercent1;
        double exitPct2 = (g_ExitPercent2 > 0) ? g_ExitPercent2 : inpExitPercent2;

        // Calculate total net potential from visible TP levels
        if(inpShowTP) {
            double currentLotSize = displayCalc.lotSize;
            if(inpNumberOfLevels >= 1 && !(inpUseSupertrendOnLastLevel && inpNumberOfLevels == 1)) {
                double tp1Pips = displayCalc.partialPips1;
                totalNet += (currentLotSize * tp1Pips * pipValuePerLot * exitPct1) / 100.0;
            }
            if(inpNumberOfLevels >= 2 && !(inpUseSupertrendOnLastLevel && inpNumberOfLevels == 2)) {
                double tp2Pips = displayCalc.partialPips2;
                double remainingAfterTP1 = currentLotSize * (100.0 - exitPct1) / 100.0;
                totalNet += (remainingAfterTP1 * tp2Pips * pipValuePerLot * exitPct2) / 100.0;
            }
            if(inpNumberOfLevels == 3 && !(inpUseSupertrendOnLastLevel && inpNumberOfLevels == 3)) {
                double tp3Pips = displayCalc.partialPips3;
                double remainingAfterTP2 = currentLotSize * (100.0 - exitPct1 - exitPct2) / 100.0;
                totalNet += remainingAfterTP2 * tp3Pips * pipValuePerLot;
            }
        }

        double rom = (marginRequired > 0) ? (totalNet / marginRequired * 100.0) : 0.0;
        m_label_romValue.Text(DoubleToString(rom, 1) + "%");

        m_label_rom.Show();
        m_label_romValue.Show();
    } else {
        // Hide ROM labels when not enabled
        m_label_rom.Hide();
        m_label_romValue.Hide();
    }
}

//+------------------------------------------------------------------+
//| Position Persistence Functions                                    |
//+------------------------------------------------------------------+
void SavePanelPosition()
{
    // Get current dialog position from CAppDialog
    int x = ExtDialog.Left();
    int y = ExtDialog.Top();

    // Create directory if it doesn't exist
    if(!FolderCreate("ForexRiskManager"))
    {
        Print("Failed to create ForexRiskManager directory for position file");
        return;
    }

    string positionFileName = "ForexRiskManager\\ForexRiskManager_PanelPosition.csv";
    string csvData = StringFormat("%d,%d", x, y);

    int fileHandle = FileOpen(positionFileName, FILE_WRITE | FILE_CSV | FILE_ANSI);
    if(fileHandle != INVALID_HANDLE)
    {
        FileWrite(fileHandle, csvData);
        FileClose(fileHandle);
        Print("Panel position saved: (", x, ", ", y, ")");
    }
    else
    {
        Print("Failed to save panel position to file: ", positionFileName);
    }
}

bool LoadPanelPosition(int &x, int &y)
{
    string positionFileName = "ForexRiskManager\\ForexRiskManager_PanelPosition.csv";
    int fileHandle = FileOpen(positionFileName, FILE_READ | FILE_CSV | FILE_ANSI);

    if(fileHandle == INVALID_HANDLE)
    {
        // No saved position, use defaults
        x = DEFAULT_PANEL_X;
        y = DEFAULT_PANEL_Y;
        Print("No saved position found, using defaults: (", x, ", ", y, ")");
        return false;
    }

    string csvData;
    if(!FileIsEnding(fileHandle))
    {
        csvData = FileReadString(fileHandle);
    }
    FileClose(fileHandle);

    if(csvData == "")
    {
        // Empty file, use defaults
        x = DEFAULT_PANEL_X;
        y = DEFAULT_PANEL_Y;
        return false;
    }

    string parts[];
    int count = StringSplit(csvData, ',', parts);

    if(count != 2)
    {
        // Invalid format, use defaults
        x = DEFAULT_PANEL_X;
        y = DEFAULT_PANEL_Y;
        return false;
    }

    x = (int)StringToInteger(parts[0]);
    y = (int)StringToInteger(parts[1]);

    Print("Panel position loaded: (", x, ", ", y, ")");
    return true;
}
