// symbol.mq4

#ifndef _SYMBOL_MQ4
#define _SYMBOL_MQ4 1

#property strict
#property library

#ifndef __MQLBUILD__
#include <MQLsyntax.mqh>
#endif


/// @brief Utility function for market symbol information
/// @param var [out] variable for the symbol info
/// @param prop [in] property for the symbol info
/// @param symbol [in] symbol for the symbol info
/// @return true if the symbol information was available, else false
bool symbolInfo(double &var, const int prop, const string symbol = NULL)
{
    return SymbolInfoDouble(symbol == NULL ? _Symbol : symbol, prop, var);
}

/// @brief Utility function for market symbol information
/// @param var [out] variable for the symbol info
/// @param prop [in] property for the symbol info
/// @param symbol [in] symbol for the symbol info
/// @return true if the symbol information was available, else false
bool symbolInfo(int &var, const int prop, const string symbol = NULL)
{
    long tmp;
    if (SymbolInfoInteger(symbol == NULL ? _Symbol : symbol, prop, tmp))
    {
        var = (int)tmp;
        return true;
    }
    else
    {
        return false;
    }
}

/// @brief Utility function for market symbol information
/// @param var [out] variable for the symbol info
/// @param prop [in] property for the symbol info
/// @param symbol [in] symbol for the symbol info
/// @return true if the symbol information was available, else false
bool symbolInfo(long &var, const int prop, const string symbol = NULL)
{
    return SymbolInfoInteger(symbol == NULL ? _Symbol : symbol, prop, var);
}


int symbolDigits(const string symbol = NULL) {
    if (symbol == NULL)
        return _Digits;
    int digits = EMPTY_VALUE;
    if (!symbolInfo(digits, SYMBOL_DIGITS, symbol)) {
        return INT_MIN;
    }
    return digits;
}


double symbolPoint(const string symbol = NULL) {
    if (symbol == NULL)
        return _Point;
    double points = EMPTY_VALUE; 
    if (!symbolInfo(points, SYMBOL_POINT, symbol)) {
        return DBL_MIN;
    }
    return points;
}


/// @brief return the points value (lots, pips) for a value in units of price
/// @param price the value in units of price
/// @return the points value (lots, pips) for the provided price value
///
long pricePoints(const double price, const string symbol = NULL)
{
    const double point = symbolPoint(symbol);
    return (long)(price / point);
}

/// @brief return the price value for a value in units of points (lots, pips)
/// @param lots the value in units of points
/// @return the price value for the provided point value
////
double pointsPrice(const long lots, const string symbol = NULL)
{
    const double point = symbolPoint(symbol);
    return NormalizeDouble(lots * point, Digits);
}

#endif