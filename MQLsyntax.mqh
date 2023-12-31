// MQL 4 Language Support for C++ Editor Tools

// Usage:
// #include <MQLsyntax.mqh>

// Original Inspiration:
// https://c.mql5.com/3/176/MQLsyntax.mqh
// via
// https://www.mql5.com/en/forum/222553/page3#comment_6719227

// Formal Reference:
//
// - Function Names
//   MQL4 https://docs.mql4.com/function_indices
//   MQL5 https://www.mql5.com/en/docs/function_indices
//
// Usage Notes:
//
// Enum type names, when defined here as prefixed with "_",
// are not defined in the MetaTrader platform. These are defined
// here as a convention for use with function prototypes.
//
// The following represents only a subset of types, constants,
// and functions defined in MQL4.
//
// This file is provided as a utility for MQL4 source editing 
// using C++ editor tools.
//
// This does not provide a complete support for the syntax and 
// semantic conventions of the the MQL4 programming language.
// 


#ifndef _MQL_SYNTAX_
#define _MQL_SYNTAX_ 1

#include <stdio.h>

// ** TBD

#ifndef interface
#define interface class
#endif

/**
 * MQL4 Pointers
 **/

enum ENUM_POINTER_TYPE
{
    POINTER_INVALID,
    POINTER_DYNAMIC,
    POINTER_AUTOMATIC
};

ENUM_POINTER_TYPE CheckPointer(void *ptr);

template <typename T>
T GetPointer(T ptr);

/**
 * String Functions (FIXME C++ toolchain interation for editor tools)
 **/

/// defining a few hacks for C++ Compatibility
/// within the editor environment

string StringFormat(const string s, ...);

#define Print(...) puts(__VA_ARGS__)

#define PrintFormat(s, ...) printf(s, __VA_ARGS__)

#define Alert(...) Print(__VA_ARGS__)

/**
 * Type Definitions
 **/

typedef unsigned char uchar;
typedef unsigned short ushort;
typedef unsigned int uint;
typedef int color;
typedef unsigned long ulong;
typedef unsigned long datetime;
typedef const char *string;

/**
 * Arrays
 **/

int ArrayResize(void *array, int new_size, int reserve_size = 0);
bool ArraySetAsSeries(const void *array, bool flag);
int ArraySize(const void *array);
void ArrayFree(void *array[]);

/**
 * Time
 */

int _Period;

enum ENUM_TIMEFRAMES
{
    PERIOD_CURRENT = 0,
    PERIOD_M1 = 1,
    PERIOD_M5 = 5,
    PERIOD_M15 = 15,
    PERIOD_M30 = 30,
    PERIOD_H1 = 60,
    PERIOD_H4 = 240,
    PERIOD_D1 = 1440,
    PERIOD_W1 = 10080,
    PERIOD_MN1 = 43200
};

enum _TIME
{
    TIME_DATE = 1,
    TIME_MINUTES = 2,
    TIME_SECONDS = 4
};

struct MqlDateTime
{
    int year;        // year
    int mon;         // month
    int day;         // day
    int hour;        // hour
    int min;         // minutes
    int sec;         // seconds
    int day_of_week; // index of day of week (0 for Sunday)
    int day_of_year; // index of day in year (0 for January 1)
};

string TimeToStr(datetime dt, int mode = TIME_DATE | TIME_MINUTES);
string TimeToString(datetime dt, int mode = TIME_DATE | TIME_MINUTES);

/**
 * Charts and Symbols
 **/

int _Period;    // timeframe period of the current chart
string _Symbol; // symbol of the current chart

long ChartOpen(string symbol, ENUM_TIMEFRAMES period);

// index for the first chart of the client terminal
long ChartFirst();

// index of the next chart, or -1 if last. use current_id 0 or ChartFirst() for first index
long ChartNext(long current_id);

/// @brief open a new chart for the symbol and timeframe
/// @param symbol chart symbol, NULL for current symbol
/// @param timeframe chart timeframe, 0 for current timeframe
/// @return current chart index of the new chart, or 0 on failure. On failure, see GetLastError()
long ChartOpen(string symbol, ENUM_TIMEFRAMES timeframe);

/// @brief close the chart
/// @param chart_id chart index, 0 for current chart
/// @return true if closed, else false
bool ChartClose(long chart_id = 0L);

/// @brief timeframe for the chart
/// @param chart_id chart index, 0 for current chart
/// @return timeframe for the chart. If no chart is found for the index, returns 0
enum ENUM_TIMEFRAMES ChartPeriod(long chart_id = 0L);

/// @brief symbol for the chart
/// @param chart_id chart index, 0 for current chart
/// @return chart symbol, or the empty string if no chart is found for the index
const string ChartSymbol(long chart_id = 0L);

struct MqlTick
{
    datetime time;
    double bid;
    double ask;
    double last;
    ulong volume;
};

bool SymbolInfoTick(
    string symbol,
    MqlTick &tick);

/// @brief MQL Rate Quote structure
struct MqlRates
{
    datetime time;    // Quote start time
    double open;      // Quote open
    double high;      // Quote high
    double low;       // Quote low
    double close;     // Quote close
    long tick_volume; // Tick volume
    int spread;       // Quote Spread, generally 0 if not available
    long real_volume; // Trade volume, generally 0 if not available
};

int CopyRates(
    string symbol,
    ENUM_TIMEFRAMES timeframe,
    int start,
    int count,
    MqlRates rates[]);

int CopyRates(
    string symbol,
    ENUM_TIMEFRAMES timeframe,
    datetime start,
    int count,
    MqlRates rates[]);

int CopyRates(
    string symbol,
    ENUM_TIMEFRAMES timeframe,
    datetime start,
    datetime stop,
    MqlRates rates[]);

/// @brief refresh rates for expert advisor data
/// @return true if data was refreshed, false if previous data is current
bool RefreshRates();

int CopyOpen(string symbol, int timeframe, int start, int count, double *open[]);
int CopyHigh(string symbol, int timeframe, int start, int count, double *high[]);
int CopyLow(string symbol, int timeframe, int start, int count, double *low[]);
int CopyClose(string symbol, int timeframe, int start, int count, double *close[]);
int CopyTime(string symbol, int timeframe, int start, int count, datetime *times[]);
int CopyTickVolume(string symbol, int timeframe, int start, int count, datetime *times[]);

double Open[];   // current symbol's open quotes (time-series index)
double High[];   // current symbol's high quotes (time-series index)
double Low[];    // current symbol's low quotes (time-series index)
double Close[];  // current symbol's close quotes (time-series index)
datetime Time[]; // current symbol's quote times (time-series index)
long Volume[];   // current symbol's tick volume quotes (time-series index)

int Bars;      // number of bars in current chart, at chart's symbol and timeframe
int Digits;    // decimal accuracy of current symbol prices
int _Digits;   // decimal accuracy of current symbol prices
double Point;  // current symbol's point value, in quote currency
double _Point; // current symbol's point value, in quote currency

double _Ask;
double _Bid;

/**
 * Graphical Objects
 **/

#define clrNONE -1
#define CLR_NONE clrNONE

#define EMPTY -1

/**
 * Custom Indicators
 **/

// https://www.mql5.com/en/docs/constants/indicatorconstants/customindicatorproperties
enum ENUM_INDEXBUFFER_TYPE
{
    INDICATOR_DATA,        // Indicator Data
    INDICATOR_COLOR_INDEX, // MQL5 indicator color
    INDICATOR_CALCULATIONS // Ancillary data
};

enum _SHAPE_STYLE
{
    DRAW_LINE,
    DRAW_SECTION,
    DRAW_HISTOGRAM,
    DRAW_ARROW,
    DRAW_ZIGZAG,
    DRAW_NONE = 12
};

enum ENUM_LINE_STYLE
{
    _STYLE_EMPTY = EMPTY,
    STYLE_SOLID,
    STYLE_DASH,
    STYLE_DOT,
    STYLE_DASHDOT,
    STYLE_DASHDOTDOT,
};

enum _LINE_WIDTH
{
    _LINE_WIDTH_NO_CHANGE,
    _LINE_WIDTH_1,
    _LINE_WIDTH_2,
    _LINE_WIDTH_3,
    _LINE_WIDTH_4,
    _LINE_WIDTH_5
}

void
SetIndexStyle(
    int index,                                 // line index
    _SHAPE_STYLE type,                         // line type
    ENUM_LINE_STYLE style = EMPTY,             // line style
    _LINE_WIDTH width = _LINE_WIDTH_NO_CHANGE, // line width
    color clr = clrNONE                        // line color
);

void SetIndexStyle(
    int index,
    int type,
    int style = EMPTY,
    int width = EMPTY,
    color clr = clrNONE);

bool IndicatorSetDouble(
    int prop_id,      // identifier
    double prop_value // value to be set
);

bool IndicatorSetDouble(
    int prop_id,       // identifier
    int prop_modifier, // modifier
    double prop_value  // value to be set
);

bool IndicatorSetInteger(
    int prop_id,   // identifier
    int prop_value // value to be set
);

bool IndicatorSetInteger(
    int prop_id,       // identifier
    int prop_modifier, // modifier
    int prop_value     // value to be set
);

bool IndicatorSetString(
    int prop_id,      // identifier
    string prop_value // value to be set
);

bool IndicatorSetString(
    int prop_id,       // identifier
    int prop_modifier, // modifier
    string prop_value  // value to be set
);

bool IndicatorSetString(
    int prop_id,       // identifier
    int prop_modifier, // modifier
    string prop_value  // value to be set
);

bool SetIndexBuffer(
    int index,                      // buffer index
    double *buffer[],               // array
    ENUM_INDEXBUFFER_TYPE data_type // what will be stored
);

bool SetIndexBuffer(
    int index,       // buffer index
    double *buffer[] // array
);

bool IndicatorBuffers(
    int count // buffers
);

int IndicatorCounted();

void IndicatorDigits(
    int digits // digits
);

void IndicatorShortName(
    string name // name
);

void SetIndexArrow(
    int index, // line index
    int code   // code
);

void SetIndexArrow(
    int index, // line index
    int code   // code
);

void SetIndexDrawBegin(
    int index, // line index
    int begin  // position
);

void SetIndexEmptyValue(
    int index,   // line index
    double value // new "empty value"
);

void SetIndexLabel(
    int index,  // line index
    string text // text
);

void SetIndexShift(
    int index, // line index
    int shift  // shift
);

void SetIndexStyle(
    int index,          // line index
    int type,           // line type
    int style = EMPTY,  // line style
    int width = EMPTY,  // line width
    color clr = clrNONE // line color
);

void SetLevelStyle(
    int draw_style, // drawing style
    int line_width, // line width
    color clr       // color
);

void SetLevelStyle(
    int draw_style, // drawing style
    int line_width, // line width
    color clr       // color
);

/**
 * Orders
 **/

double Bid;
double Ask;
int OP_SELL;
int OP_BUY;

bool OrderClose(int ticket, double lots, double price, int slippage, color arrow_color);

bool OrderCloseBy(int ticket, int opposite, color arrow_color);

double OrderClosePrice();

datetime OrderCloseTime();

const string OrderComment();

double OrderCommission();

bool OrderDelete(int ticket, color arrow_color);

datetime OrderExpiration();

double OrderLots();

int OrderMagicNumber();

bool OrderModify(int ticket, double price, double stoploss, double takeprofit, datetime expiration, color arrow_color);

double OrderOpenPrice();

datetime OrderOpenTime();

void OrderPrint();

double OrderProfit();

enum _ORDER_SELECT_FLAG
{
    SELECT_BY_POS,
    SELECT_BY_TICKET
};

enum _ORDER_SELECT_POOL
{
    MODE_TRADES,
    MODE_HISTORY
};

bool OrderSelect(int index, int select, int pool = MODE_TRADES);

int OrderSend(
    string symbol,
    int cmd,
    double volume,
    double price,
    int slippage,
    double stoploss,
    double takeprofit,
    string comment = NULL,
    int magic = 0,
    datetime expiration = 0,
    color arrow_color = clrNONE);

int OrdersHistoryTotal();

double OrderStopLoss();

int OrdersTotal();

double OrderSwap();

const string OrderSymbol();

double OrderTakeProfit();

int OrderTicket();

enum _ORDER_TYPE
{
    OP_BUY,
    OP_SELL,
    OP_BUYLIMIT,
    OP_BUYSTOP,
    OP_SELLLIMIT,
    OP_SELLSTOP,
};

enum _ORDER_TYPE OrderType();

/**
 * Mathematical Operations
 **/

double fmod(double dividend, double divisor);
double MathMod(double dividend, double divisor);
double fabs(double value);
double MathAbs(double value);
double ceil(double value);
double MathCeil(double value);
double floor(double value);
double MathFloor(double value);
double pow(double base, double exp);
double sqrt(double value);
double MathSqrt(double value);
double log(double value);
double MathLog(double value);
double log10(double value);
double MathLog10(double value);
double fmin(double lhs, double rhs);
double MathMin(double lhs, double rhs);
double fmax(double lhs, double rhs);
double MathMax(double lhs, double rhs);

double cos(double radians);
double MathCos(double radians);
double sin(double radians);
double MathSin(double radians);
double tan(double radians);
double MathTan(double radians);



/**
 * Indicators
 **/

int iBars(const string symbol, int timeframe);
int iBarShift(const string symbol, int timeframe, datetime time, bool exact = false);

enum ENUM_APPLIED_PRICE
{
    PRICE_CLOSE,
    PRICE_OPEN,
    PRICE_HIGH,
    PRICE_LOW,
    PRICE_MEDIAN,
    PRICE_TYPICAL,
    PRICE_WEIGHTED
};

enum ENUM_MA_METHOD
{
    MODE_SMA,
    MODE_EMA,
    MODE_SMMA,
    MODE_LWMA
};

enum _ADX_MODE
{
    MODE_MAIN,
    MODE_PLUSDI,
    MODE_MINUSDI
};

double iADX(string &symbol, int timeframe, int period, int applied_price, _ADX_MODE mode, int shift);

/**
 * MQL Programs
 */

int _LastError;
int _RandomSeed;
bool _StopFlag;
int _UninitReason;

enum _DEINIT_REASON
{
    REASON_PROGRAM,
    REASON_REMOVE,
    REASON_RECOMPILE,
    REASON_CHARTCLOSE,
    REASON_PARAMETERS,
    REASON_ACCOUNT,
    REASON_TEMPLATE,
    REASON_INITFAILED,
    REASON_CLOSE
};

enum ENUM_INIT_RETCODE
{
    INIT_SUCCEEDED,            // Initialization Succeeded
    INIT_FAILED,               // Initialization Failed
    INIT_PARAMETERS_INCORRECT, // Incorrect Paramters
    INIT_AGENT_NOT_SUITABLE    // (Undocumented) EA failure
};

/**
 * Batch from contrib
 */

// #define MqlRates int
#define COLOR_FORMAT_ARGB_RAW 0
#define COLOR_FORMAT_XRGB_NOALPHA 0
#define COLOR_FORMAT_ARGB_NORMALIZE 0
// #define INIT_FAILED 0
// #define INIT_SUCCEEDED 0
// #define INIT_AGENT_NOT_SUITABLE 0
// #define INIT_PARAMETERS_INCORRECT 0

/// Editors such as VS Code, with its C++ support, may
/// typically expand these to their correct value without
/// declaration. 
///
/// In C/C++ environments, the compiler would typically
/// provide these macros.
// #define __DATE__ 0
// #define __DATETIME__ 0
// #define __FILE__ 0
// #define __FUNCSIG__ 0
// #define __FUNCTION__ 0
// #define __LINE__ 0

#define __MQLBUILD__ 0
#define __MQL5BUILD__ 0
#define __PATH__ 0
#define ACCOUNT_ASSETS 0
#define ACCOUNT_BALANCE 0
#define ACCOUNT_COMMISSION_BLOCKED 0
#define ACCOUNT_COMPANY 0
#define ACCOUNT_CREDIT 0
#define ACCOUNT_CURRENCY 0
#define ACCOUNT_EQUITY 0
#define ACCOUNT_LEVERAGE 0
#define ACCOUNT_LIABILITIES 0
#define ACCOUNT_LIMIT_ORDERS 0
#define ACCOUNT_LOGIN 0
#define ACCOUNT_MARGIN 0
#define ACCOUNT_MARGIN_FREE 0
#define ACCOUNT_MARGIN_INITIAL 0
#define ACCOUNT_MARGIN_LEVEL 0
#define ACCOUNT_MARGIN_MAINTENANCE 0
#define ACCOUNT_MARGIN_SO_CALL 0
#define ACCOUNT_MARGIN_SO_MODE 0
#define ACCOUNT_MARGIN_SO_SO 0
#define ACCOUNT_NAME 0
#define ACCOUNT_PROFIT 0
#define ACCOUNT_SERVER 0
#define ACCOUNT_STOPOUT_MODE_MONEY 0
#define ACCOUNT_STOPOUT_MODE_PERCENT 0
#define ACCOUNT_TRADE_ALLOWED 0
#define ACCOUNT_TRADE_EXPERT 0
#define ACCOUNT_TRADE_MODE 0
#define ACCOUNT_TRADE_MODE_CONTEST 0
#define ACCOUNT_TRADE_MODE_DEMO 0
#define ACCOUNT_TRADE_MODE_REAL 0
#define ALIGN_CENTER 0
#define ALIGN_LEFT 0
#define ALIGN_RIGHT 0
#define ANCHOR_CENTER 0
#define ANCHOR_LEFT 0
#define ANCHOR_LEFT_LOWER 0
#define ANCHOR_LEFT_UPPER 0
#define ANCHOR_LOWER 0
#define ANCHOR_RIGHT 0
#define ANCHOR_RIGHT_LOWER 0
#define ANCHOR_RIGHT_UPPER 0
#define ANCHOR_UPPER 0
#define BASE_LINE 0
#define BOOK_TYPE_BUY 0
#define BOOK_TYPE_BUY_MARKET 0
#define BOOK_TYPE_SELL 0
#define BOOK_TYPE_SELL_MARKET 0
#define BORDER_FLAT 0
#define BORDER_RAISED 0
#define BORDER_SUNKEN 0
#define CHAR_MAX 0
#define CHAR_MIN 0
#define CHART_AUTOSCROLL 0
#define CHART_BARS 0
#define CHART_BEGIN 0
#define CHART_BRING_TO_TOP 0
#define CHART_CANDLES 0
#define CHART_COLOR_ASK 0
#define CHART_COLOR_BACKGROUND 0
#define CHART_COLOR_BID 0
#define CHART_COLOR_CANDLE_BEAR 0
#define CHART_COLOR_CANDLE_BULL 0
#define CHART_COLOR_CHART_DOWN 0
#define CHART_COLOR_CHART_LINE 0
#define CHART_COLOR_CHART_UP 0
#define CHART_COLOR_FOREGROUND 0
#define CHART_COLOR_GRID 0
#define CHART_COLOR_LAST 0
#define CHART_COLOR_STOP_LEVEL 0
#define CHART_COLOR_VOLUME 0
#define CHART_COMMENT 0
#define CHART_CURRENT_POS 0
#define CHART_DRAG_TRADE_LEVELS 0
#define CHART_EVENT_MOUSE_MOVE 0
#define CHART_EVENT_OBJECT_CREATE 0
#define CHART_EVENT_OBJECT_DELETE 0
#define CHART_FIRST_VISIBLE_BAR 0
#define CHART_FIXED_MAX 0
#define CHART_FIXED_MIN 0
#define CHART_FIXED_POSITION 0
#define CHART_FOREGROUND 0
#define CHART_HEIGHT_IN_PIXELS 0
#define CHART_IS_OBJECT 0
#define CHART_LINE 0
#define CHART_MODE 0
#define CHART_MOUSE_SCROLL 0
#define CHART_POINTS_PER_BAR 0
#define CHART_PRICE_MAX 0
#define CHART_PRICE_MIN 0
#define CHART_SCALE 0
#define CHART_SCALE_PT_PER_BAR 0
#define CHART_SCALEFIX 0
#define CHART_SCALEFIX_11 0
#define CHART_SHIFT 0
#define CHART_SHIFT_SIZE 0
#define CHART_SHOW_ASK_LINE 0
#define CHART_SHOW_BID_LINE 0
#define CHART_SHOW_DATE_SCALE 0
#define CHART_SHOW_GRID 0
#define CHART_SHOW_LAST_LINE 0
#define CHART_SHOW_OBJECT_DESCR 0
#define CHART_SHOW_OHLC 0
#define CHART_SHOW_ONE_CLICK 0
#define CHART_SHOW_PERIOD_SEP 0
#define CHART_SHOW_PRICE_SCALE 0
#define CHART_SHOW_TRADE_LEVELS 0
#define CHART_SHOW_VOLUMES 0
#define CHART_VISIBLE_BARS 0
#define CHART_VOLUME_HIDE 0
#define CHART_VOLUME_REAL 0
#define CHART_VOLUME_TICK 0
#define CHART_WIDTH_IN_BARS 0
#define CHART_WIDTH_IN_PIXELS 0
#define CHART_WINDOW_HANDLE 0
#define CHART_WINDOW_IS_VISIBLE 0
#define CHART_WINDOW_YDISTANCE 0
#define CHART_WINDOWS_TOTAL 0
#define CHARTEVENT_CHART_CHANGE 0
#define CHARTEVENT_CLICK 0
#define CHARTEVENT_CUSTOM 0
#define CHARTEVENT_CUSTOM_LAST 0
#define CHARTEVENT_KEYDOWN 0
#define CHARTEVENT_MOUSE_MOVE 0
#define CHARTEVENT_OBJECT_CHANGE 0
#define CHARTEVENT_OBJECT_CLICK 0
#define CHARTEVENT_OBJECT_CREATE 0
#define CHARTEVENT_OBJECT_DELETE 0
#define CHARTEVENT_OBJECT_DRAG 0
#define CHARTEVENT_OBJECT_ENDEDIT 0
#define CHARTS_MAX 0
#define CHIKOUSPAN_LINE 0
#define clrAliceBlue 0
#define clrAntiqueWhite 0
#define clrAqua 0
#define clrAquamarine 0
#define clrBeige 0
#define clrBisque 0
#define clrBlack 0
#define clrBlanchedAlmond 0
#define clrBlue 0
#define clrBlueViolet 0
#define clrBrown 0
#define clrBurlyWood 0
#define clrCadetBlue 0
#define clrChartreuse 0
#define clrChocolate 0
#define clrCoral 0
#define clrCornflowerBlue 0
#define clrCornsilk 0
#define clrCrimson 0
#define clrDarkBlue 0
#define clrDarkGoldenrod 0
#define clrDarkGray 0
#define clrDarkGreen 0
#define clrDarkKhaki 0
#define clrDarkOliveGreen 0
#define clrDarkOrange 0
#define clrDarkOrchid 0
#define clrDarkSalmon 0
#define clrDarkSeaGreen 0
#define clrDarkSlateBlue 0
#define clrDarkSlateGray 0
#define clrDarkTurquoise 0
#define clrDarkViolet 0
#define clrDeepPink 0
#define clrDeepSkyBlue 0
#define clrDimGray 0
#define clrDodgerBlue 0
#define clrFireBrick 0
#define clrForestGreen 0
#define clrGainsboro 0
#define clrGold 0
#define clrGoldenrod 0
#define clrGray 0
#define clrGreen 0
#define clrGreenYellow 0
#define clrHoneydew 0
#define clrHotPink 0
#define clrIndianRed 0
#define clrIndigo 0
#define clrIvory 0
#define clrKhaki 0
#define clrLavender 0
#define clrLavenderBlush 0
#define clrLawnGreen 0
#define clrLemonChiffon 0
#define clrLightBlue 0
#define clrLightCoral 0
#define clrLightCyan 0
#define clrLightGoldenrod 0
#define clrLightGray 0
#define clrLightGreen 0
#define clrLightPink 0
#define clrLightSalmon 0
#define clrLightSeaGreen 0
#define clrLightSkyBlue 0
#define clrLightSlateGray 0
#define clrLightSteelBlue 0
#define clrLightYellow 0
#define clrLime 0
#define clrLimeGreen 0
#define clrLinen 0
#define clrMagenta 0
#define clrMaroon 0
#define clrMediumAquamarine 0
#define clrMediumBlue 0
#define clrMediumOrchid 0
#define clrMediumPurple 0
#define clrMediumSeaGreen 0
#define clrMediumSlateBlue 0
#define clrMediumSpringGreen 0
#define clrMediumTurquoise 0
#define clrMediumVioletRed 0
#define clrMidnightBlue 0
#define clrMintCream 0
#define clrMistyRose 0
#define clrMoccasin 0
#define clrNavajoWhite 0
#define clrNavy 0
// #define clrNONE 0
#define clrOldLace 0
#define clrOlive 0
#define clrOliveDrab 0
#define clrOrange 0
#define clrOrangeRed 0
#define clrOrchid 0
#define clrPaleGoldenrod 0
#define clrPaleGreen 0
#define clrPaleTurquoise 0
#define clrPaleVioletRed 0
#define clrPapayaWhip 0
#define clrPeachPuff 0
#define clrPeru 0
#define clrPink 0
#define clrPlum 0
#define clrPowderBlue 0
#define clrPurple 0
#define clrRed 0
#define clrRosyBrown 0
#define clrRoyalBlue 0
#define clrSaddleBrown 0
#define clrSalmon 0
#define clrSandyBrown 0
#define clrSeaGreen 0
#define clrSeashell 0
#define clrSienna 0
#define clrSilver 0
#define clrSkyBlue 0
#define clrSlateBlue 0
#define clrSlateGray 0
#define clrSnow 0
#define clrSpringGreen 0
#define clrSteelBlue 0
#define clrTan 0
#define clrTeal 0
#define clrThistle 0
#define clrTomato 0
#define clrTurquoise 0
#define clrViolet 0
#define clrWheat 0
#define clrWhite 0
#define clrWhiteSmoke 0
#define clrYellow 0
#define clrYellowGreen 0
#define CORNER_LEFT_LOWER 0
#define CORNER_LEFT_UPPER 0
#define CORNER_RIGHT_LOWER 0
#define CORNER_RIGHT_UPPER 0
#define CP_ACP 0
#define CP_MACCP 0
#define CP_OEMCP 0
#define CP_SYMBOL 0
#define CP_THREAD_ACP 0
#define CP_UTF7 0
#define CP_UTF8 0
#define CRYPT_AES128 0
#define CRYPT_AES256 0
#define CRYPT_ARCH_ZIP 0
#define CRYPT_BASE64 0
#define CRYPT_DES 0
#define CRYPT_HASH_MD5 0
#define CRYPT_HASH_SHA1 0
#define CRYPT_HASH_SHA256 0
#define DBL_DIG 0
#define DBL_EPSILON 0
#define DBL_MANT_DIG 0
#define DBL_MAX 0
#define DBL_MAX_10_EXP 0
#define DBL_MAX_EXP 0
#define DBL_MIN 0
#define DBL_MIN_10_EXP 0
#define DBL_MIN_EXP 0
#define DEAL_COMMENT 0
#define DEAL_COMMISSION 0
#define DEAL_ENTRY 0
#define DEAL_ENTRY_IN 0
#define DEAL_ENTRY_INOUT 0
#define DEAL_ENTRY_OUT 0
#define DEAL_MAGIC 0
#define DEAL_ORDER 0
#define DEAL_POSITION_ID 0
#define DEAL_PRICE 0
#define DEAL_PROFIT 0
#define DEAL_SWAP 0
#define DEAL_SYMBOL 0
#define DEAL_TIME 0
#define DEAL_TIME_MSC 0
#define DEAL_TYPE 0
#define DEAL_TYPE_BALANCE 0
#define DEAL_TYPE_BONUS 0
#define DEAL_TYPE_BUY 0
#define DEAL_TYPE_BUY_CANCELED 0
#define DEAL_TYPE_CHARGE 0
#define DEAL_TYPE_COMMISSION 0
#define DEAL_TYPE_COMMISSION_AGENT_DAILY 0
#define DEAL_TYPE_COMMISSION_AGENT_MONTHLY 0
#define DEAL_TYPE_COMMISSION_DAILY 0
#define DEAL_TYPE_COMMISSION_MONTHLY 0
#define DEAL_TYPE_CORRECTION 0
#define DEAL_TYPE_CREDIT 0
#define DEAL_TYPE_INTEREST 0
#define DEAL_TYPE_SELL 0
#define DEAL_TYPE_SELL_CANCELED 0
#define DEAL_VOLUME 0
#define DRAW_ARROW 0
#define DRAW_BARS 0
#define DRAW_CANDLES 0
#define DRAW_COLOR_ARROW 0
#define DRAW_COLOR_BARS 0
#define DRAW_COLOR_CANDLES 0
#define DRAW_COLOR_HISTOGRAM 0
#define DRAW_COLOR_HISTOGRAM2 0
#define DRAW_COLOR_LINE 0
#define DRAW_COLOR_SECTION 0
#define DRAW_COLOR_ZIGZAG 0
#define DRAW_FILLING 0
// #define DRAW_HISTOGRAM 0
#define DRAW_HISTOGRAM2 0
// #define DRAW_LINE 0
// #define DRAW_NONE 0
// #define DRAW_SECTION 0
// #define DRAW_ZIGZAG 0
#define ELLIOTT_CYCLE 0
#define ELLIOTT_GRAND_SUPERCYCLE 0
#define ELLIOTT_INTERMEDIATE 0
#define ELLIOTT_MINOR 0
#define ELLIOTT_MINUETTE 0
#define ELLIOTT_MINUTE 0
#define ELLIOTT_PRIMARY 0
#define ELLIOTT_SUBMINUETTE 0
#define ELLIOTT_SUPERCYCLE 0
#define EMPTY_VALUE 0
#define ERR_ACCOUNT_WRONG_PROPERTY 0
#define ERR_ARRAY_BAD_SIZE 0
#define ERR_ARRAY_RESIZE_ERROR 0
#define ERR_BOOKS_CANNOT_ADD 0
#define ERR_BOOKS_CANNOT_DELETE 0
#define ERR_BOOKS_CANNOT_GET 0
#define ERR_BOOKS_CANNOT_SUBSCRIBE 0
#define ERR_BUFFERS_NO_MEMORY 0
#define ERR_BUFFERS_WRONG_INDEX 0
#define ERR_CANNOT_CLEAN_DIRECTORY 0
#define ERR_CANNOT_DELETE_DIRECTORY 0
#define ERR_CANNOT_DELETE_FILE 0
#define ERR_CANNOT_OPEN_FILE 0
#define ERR_CHAR_ARRAY_ONLY 0
#define ERR_CHART_CANNOT_CHANGE 0
#define ERR_CHART_CANNOT_CREATE_TIMER 0
#define ERR_CHART_CANNOT_OPEN 0
#define ERR_CHART_INDICATOR_CANNOT_ADD 0
#define ERR_CHART_INDICATOR_CANNOT_DEL 0
#define ERR_CHART_INDICATOR_NOT_FOUND 0
#define ERR_CHART_NAVIGATE_FAILED 0
#define ERR_CHART_NO_EXPERT 0
#define ERR_CHART_NO_REPLY 0
#define ERR_CHART_NOT_FOUND 0
#define ERR_CHART_SCREENSHOT_FAILED 0
#define ERR_CHART_TEMPLATE_FAILED 0
#define ERR_CHART_WINDOW_NOT_FOUND 0
#define ERR_CHART_WRONG_ID 0
#define ERR_CHART_WRONG_PARAMETER 0
#define ERR_CHART_WRONG_PROPERTY 0
#define ERR_CUSTOM_WRONG_PROPERTY 0
#define ERR_DIRECTORY_NOT_EXIST 0
#define ERR_DOUBLE_ARRAY_ONLY 0
#define ERR_FILE_BINSTRINGSIZE 0
#define ERR_FILE_CACHEBUFFER_ERROR 0
#define ERR_FILE_CANNOT_REWRITE 0
#define ERR_FILE_IS_DIRECTORY 0
#define ERR_FILE_ISNOT_DIRECTORY 0
#define ERR_FILE_NOT_EXIST 0
#define ERR_FILE_NOTBIN 0
#define ERR_FILE_NOTCSV 0
#define ERR_FILE_NOTTOREAD 0
#define ERR_FILE_NOTTOWRITE 0
#define ERR_FILE_NOTTXT 0
#define ERR_FILE_NOTTXTORCSV 0
#define ERR_FILE_READERROR 0
#define ERR_FILE_WRITEERROR 0
#define ERR_FLOAT_ARRAY_ONLY 0
#define ERR_FTP_SEND_FAILED 0
#define ERR_FUNCTION_NOT_ALLOWED 0
#define ERR_GLOBALVARIABLE_EXISTS 0
#define ERR_GLOBALVARIABLE_NOT_FOUND 0
#define ERR_HISTORY_NOT_FOUND 0
#define ERR_HISTORY_WRONG_PROPERTY 0
#define ERR_INCOMPATIBLE_ARRAYS 0
#define ERR_INCOMPATIBLE_FILE 0
#define ERR_INDICATOR_CANNOT_ADD 0
#define ERR_INDICATOR_CANNOT_APPLY 0
#define ERR_INDICATOR_CANNOT_CREATE 0
#define ERR_INDICATOR_CUSTOM_NAME 0
#define ERR_INDICATOR_DATA_NOT_FOUND 0
#define ERR_INDICATOR_NO_MEMORY 0
#define ERR_INDICATOR_PARAMETER_TYPE 0
#define ERR_INDICATOR_PARAMETERS_MISSING 0
#define ERR_INDICATOR_UNKNOWN_SYMBOL 0
#define ERR_INDICATOR_WRONG_HANDLE 0
#define ERR_INDICATOR_WRONG_INDEX 0
#define ERR_INDICATOR_WRONG_PARAMETERS 0
#define ERR_INT_ARRAY_ONLY 0
#define ERR_INTERNAL_ERROR 0
#define ERR_INVALID_ARRAY 0
#define ERR_INVALID_DATETIME 0
#define ERR_INVALID_FILEHANDLE 0
#define ERR_INVALID_PARAMETER 0
#define ERR_INVALID_POINTER 0
#define ERR_INVALID_POINTER_TYPE 0
#define ERR_LONG_ARRAY_ONLY 0
#define ERR_MAIL_SEND_FAILED 0
#define ERR_MARKET_LASTTIME_UNKNOWN 0
#define ERR_MARKET_NOT_SELECTED 0
#define ERR_MARKET_SELECT_ERROR 0
#define ERR_MARKET_UNKNOWN_SYMBOL 0
#define ERR_MARKET_WRONG_PROPERTY 0
#define ERR_MQL5_WRONG_PROPERTY 0
#define ERR_NO_STRING_DATE 0
#define ERR_NOT_ENOUGH_MEMORY 0
#define ERR_NOTIFICATION_SEND_FAILED 0
#define ERR_NOTIFICATION_TOO_FREQUENT 0
#define ERR_NOTIFICATION_WRONG_PARAMETER 0
#define ERR_NOTIFICATION_WRONG_SETTINGS 0
#define ERR_NOTINITIALIZED_STRING 0
#define ERR_NUMBER_ARRAYS_ONLY 0
#define ERR_OBJECT_ERROR 0
#define ERR_OBJECT_GETDATE_FAILED 0
#define ERR_OBJECT_GETVALUE_FAILED 0
#define ERR_OBJECT_NOT_FOUND 0
#define ERR_OBJECT_WRONG_PROPERTY 0
#define ERR_ONEDIM_ARRAYS_ONLY 0
#define ERR_OPENCL_BUFFER_CREATE 0
#define ERR_OPENCL_CONTEXT_CREATE 0
#define ERR_OPENCL_EXECUTE 0
#define ERR_OPENCL_INTERNAL 0
#define ERR_OPENCL_INVALID_HANDLE 0
#define ERR_OPENCL_KERNEL_CREATE 0
#define ERR_OPENCL_NOT_SUPPORTED 0
#define ERR_OPENCL_PROGRAM_CREATE 0
#define ERR_OPENCL_QUEUE_CREATE 0
#define ERR_OPENCL_SET_KERNEL_PARAMETER 0
#define ERR_OPENCL_TOO_LONG_KERNEL_NAME 0
#define ERR_OPENCL_WRONG_BUFFER_OFFSET 0
#define ERR_OPENCL_WRONG_BUFFER_SIZE 0
#define ERR_PLAY_SOUND_FAILED 0
#define ERR_RESOURCE_NAME_DUPLICATED 0
#define ERR_RESOURCE_NAME_IS_TOO_LONG 0
#define ERR_RESOURCE_NOT_FOUND 0
#define ERR_RESOURCE_UNSUPPOTED_TYPE 0
#define ERR_SERIES_ARRAY 0
#define ERR_SHORT_ARRAY_ONLY 0
#define ERR_SMALL_ARRAY 0
#define ERR_SMALL_ASSERIES_ARRAY 0
#define ERR_STRING_OUT_OF_MEMORY 0
#define ERR_STRING_RESIZE_ERROR 0
#define ERR_STRING_SMALL_LEN 0
#define ERR_STRING_TIME_ERROR 0
#define ERR_STRING_TOO_BIGNUMBER 0
#define ERR_STRING_UNKNOWNTYPE 0
#define ERR_STRING_ZEROADDED 0
#define ERR_STRINGPOS_OUTOFRANGE 0
#define ERR_STRUCT_WITHOBJECTS_ORCLASS 0
#define ERR_SUCCESS 0
#define ERR_TERMINAL_WRONG_PROPERTY 0
#define ERR_TOO_LONG_FILENAME 0
#define ERR_TOO_MANY_FILES 0
#define ERR_TOO_MANY_FORMATTERS 0
#define ERR_TOO_MANY_PARAMETERS 0
#define ERR_TRADE_DEAL_NOT_FOUND 0
#define ERR_TRADE_DISABLED 0
#define ERR_TRADE_ORDER_NOT_FOUND 0
#define ERR_TRADE_POSITION_NOT_FOUND 0
#define ERR_TRADE_SEND_FAILED 0
#define ERR_TRADE_WRONG_PROPERTY 0
#define ERR_USER_ERROR_FIRST 0
#define ERR_WEBREQUEST_CONNECT_FAILED 0
#define ERR_WEBREQUEST_INVALID_ADDRESS 0
#define ERR_WEBREQUEST_REQUEST_FAILED 0
#define ERR_WEBREQUEST_TIMEOUT 0
#define ERR_WRONG_DIRECTORYNAME 0
#define ERR_WRONG_FILEHANDLE 0
#define ERR_WRONG_FILENAME 0
#define ERR_WRONG_FORMATSTRING 0
#define ERR_WRONG_INTERNAL_PARAMETER 0
#define ERR_WRONG_STRING_DATE 0
#define ERR_WRONG_STRING_OBJECT 0
#define ERR_WRONG_STRING_PARAMETER 0
#define ERR_WRONG_STRING_TIME 0
#define ERR_ZEROSIZE_ARRAY 0
#define FILE_ACCESS_DATE 0
#define FILE_ANSI 0
#define FILE_BIN 0
#define FILE_COMMON 0
#define FILE_CREATE_DATE 0
#define FILE_CSV 0
#define FILE_END 0
#define FILE_EXISTS 0
#define FILE_IS_ANSI 0
#define FILE_IS_BINARY 0
#define FILE_IS_COMMON 0
#define FILE_IS_CSV 0
#define FILE_IS_READABLE 0
#define FILE_IS_TEXT 0
#define FILE_IS_WRITABLE 0
#define FILE_LINE_END 0
#define FILE_MODIFY_DATE 0
#define FILE_POSITION 0
#define FILE_READ 0
#define FILE_REWRITE 0
#define FILE_SHARE_READ 0
#define FILE_SHARE_WRITE 0
#define FILE_SIZE 0
#define FILE_TXT 0
#define FILE_UNICODE 0
#define FILE_WRITE 0
#define FLT_DIG 0
#define FLT_EPSILON 0
#define FLT_MANT_DIG 0
#define FLT_MAX 0
#define FLT_MAX_10_EXP 0
#define FLT_MAX_EXP 0
#define FLT_MIN 0
#define FLT_MIN_10_EXP 0
#define FLT_MIN_EXP 0
#define FRIDAY 0
#define GANN_DOWN_TREND 0
#define GANN_UP_TREND 0
#define GATORJAW_LINE 0
#define GATORLIPS_LINE 0
#define GATORTEETH_LINE 0
#define IDABORT 0
#define IDCANCEL 0
#define IDCONTINUE 0
#define IDIGNORE 0
#define IDNO 0
#define IDOK 0
#define IDRETRY 0
#define IDTRYAGAIN 0
#define IDYES 0
#define IND_AC 0
#define IND_AD 0
#define IND_ADX 0
#define IND_ADXW 0
#define IND_ALLIGATOR 0
#define IND_AMA 0
#define IND_AO 0
#define IND_ATR 0
#define IND_BANDS 0
#define IND_BEARS 0
#define IND_BULLS 0
#define IND_BWMFI 0
#define IND_CCI 0
#define IND_CHAIKIN 0
#define IND_CUSTOM 0
#define IND_DEMA 0
#define IND_DEMARKER 0
#define IND_ENVELOPES 0
#define IND_FORCE 0
#define IND_FRACTALS 0
#define IND_FRAMA 0
#define IND_GATOR 0
#define IND_ICHIMOKU 0
#define IND_MA 0
#define IND_MACD 0
#define IND_MFI 0
#define IND_MOMENTUM 0
#define IND_OBV 0
#define IND_OSMA 0
#define IND_RSI 0
#define IND_RVI 0
#define IND_SAR 0
#define IND_STDDEV 0
#define IND_STOCHASTIC 0
#define IND_TEMA 0
#define IND_TRIX 0
#define IND_VIDYA 0
#define IND_VOLUMES 0
#define IND_WPR 0
// #define INDICATOR_CALCULATIONS 0
// #define INDICATOR_COLOR_INDEX 0
// #define INDICATOR_DATA 0
#define INDICATOR_DIGITS 0
#define INDICATOR_HEIGHT 0
#define INDICATOR_LEVELCOLOR 0
#define INDICATOR_LEVELS 0
#define INDICATOR_LEVELSTYLE 0
#define INDICATOR_LEVELTEXT 0
#define INDICATOR_LEVELVALUE 0
#define INDICATOR_LEVELWIDTH 0
#define INDICATOR_MAXIMUM 0
#define INDICATOR_MINIMUM 0
#define INDICATOR_SHORTNAME 0
#define INT_MAX 0
#define INT_MIN 0
#define INVALID_HANDLE 0
#define IS_DEBUG_MODE 0
#define IS_PROFILE_MODE 0
#define KIJUNSEN_LINE 0
#define LICENSE_DEMO 0
#define LICENSE_FREE 0
#define LICENSE_FULL 0
#define LICENSE_TIME 0
#define LONG_MAX 0
#define LONG_MIN 0
#define LOWER_BAND 0
#define LOWER_HISTOGRAM 0
#define LOWER_LINE 0
#define M_1_PI 0
#define M_2_PI 0
#define M_2_SQRTPI 0
#define M_E 0
#define M_LN10 0
#define M_LN2 0
#define M_LOG10E 0
#define M_LOG2E 0
#define M_PI 0
#define M_PI_2 0
#define M_PI_4 0
#define M_SQRT1_2 0
#define M_SQRT2 0
#define MAIN_LINE 0
#define MB_ABORTRETRYIGNORE 0
#define MB_CANCELTRYCONTINUE 0
#define MB_DEFBUTTON1 0
#define MB_DEFBUTTON2 0
#define MB_DEFBUTTON3 0
#define MB_DEFBUTTON4 0
#define MB_ICONEXCLAMATION 0
#define MB_ICONWARNING 0
#define MB_ICONINFORMATION 0
#define MB_ICONASTERISK 0
#define MB_ICONQUESTION 0
#define MB_ICONSTOP 0
#define MB_ICONERROR 0
#define MB_ICONHAND 0
#define MB_OK 0
#define MB_OKCANCEL 0
#define MB_RETRYCANCEL 0
#define MB_YESNO 0
#define MB_YESNOCANCEL 0
#define MINUSDI_LINE 0
/*
#define MODE_EMA 0
#define MODE_LWMA 0
#define MODE_SMA 0
#define MODE_SMMA 0
*/
#define MONDAY 0
#define MQL_DEBUG 0
#define MQL_DLLS_ALLOWED 0
#define MQL_FRAME_MODE 0
#define MQL_LICENSE_TYPE 0
#define MQL_MEMORY_LIMIT 0
#define MQL_MEMORY_USED 0
#define MQL_OPTIMIZATION 0
#define MQL_PROFILER 0
#define MQL_PROGRAM_NAME 0
#define MQL_PROGRAM_PATH 0
#define MQL_PROGRAM_TYPE 0
#define MQL_SIGNALS_ALLOWED 0
#define MQL_TESTER 0
#define MQL_TRADE_ALLOWED 0
#define MQL_VISUAL_MODE 0
#define NULL 0
#define OBJ_ALL_PERIODS 0
#define OBJ_ARROW 0
#define OBJ_ARROW_BUY 0
#define OBJ_ARROW_CHECK 0
#define OBJ_ARROW_DOWN 0
#define OBJ_ARROW_LEFT_PRICE 0
#define OBJ_ARROW_RIGHT_PRICE 0
#define OBJ_ARROW_SELL 0
#define OBJ_ARROW_STOP 0
#define OBJ_ARROW_THUMB_DOWN 0
#define OBJ_ARROW_THUMB_UP 0
#define OBJ_ARROW_UP 0
#define OBJ_ARROWED_LINE 0
#define OBJ_BITMAP 0
#define OBJ_BITMAP_LABEL 0
#define OBJ_BUTTON 0
#define OBJ_CHANNEL 0
#define OBJ_CHART 0
#define OBJ_CYCLES 0
#define OBJ_EDIT 0
#define OBJ_ELLIOTWAVE3 0
#define OBJ_ELLIOTWAVE5 0
#define OBJ_ELLIPSE 0
#define OBJ_EVENT 0
#define OBJ_EXPANSION 0
#define OBJ_FIBO 0
#define OBJ_FIBOARC 0
#define OBJ_FIBOCHANNEL 0
#define OBJ_FIBOFAN 0
#define OBJ_FIBOTIMES 0
#define OBJ_GANNFAN 0
#define OBJ_GANNGRID 0
#define OBJ_GANNLINE 0
#define OBJ_HLINE 0
#define OBJ_LABEL 0
#define OBJ_NO_PERIODS 0
#define OBJ_PERIOD_D1 0
#define OBJ_PERIOD_H1 0
#define OBJ_PERIOD_H12 0
#define OBJ_PERIOD_H2 0
#define OBJ_PERIOD_H3 0
#define OBJ_PERIOD_H4 0
#define OBJ_PERIOD_H6 0
#define OBJ_PERIOD_H8 0
#define OBJ_PERIOD_M1 0
#define OBJ_PERIOD_M10 0
#define OBJ_PERIOD_M12 0
#define OBJ_PERIOD_M15 0
#define OBJ_PERIOD_M2 0
#define OBJ_PERIOD_M20 0
#define OBJ_PERIOD_M3 0
#define OBJ_PERIOD_M30 0
#define OBJ_PERIOD_M4 0
#define OBJ_PERIOD_M5 0
#define OBJ_PERIOD_M6 0
#define OBJ_PERIOD_MN1 0
#define OBJ_PERIOD_W1 0
#define OBJ_PITCHFORK 0
#define OBJ_RECTANGLE 0
#define OBJ_RECTANGLE_LABEL 0
#define OBJ_REGRESSION 0
#define OBJ_STDDEVCHANNEL 0
#define OBJ_TEXT 0
#define OBJ_TREND 0
#define OBJ_TRENDBYANGLE 0
#define OBJ_TRIANGLE 0
#define OBJ_VLINE 0
#define OBJPROP_ALIGN 0
#define OBJPROP_ANCHOR 0
#define OBJPROP_ANGLE 0
#define OBJPROP_ARROWCODE 0
#define OBJPROP_BACK 0
#define OBJPROP_BGCOLOR 0
#define OBJPROP_BMPFILE 0
#define OBJPROP_BORDER_COLOR 0
#define OBJPROP_BORDER_TYPE 0
#define OBJPROP_CHART_ID 0
#define OBJPROP_CHART_SCALE 0
#define OBJPROP_COLOR 0
#define OBJPROP_CORNER 0
#define OBJPROP_CREATETIME 0
#define OBJPROP_DATE_SCALE 0
#define OBJPROP_DEGREE 0
#define OBJPROP_DEVIATION 0
#define OBJPROP_DIRECTION 0
#define OBJPROP_DRAWLINES 0
#define OBJPROP_ELLIPSE 0
#define OBJPROP_FILL 0
#define OBJPROP_FONT 0
#define OBJPROP_FONTSIZE 0
#define OBJPROP_HIDDEN 0
#define OBJPROP_LEVELCOLOR 0
#define OBJPROP_LEVELS 0
#define OBJPROP_LEVELSTYLE 0
#define OBJPROP_LEVELTEXT 0
#define OBJPROP_LEVELVALUE 0
#define OBJPROP_LEVELWIDTH 0
#define OBJPROP_NAME 0
#define OBJPROP_PERIOD 0
#define OBJPROP_PRICE 0
#define OBJPROP_PRICE_SCALE 0
#define OBJPROP_RAY 0
#define OBJPROP_RAY_LEFT 0
#define OBJPROP_RAY_RIGHT 0
#define OBJPROP_READONLY 0
#define OBJPROP_SCALE 0
#define OBJPROP_SELECTABLE 0
#define OBJPROP_SELECTED 0
#define OBJPROP_STATE 0
#define OBJPROP_STYLE 0
#define OBJPROP_SYMBOL 0
#define OBJPROP_TEXT 0
#define OBJPROP_TIME 0
#define OBJPROP_TIMEFRAMES 0
#define OBJPROP_TOOLTIP 0
#define OBJPROP_TYPE 0
#define OBJPROP_WIDTH 0
#define OBJPROP_XDISTANCE 0
#define OBJPROP_XOFFSET 0
#define OBJPROP_XSIZE 0
#define OBJPROP_YDISTANCE 0
#define OBJPROP_YOFFSET 0
#define OBJPROP_YSIZE 0
#define OBJPROP_ZORDER 0
#define ORDER_COMMENT 0
#define ORDER_FILLING_FOK 0
#define ORDER_FILLING_IOC 0
#define ORDER_FILLING_RETURN 0
#define ORDER_MAGIC 0
#define ORDER_POSITION_ID 0
#define ORDER_PRICE_CURRENT 0
#define ORDER_PRICE_OPEN 0
#define ORDER_PRICE_STOPLIMIT 0
#define ORDER_SL 0
#define ORDER_STATE 0
#define ORDER_STATE_CANCELED 0
#define ORDER_STATE_EXPIRED 0
#define ORDER_STATE_FILLED 0
#define ORDER_STATE_PARTIAL 0
#define ORDER_STATE_PLACED 0
#define ORDER_STATE_REJECTED 0
#define ORDER_STATE_REQUEST_ADD 0
#define ORDER_STATE_REQUEST_CANCEL 0
#define ORDER_STATE_REQUEST_MODIFY 0
#define ORDER_STATE_STARTED 0
#define ORDER_SYMBOL 0
#define ORDER_TIME_DAY 0
#define ORDER_TIME_DONE 0
#define ORDER_TIME_DONE_MSC 0
#define ORDER_TIME_EXPIRATION 0
#define ORDER_TIME_GTC 0
#define ORDER_TIME_SETUP 0
#define ORDER_TIME_SETUP_MSC 0
#define ORDER_TIME_SPECIFIED 0
#define ORDER_TIME_SPECIFIED_DAY 0
#define ORDER_TP 0
#define ORDER_TYPE 0
#define ORDER_TYPE_BUY 0
#define ORDER_TYPE_BUY_LIMIT 0
#define ORDER_TYPE_BUY_STOP 0
#define ORDER_TYPE_BUY_STOP_LIMIT 0
#define ORDER_TYPE_FILLING 0
#define ORDER_TYPE_SELL 0
#define ORDER_TYPE_SELL_LIMIT 0
#define ORDER_TYPE_SELL_STOP 0
#define ORDER_TYPE_SELL_STOP_LIMIT 0
#define ORDER_TYPE_TIME 0
#define ORDER_VOLUME_CURRENT 0
#define ORDER_VOLUME_INITIAL 0
#define PERIOD_CURRENT 0
// #define PERIOD_D1 0
// #define PERIOD_H1 0
#define PERIOD_H12 0
#define PERIOD_H2 0
#define PERIOD_H3 0
// #define PERIOD_H4 0
#define PERIOD_H6 0
#define PERIOD_H8 0
// #define PERIOD_M1 0
#define PERIOD_M10 0
#define PERIOD_M12 0
// #define PERIOD_M15 0
#define PERIOD_M2 0
#define PERIOD_M20 0
#define PERIOD_M3 0
// #define PERIOD_M30 0
#define PERIOD_M4 0
// #define PERIOD_M5 0
#define PERIOD_M6 0
// #define PERIOD_MN1 0
#define PERIOD_W1 0
#define PLOT_ARROW 0
#define PLOT_ARROW_SHIFT 0
#define PLOT_COLOR_INDEXES 0
#define PLOT_DRAW_BEGIN 0
#define PLOT_DRAW_TYPE 0
#define PLOT_EMPTY_VALUE 0
#define PLOT_LABEL 0
#define PLOT_LINE_COLOR 0
#define PLOT_LINE_STYLE 0
#define PLOT_LINE_WIDTH 0
#define PLOT_SHIFT 0
#define PLOT_SHOW_DATA 0
#define PLUSDI_LINE 0
// #define POINTER_AUTOMATIC 0
// #define POINTER_DYNAMIC 0
// #define POINTER_INVALID 0
#define POSITION_COMMENT 0
#define POSITION_COMMISSION 0
#define POSITION_IDENTIFIER 0
#define POSITION_MAGIC 0
#define POSITION_PRICE_CURRENT 0
#define POSITION_PRICE_OPEN 0
#define POSITION_PROFIT 0
#define POSITION_SL 0
#define POSITION_SWAP 0
#define POSITION_SYMBOL 0
#define POSITION_TIME 0
#define POSITION_TIME_MSC 0
#define POSITION_TIME_UPDATE 0
#define POSITION_TIME_UPDATE_MSC 0
#define POSITION_TP 0
#define POSITION_TYPE 0
#define POSITION_TYPE_BUY 0
#define POSITION_TYPE_SELL 0
#define POSITION_VOLUME 0
/*
#define PRICE_CLOSE 0
#define PRICE_HIGH 0
#define PRICE_LOW 0
#define PRICE_MEDIAN 0
#define PRICE_OPEN 0
#define PRICE_TYPICAL 0
#define PRICE_WEIGHTED 0
*/
#define PROGRAM_EXPERT 0
#define PROGRAM_INDICATOR 0
#define PROGRAM_SCRIPT 0
// #define REASON_ACCOUNT 0
// #define REASON_CHARTCHANGE 0
// #define REASON_CHARTCLOSE 0
// #define REASON_CLOSE 0
// #define REASON_INITFAILED 0
// #define REASON_PARAMETERS 0
// #define REASON_PROGRAM 0
// #define REASON_RECOMPILE 0
// #define REASON_REMOVE 0
// #define REASON_TEMPLATE 0
#define SATURDAY 0
#define SEEK_CUR 0
#define SEEK_END 0
#define SEEK_SET 0
#define SENKOUSPANA_LINE 0
#define SENKOUSPANB_LINE 0
#define SERIES_BARS_COUNT 0
#define SERIES_FIRSTDATE 0
#define SERIES_LASTBAR_DATE 0
#define SERIES_SERVER_FIRSTDATE 0
#define SERIES_SYNCHRONIZED 0
#define SERIES_TERMINAL_FIRSTDATE 0
#define SHORT_MAX 0
#define SHORT_MIN 0
#define SIGNAL_BASE_AUTHOR_LOGIN 0
#define SIGNAL_BASE_BALANCE 0
#define SIGNAL_BASE_BROKER 0
#define SIGNAL_BASE_BROKER_SERVER 0
#define SIGNAL_BASE_CURRENCY 0
#define SIGNAL_BASE_DATE_PUBLISHED 0
#define SIGNAL_BASE_DATE_STARTED 0
#define SIGNAL_BASE_EQUITY 0
#define SIGNAL_BASE_GAIN 0
#define SIGNAL_BASE_ID 0
#define SIGNAL_BASE_LEVERAGE 0
#define SIGNAL_BASE_MAX_DRAWDOWN 0
#define SIGNAL_BASE_NAME 0
#define SIGNAL_BASE_PIPS 0
#define SIGNAL_BASE_PRICE 0
#define SIGNAL_BASE_RATING 0
#define SIGNAL_BASE_ROI 0
#define SIGNAL_BASE_SUBSCRIBERS 0
#define SIGNAL_BASE_TRADE_MODE 0
#define SIGNAL_BASE_TRADES 0
#define SIGNAL_INFO_CONFIRMATIONS_DISABLED 0
#define SIGNAL_INFO_COPY_SLTP 0
#define SIGNAL_INFO_DEPOSIT_PERCENT 0
#define SIGNAL_INFO_EQUITY_LIMIT 0
#define SIGNAL_INFO_ID 0
#define SIGNAL_INFO_NAME 0
#define SIGNAL_INFO_SLIPPAGE 0
#define SIGNAL_INFO_SUBSCRIPTION_ENABLED 0
#define SIGNAL_INFO_TERMS_AGREE 0
#define SIGNAL_INFO_VOLUME_PERCENT 0
#define SIGNAL_LINE 0
#define STAT_BALANCE_DD 0
#define STAT_BALANCE_DD_RELATIVE 0
#define STAT_BALANCE_DDREL_PERCENT 0
#define STAT_BALANCEDD_PERCENT 0
#define STAT_BALANCEMIN 0
#define STAT_CONLOSSMAX 0
#define STAT_CONLOSSMAX_TRADES 0
#define STAT_CONPROFITMAX 0
#define STAT_CONPROFITMAX_TRADES 0
#define STAT_CUSTOM_ONTESTER 0
#define STAT_DEALS 0
#define STAT_EQUITY_DD 0
#define STAT_EQUITY_DD_RELATIVE 0
#define STAT_EQUITY_DDREL_PERCENT 0
#define STAT_EQUITYDD_PERCENT 0
#define STAT_EQUITYMIN 0
#define STAT_EXPECTED_PAYOFF 0
#define STAT_GROSS_LOSS 0
#define STAT_GROSS_PROFIT 0
#define STAT_INITIAL_DEPOSIT 0
#define STAT_LONG_TRADES 0
#define STAT_LOSS_TRADES 0
#define STAT_LOSSTRADES_AVGCON 0
#define STAT_MAX_CONLOSS_TRADES 0
#define STAT_MAX_CONLOSSES 0
#define STAT_MAX_CONPROFIT_TRADES 0
#define STAT_MAX_CONWINS 0
#define STAT_MAX_LOSSTRADE 0
#define STAT_MAX_PROFITTRADE 0
#define STAT_MIN_MARGINLEVEL 0
#define STAT_PROFIT 0
#define STAT_PROFIT_FACTOR 0
#define STAT_PROFIT_LONGTRADES 0
#define STAT_PROFIT_SHORTTRADES 0
#define STAT_PROFIT_TRADES 0
#define STAT_PROFITTRADES_AVGCON 0
#define STAT_RECOVERY_FACTOR 0
#define STAT_SHARPE_RATIO 0
#define STAT_SHORT_TRADES 0
#define STAT_TRADES 0
#define STAT_WITHDRAWAL 0
#define STO_CLOSECLOSE 0
#define STO_LOWHIGH 0
#define STYLE_DASH 0
#define STYLE_DASHDOT 0
#define STYLE_DASHDOTDOT 0
#define STYLE_DOT 0
#define STYLE_SOLID 0
#define SUNDAY 0
#define SYMBOL_ASK 0
#define SYMBOL_ASKHIGH 0
#define SYMBOL_ASKLOW 0
#define SYMBOL_BANK 0
#define SYMBOL_BASIS 0
#define SYMBOL_BID 0
#define SYMBOL_BIDHIGH 0
#define SYMBOL_BIDLOW 0
#define SYMBOL_CALC_MODE_CFD 0
#define SYMBOL_CALC_MODE_CFDINDEX 0
#define SYMBOL_CALC_MODE_CFDLEVERAGE 0
#define SYMBOL_CALC_MODE_EXCH_FUTURES 0
#define SYMBOL_CALC_MODE_EXCH_FUTURES_FORTS 0
#define SYMBOL_CALC_MODE_EXCH_STOCKS 0
#define SYMBOL_CALC_MODE_FOREX 0
#define SYMBOL_CALC_MODE_FUTURES 0
#define SYMBOL_CALC_MODE_SERV_COLLATERAL 0
#define SYMBOL_CURRENCY_BASE 0
#define SYMBOL_CURRENCY_MARGIN 0
#define SYMBOL_CURRENCY_PROFIT 0
#define SYMBOL_DESCRIPTION 0
#define SYMBOL_DIGITS 0
#define SYMBOL_EXPIRATION_DAY 0
#define SYMBOL_EXPIRATION_GTC 0
#define SYMBOL_EXPIRATION_MODE 0
#define SYMBOL_EXPIRATION_SPECIFIED 0
#define SYMBOL_EXPIRATION_SPECIFIED_DAY 0
#define SYMBOL_EXPIRATION_TIME 0
#define SYMBOL_FILLING_FOK 0
#define SYMBOL_FILLING_IOC 0
#define SYMBOL_FILLING_MODE 0
#define SYMBOL_ISIN 0
#define SYMBOL_LAST 0
#define SYMBOL_LASTHIGH 0
#define SYMBOL_LASTLOW 0
#define SYMBOL_MARGIN_INITIAL 0
#define SYMBOL_MARGIN_MAINTENANCE 0
#define SYMBOL_OPTION_MODE 0
#define SYMBOL_OPTION_MODE_EUROPEAN 0
#define SYMBOL_OPTION_MODE_AMERICAN 0
#define SYMBOL_OPTION_RIGHT 0
#define SYMBOL_OPTION_RIGHT_CALL 0
#define SYMBOL_OPTION_RIGHT_PUT 0
#define SYMBOL_OPTION_STRIKE 0
#define SYMBOL_ORDER_LIMIT 0
#define SYMBOL_ORDER_MARKET 0
#define SYMBOL_ORDER_MODE 0
#define SYMBOL_ORDER_SL 0
#define SYMBOL_ORDER_STOP 0
#define SYMBOL_ORDER_STOP_LIMIT 0
#define SYMBOL_ORDER_TP 0
#define SYMBOL_PATH 0
#define SYMBOL_POINT 0
#define SYMBOL_SELECT 0
#define SYMBOL_SESSION_AW 0
#define SYMBOL_SESSION_BUY_ORDERS 0
#define SYMBOL_SESSION_BUY_ORDERS_VOLUME 0
#define SYMBOL_SESSION_CLOSE 0
#define SYMBOL_SESSION_DEALS 0
#define SYMBOL_SESSION_INTEREST 0
#define SYMBOL_SESSION_OPEN 0
#define SYMBOL_SESSION_PRICE_LIMIT_MAX 0
#define SYMBOL_SESSION_PRICE_LIMIT_MIN 0
#define SYMBOL_SESSION_PRICE_SETTLEMENT 0
#define SYMBOL_SESSION_SELL_ORDERS 0
#define SYMBOL_SESSION_SELL_ORDERS_VOLUME 0
#define SYMBOL_SESSION_TURNOVER 0
#define SYMBOL_SESSION_VOLUME 0
#define SYMBOL_SPREAD 0
#define SYMBOL_SPREAD_FLOAT 0
#define SYMBOL_START_TIME 0
#define SYMBOL_SWAP_LONG 0
#define SYMBOL_SWAP_MODE 0
#define SYMBOL_SWAP_MODE_CURRENCY_DEPOSIT 0
#define SYMBOL_SWAP_MODE_CURRENCY_MARGIN 0
#define SYMBOL_SWAP_MODE_CURRENCY_SYMBOL 0
#define SYMBOL_SWAP_MODE_DISABLED 0
#define SYMBOL_SWAP_MODE_INTEREST_CURRENT 0
#define SYMBOL_SWAP_MODE_INTEREST_OPEN 0
#define SYMBOL_SWAP_MODE_POINTS 0
#define SYMBOL_SWAP_MODE_REOPEN_BID 0
#define SYMBOL_SWAP_MODE_REOPEN_CURRENT 0
#define SYMBOL_SWAP_ROLLOVER3DAYS 0
#define SYMBOL_SWAP_SHORT 0
#define SYMBOL_TICKS_BOOKDEPTH 0
#define SYMBOL_TIME 0
#define SYMBOL_TRADE_CALC_MODE 0
#define SYMBOL_TRADE_CONTRACT_SIZE 0
#define SYMBOL_TRADE_EXECUTION_EXCHANGE 0
#define SYMBOL_TRADE_EXECUTION_INSTANT 0
#define SYMBOL_TRADE_EXECUTION_MARKET 0
#define SYMBOL_TRADE_EXECUTION_REQUEST 0
#define SYMBOL_TRADE_EXEMODE 0
#define SYMBOL_TRADE_FREEZE_LEVEL 0
#define SYMBOL_TRADE_MODE 0
#define SYMBOL_TRADE_MODE_CLOSEONLY 0
#define SYMBOL_TRADE_MODE_DISABLED 0
#define SYMBOL_TRADE_MODE_FULL 0
#define SYMBOL_TRADE_MODE_LONGONLY 0
#define SYMBOL_TRADE_MODE_SHORTONLY 0
#define SYMBOL_TRADE_STOPS_LEVEL 0
#define SYMBOL_TRADE_TICK_SIZE 0
#define SYMBOL_TRADE_TICK_VALUE 0
#define SYMBOL_TRADE_TICK_VALUE_LOSS 0
#define SYMBOL_TRADE_TICK_VALUE_PROFIT 0
#define SYMBOL_VOLUME 0
#define SYMBOL_VOLUME_LIMIT 0
#define SYMBOL_VOLUME_MAX 0
#define SYMBOL_VOLUME_MIN 0
#define SYMBOL_VOLUME_STEP 0
#define SYMBOL_VOLUMEHIGH 0
#define SYMBOL_VOLUMELOW 0
#define TENKANSEN_LINE 0
#define TERMINAL_BUILD 0
#define TERMINAL_CODEPAGE 0
#define TERMINAL_COMMONDATA_PATH 0
#define TERMINAL_COMMUNITY_ACCOUNT 0
#define TERMINAL_COMMUNITY_BALANCE 0
#define TERMINAL_COMMUNITY_CONNECTION 0
#define TERMINAL_COMPANY 0
#define TERMINAL_CONNECTED 0
#define TERMINAL_CPU_CORES 0
#define TERMINAL_DATA_PATH 0
#define TERMINAL_DISK_SPACE 0
#define TERMINAL_DLLS_ALLOWED 0
#define TERMINAL_EMAIL_ENABLED 0
#define TERMINAL_FTP_ENABLED 0
#define TERMINAL_LANGUAGE 0
#define TERMINAL_MAXBARS 0
#define TERMINAL_MEMORY_AVAILABLE 0
#define TERMINAL_MEMORY_PHYSICAL 0
#define TERMINAL_MEMORY_TOTAL 0
#define TERMINAL_MEMORY_USED 0
#define TERMINAL_MQID 0
#define TERMINAL_NAME 0
#define TERMINAL_NOTIFICATIONS_ENABLED 0
#define TERMINAL_OPENCL_SUPPORT 0
#define TERMINAL_PATH 0
#define TERMINAL_PING_LAST 0
#define TERMINAL_SCREEN_DPI 0
#define TERMINAL_TRADE_ALLOWED 0
#define TERMINAL_X64 0
#define THURSDAY 0
#define TRADE_ACTION_DEAL 0
#define TRADE_ACTION_MODIFY 0
#define TRADE_ACTION_PENDING 0
#define TRADE_ACTION_REMOVE 0
#define TRADE_ACTION_SLTP 0
#define TRADE_RETCODE_CANCEL 0
#define TRADE_RETCODE_CLIENT_DISABLES_AT 0
#define TRADE_RETCODE_CONNECTION 0
#define TRADE_RETCODE_DONE 0
#define TRADE_RETCODE_DONE_PARTIAL 0
#define TRADE_RETCODE_ERROR 0
#define TRADE_RETCODE_FROZEN 0
#define TRADE_RETCODE_INVALID 0
#define TRADE_RETCODE_INVALID_EXPIRATION 0
#define TRADE_RETCODE_INVALID_FILL 0
#define TRADE_RETCODE_INVALID_ORDER 0
#define TRADE_RETCODE_INVALID_PRICE 0
#define TRADE_RETCODE_INVALID_STOPS 0
#define TRADE_RETCODE_INVALID_VOLUME 0
#define TRADE_RETCODE_LIMIT_ORDERS 0
#define TRADE_RETCODE_LIMIT_VOLUME 0
#define TRADE_RETCODE_LOCKED 0
#define TRADE_RETCODE_MARKET_CLOSED 0
#define TRADE_RETCODE_NO_CHANGES 0
#define TRADE_RETCODE_NO_MONEY 0
#define TRADE_RETCODE_ONLY_REAL 0
#define TRADE_RETCODE_ORDER_CHANGED 0
#define TRADE_RETCODE_PLACED 0
#define TRADE_RETCODE_POSITION_CLOSED 0
#define TRADE_RETCODE_PRICE_CHANGED 0
#define TRADE_RETCODE_PRICE_OFF 0
#define TRADE_RETCODE_REJECT 0
#define TRADE_RETCODE_REQUOTE 0
#define TRADE_RETCODE_SERVER_DISABLES_AT 0
#define TRADE_RETCODE_TIMEOUT 0
#define TRADE_RETCODE_TOO_MANY_REQUESTS 0
#define TRADE_RETCODE_TRADE_DISABLED 0
#define TRADE_TRANSACTION_DEAL_ADD 0
#define TRADE_TRANSACTION_DEAL_DELETE 0
#define TRADE_TRANSACTION_DEAL_UPDATE 0
#define TRADE_TRANSACTION_HISTORY_ADD 0
#define TRADE_TRANSACTION_HISTORY_DELETE 0
#define TRADE_TRANSACTION_HISTORY_UPDATE 0
#define TRADE_TRANSACTION_ORDER_ADD 0
#define TRADE_TRANSACTION_ORDER_DELETE 0
#define TRADE_TRANSACTION_ORDER_UPDATE 0
#define TRADE_TRANSACTION_POSITION 0
#define TRADE_TRANSACTION_REQUEST 0
#define TUESDAY 0
#define TYPE_BOOL 0
#define TYPE_CHAR 0
#define TYPE_COLOR 0
#define TYPE_DATETIME 0
#define TYPE_DOUBLE 0
#define TYPE_FLOAT 0
#define TYPE_INT 0
#define TYPE_LONG 0
#define TYPE_SHORT 0
#define TYPE_STRING 0
#define TYPE_UCHAR 0
#define TYPE_UINT 0
#define TYPE_ULONG 0
#define TYPE_USHORT 0
#define UCHAR_MAX 0
#define UINT_MAX 0
#define ULONG_MAX 0
#define UPPER_BAND 0
#define UPPER_HISTOGRAM 0
#define UPPER_LINE 0
#define USHORT_MAX 0
#define VOLUME_REAL 0
#define VOLUME_TICK 0
#define WEDNESDAY 0
#define WHOLE_ARRAY 0
#define WRONG_VALUE 0
#define AccountInfoDouble() 0
#define AccountInfoInteger() 0
#define AccountInfoString() 0
#define acos() 0
// #define Alert() 0
#define ArrayBsearch() 0
#define ArrayCompare() 0
#define ArrayCopy() 0
#define ArrayFill() 0
// #define ArrayFree() 0
#define ArrayGetAsSeries() 0
#define ArrayInitialize() 0
#define ArrayIsDynamic() 0
#define ArrayIsSeries() 0
#define ArrayMaximum() 0
#define ArrayMinimum() 0
#define ArrayRange() 0
// #define ArrayResize() 0
// #define ArraySetAsSeries() 0
// #define ArraySize() 0
#define ArraySort() 0
#define asin() 0
#define atan() 0
#define Bars() 0
#define BarsCalculated() 0
// #define ceil() 0
#define CharArrayToString() 0
#define ChartApplyTemplate() 0
#define ChartClose() 0
#define ChartFirst() 0
#define ChartGetDouble() 0
#define ChartGetInteger() 0
#define ChartGetString() 0
#define ChartID() 0
#define ChartIndicatorAdd() 0
#define ChartIndicatorDelete() 0
#define ChartIndicatorGet() 0
#define ChartIndicatorName() 0
#define ChartIndicatorsTotal() 0
#define ChartNavigate() 0
#define ChartNext() 0
#define ChartOpen() 0
#define CharToString() 0
// #define ChartPeriod() 0
#define ChartPriceOnDropped() 0
#define ChartRedraw() 0
#define ChartSaveTemplate() 0
#define ChartScreenShot() 0
#define ChartSetDouble() 0
#define ChartSetInteger() 0
#define ChartSetString() 0
#define ChartSetSymbolPeriod() 0
// #define ChartSymbol() 0
#define ChartTimeOnDropped() 0
#define ChartTimePriceToXY() 0
#define ChartWindowFind() 0
#define ChartWindowOnDropped() 0
#define ChartXOnDropped() 0
#define ChartXYToTimePrice() 0
#define ChartYOnDropped() 0
// #define CheckPointer() 0
#define CLBufferCreate() 0
#define CLBufferFree() 0
#define CLBufferRead() 0
#define CLBufferWrite() 0
#define CLContextCreate() 0
#define CLContextFree() 0
#define CLExecute() 0
#define CLGetDeviceInfo() 0
#define CLGetInfoInteger() 0
#define CLHandleType() 0
#define CLKernelCreate() 0
#define CLKernelFree() 0
#define CLProgramCreate() 0
#define CLProgramFree() 0
#define CLSetKernelArg() 0
#define CLSetKernelArgMem() 0
#define ColorToARGB() 0
#define ColorToString() 0
#define Comment() 0
#define CopyBuffer() 0
// #define CopyClose() 0
// #define CopyHigh() 0
// #define CopyLow() 0
// #define CopyOpen() 0
// #define CopyRates() 0
#define CopyRealVolume() 0
#define CopySpread() 0
#define CopyTicks() 0
// #define CopyTickVolume() 0
// #define CopyTime() 0
// #define cos() 0
#define CryptDecode() 0
#define CryptEncode() 0
#define DebugBreak() 0
#define Digits() 0
#define DoubleToString() 0
#define EnumToString() 0
#define EventChartCustom() 0
#define EventKillTimer() 0
#define EventSetMillisecondTimer() 0
#define EventSetTimer() 0
#define exp() 0
#define ExpertRemove() 0
// #define fabs() 0
#define FileClose() 0
#define FileCopy() 0
#define FileDelete() 0
#define FileFindClose() 0
#define FileFindFirst() 0
#define FileFindNext() 0
#define FileFlush() 0
#define FileGetInteger() 0
#define FileIsEnding() 0
#define FileIsExist() 0
#define FileIsLineEnding() 0
#define FileMove() 0
#define FileOpen() 0
#define FileReadArray() 0
#define FileReadBool() 0
#define FileReadDatetime() 0
#define FileReadDouble() 0
#define FileReadFloat() 0
#define FileReadInteger() 0
#define FileReadLong() 0
#define FileReadNumber() 0
#define FileReadString() 0
#define FileReadStruct() 0
#define FileSeek() 0
#define FileSize() 0
#define FileTell() 0
#define FileWrite() 0
#define FileWriteArray() 0
#define FileWriteDouble() 0
#define FileWriteFloat() 0
#define FileWriteInteger() 0
#define FileWriteLong() 0
#define FileWriteString() 0
#define FileWriteStruct() 0
// #define floor() 0
// #define fmax() 0
// #define fmin() 0
// #define fmod() 0
#define FolderClean() 0
#define FolderCreate() 0
#define FolderDelete() 0
#define FrameAdd() 0
#define FrameFilter() 0
#define FrameFirst() 0
#define FrameInputs() 0
#define FrameNext() 0
#define GetLastError() 0
// #define GetPointer() 0
#define GetTickCount() 0
#define GlobalVariableCheck() 0
#define GlobalVariableDel() 0
#define GlobalVariableGet() 0
#define GlobalVariableName() 0
#define GlobalVariablesDeleteAll() 0
#define GlobalVariableSet() 0
#define GlobalVariableSetOnCondition() 0
#define GlobalVariablesFlush() 0
#define GlobalVariablesTotal() 0
#define GlobalVariableTemp() 0
#define GlobalVariableTime() 0
#define HistoryDealGetDouble() 0
#define HistoryDealGetInteger() 0
#define HistoryDealGetString() 0
#define HistoryDealGetTicket() 0
#define HistoryDealSelect() 0
#define HistoryDealsTotal() 0
#define HistoryOrderGetDouble() 0
#define HistoryOrderGetInteger() 0
#define HistoryOrderGetString() 0
#define HistoryOrderGetTicket() 0
#define HistoryOrderSelect() 0
#define HistoryOrdersTotal() 0
#define HistorySelect() 0
#define HistorySelectByPosition() 0
#define iAC() 0
#define iAD() 0
// #define iADX() 0
#define iADXWilder() 0
#define iAlligator() 0
#define iAMA() 0
#define iAO() 0
#define iATR() 0
#define iBands() 0
#define iBearsPower() 0
#define iBullsPower() 0
#define iBWMFI() 0
#define iCCI() 0
#define iChaikin() 0
#define iCustom() 0
#define iDEMA() 0
#define iDeMarker() 0
#define iEnvelopes() 0
#define iForce() 0
#define iFractals() 0
#define iFrAMA() 0
#define iGator() 0
#define iIchimoku() 0
#define iMA() 0
#define iMACD() 0
#define iMFI() 0
#define iMomentum() 0
#define IndicatorCreate() 0
#define IndicatorParameters() 0
#define IndicatorRelease() 0
#define IndicatorSetDouble() 0
#define IndicatorSetInteger() 0
#define IndicatorSetString() 0
#define IntegerToString() 0
#define iOBV() 0
#define iOsMA() 0
#define iRSI() 0
#define iRVI() 0
#define iSAR() 0
#define IsStopped() 0
#define iStdDev() 0
#define iStochastic() 0
#define iTEMA() 0
#define iTriX() 0
#define iVIDyA() 0
#define iVolumes() 0
#define iWPR() 0
// #define log() 0
// #define log10() 0
#define MarketBookAdd() 0
#define MarketBookGet() 0
#define MarketBookRelease() 0
// #define MathAbs() 0
#define MathArccos() 0
#define MathArcsin() 0
#define MathArctan() 0
// #define MathCeil() 0
// #define MathCos() 0
// #define MathExp() 0
// #define MathFloor() 0
#define MathIsValidNumber() 0
// #define MathLog() 0
// #define MathLog10() 0
// #define MathMax() 0
// #define MathMin() 0
// #define MathMod() 0
// #define MathPow() 0
#define MathRand() 0
#define MathRound() 0
// #define MathSin() 0
// #define MathSqrt() 0
#define MathSrand() 0
// #define MathTan() 0
#define MessageBox() 0
#define MQLInfoInteger() 0
#define MQLInfoString() 0
#define NormalizeDouble() 0
#define ObjectCreate() 0
#define ObjectDelete() 0
#define ObjectFind() 0
#define ObjectGetDouble() 0
#define ObjectGetInteger() 0
#define ObjectGetString() 0
#define ObjectGetTimeByValue() 0
#define ObjectGetValueByTime() 0
#define ObjectMove() 0
#define ObjectName() 0
#define ObjectsDeleteAll() 0
#define ObjectSetDouble() 0
#define ObjectSetInteger() 0
#define ObjectSetString() 0
#define ObjectsTotal() 0
#define OrderCalcMargin() 0
#define OrderCalcProfit() 0
#define OrderCheck() 0
#define OrderGetDouble() 0
#define OrderGetInteger() 0
#define OrderGetString() 0
#define OrderGetTicket() 0
// #define OrderSelect() 0
// #define OrderSend() 0
#define OrderSendAsync() 0
// #define OrdersTotal() 0
#define ParameterGetRange() 0
#define ParameterSetRange() 0
#define Period() 0
#define PeriodSeconds() 0
#define PlaySound() 0
#define PlotIndexGetInteger() 0
#define PlotIndexSetDouble() 0
#define PlotIndexSetInteger() 0
#define PlotIndexSetString() 0
#define Point() 0
#define PositionGetDouble() 0
#define PositionGetInteger() 0
#define PositionGetString() 0
#define PositionGetSymbol() 0
#define PositionGetTicket() 0
#define PositionSelect() 0
#define PositionSelectByTicket() 0
#define PositionsTotal() 0
// #define pow() 0
// #define Print() 0
// #define printf() 0
// #define PrintFormat() 0
#define rand() 0
#define ResetLastError() 0
#define ResourceCreate() 0
#define ResourceFree() 0
#define ResourceReadImage() 0
#define ResourceSave() 0
#define round() 0
#define SendFTP() 0
#define SendMail() 0
#define SendNotification() 0
#define SeriesInfoInteger() 0
// #define SetIndexBuffer() 0
#define ShortArrayToString() 0
#define ShortToString() 0
#define SignalBaseGetDouble() 0
#define SignalBaseGetInteger() 0
#define SignalBaseGetString() 0
#define SignalBaseSelect() 0
#define SignalBaseTotal() 0
#define SignalInfoGetDouble() 0
#define SignalInfoGetInteger() 0
#define SignalInfoGetString() 0
#define SignalInfoSetDouble() 0
#define SignalInfoSetInteger() 0
#define SignalSubscribe() 0
#define SignalUnsubscribe() 0
// #define sin() 0
#define Sleep() 0
// #define sqrt() 0
#define srand() 0
#define StringAdd() 0
#define StringBufferLen() 0
#define StringCompare() 0
#define StringConcatenate() 0
#define StringFill() 0
#define StringFind() 0
// #define StringFormat() 0
#define StringGetCharacter() 0
#define StringInit() 0
#define StringLen() 0
#define StringReplace() 0
#define StringSetCharacter() 0
#define StringSplit() 0
#define StringSubstr() 0
#define StringToCharArray() 0
#define StringToColor() 0
#define StringToDouble() 0
#define StringToInteger() 0
#define StringToLower() 0
#define StringToShortArray() 0
#define StringToTime() 0
#define StringToUpper() 0
#define StringTrimLeft() 0
#define StringTrimRight() 0
#define StructToTime() 0
#define Symbol() 0
#define SymbolInfoDouble() 0
#define SymbolInfoInteger() 0
#define SymbolInfoMarginRate() 0
#define SymbolInfoSessionQuote() 0
#define SymbolInfoSessionTrade() 0
#define SymbolInfoString() 0
// #define SymbolInfoTick() 0
#define SymbolIsSynchronized() 0
#define SymbolName() 0
#define SymbolSelect() 0
#define SymbolsTotal() 0
// #define tan() 0
#define TerminalClose() 0
#define TerminalInfoDouble() 0
#define TerminalInfoInteger() 0
#define TerminalInfoString() 0
#define TesterStatistics() 0
#define TextGetSize() 0
#define TextOut() 0
#define TextSetFont() 0
#define TimeCurrent() 0
#define TimeDaylightSavings() 0
#define TimeGMT() 0
#define TimeGMTOffset() 0
#define TimeLocal() 0
// #define TimeToString() 0
#define TimeToStruct() 0
#define TimeTradeServer() 0
#define UninitializeReason() 0
#define WebRequest() 0
#define ZeroMemory() 0

#endif
