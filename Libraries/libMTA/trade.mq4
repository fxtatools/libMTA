#ifndef _TRADE_MQ4
#define _TRADE_MQ4 1

#ifndef __MQLBUILD__
#include <MQLsyntax.mqh>
#endif

#property library
#property strict

#include "chartable.mq4"
#include "quotes.mq4"
#include "indicator.mq4"
#include <stdlib.mqh>

static const bool __testing__ = MQLInfoInteger(MQL_TESTER) || MQLInfoInteger(MQL_VISUAL_MODE) || MQLInfoInteger(MQL_PROFILER) || MQLInfoInteger(MQL_DEBUG) || MQLInfoInteger(MQL_OPTIMIZATION) || MQLInfoInteger(MQL_FRAME_MODE);

class TradeProcess // : public Chartable
{
protected:
    // FIXME manage an array of quote mgr, one for each active timeframe and symbol
    // - array of QuoteMgr
    QuoteMgr *quote_mgrs[];
    // - array of indicators
    PriceIndicator *indicators[];
    // - with methods below ...
    int n_quote_mgrs; // LHS of a "1 to 1+" mapping onto indicators
    int n_indicators;
    // int
    datetime latest_quote_dt;

public:
    TradeProcess() : latest_quote_dt(EMPTY_VALUE)
    {

    }
    ~TradeProcess()
    {
        for (int n = 0; n < n_indicators; n++)
        {
            FREEPTR(indicators[n])
        };
        for (int n = 0; n < n_quote_mgrs; n++)
        {
            FREEPTR(quote_mgrs[n])
        };
    }

    virtual QuoteMgr *ensureQuoteMgr(const string _symbol = NULL, const int _timeframe = EMPTY_VALUE)
    {
        const string search_s = _symbol == NULL ? _Symbol : _symbol;
        const int search_tf = _timeframe == EMPTY_VALUE ? _Period : _timeframe;

        for (int n = 0; n < n_quote_mgrs; n++)
        {
            QuoteMgr *mgr = quote_mgrs[n];
            if (mgr.getSymbol() == search_s && mgr.getTimeframe() == search_tf)
            {
                return mgr;
            }
        }
        QuoteMgr *mgr = new QuoteMgr(0, true, search_s, search_tf);
        const int idx = n_quote_mgrs++;
        ArrayResize(quote_mgrs, n_quote_mgrs);
        quote_mgrs[idx] = mgr;
        return mgr;
    };

    virtual void addIndicator(PriceIndicator *indicator) {
        // FIXME add the indicator to some linked object, pairing the quote manager with same
        ensureQuoteMgr(indicator.getSymbol(), indicator.getTimeframe());
        const int idx = n_indicators++;
        ArrayResize(indicators, n_indicators);
        indicators[idx] = indicator;
    };

    virtual bool removeIndicator(PriceIndicator *indicator) {
        // FIXME needs test
        int idx = EMPTY;
        for(int n = 0; n < n_indicators; n++) {
            if (indicators[n] == indicator) {
                idx = n;
                break;
            }
        }
        if(idx == EMPTY) return false;
        const int nend = n_indicators - 1;
        for (int n = idx; n < nend; n++) {
            indicators[n] = indicators[n+1];
        }
        n_indicators--;
        ArrayResize(indicators, n_indicators);
        return true;
    }


    virtual bool fetchQuotes(const int count = EMPTY) {
        DEBUG("Fetching quotes");
        for (int nq = 0; nq < n_quote_mgrs; nq++) {
            QuoteMgr *mgr = quote_mgrs[nq];
            int nr_quotes = count == EMPTY ? mgr.latestQuoteShift() + 1 : count;
            for (int ni = 0; ni < n_indicators; ni++) {
                PriceIndicator *in = indicators[ni];
                if(in.getSymbol() == mgr.getSymbol() && in.getTimeframe() == mgr.getTimeframe()) {
                    const int in_quotes = in.indicatorUpdateShift(count);
                    if(in_quotes > nr_quotes) nr_quotes = in_quotes;
                };
            }
            DEBUG("Fetching %d quotes for %s, %d", nr_quotes, mgr.getSymbol(), mgr.getTimeframe());
            if (!mgr.updateQuotes(nr_quotes)) {
                    handleError(StringFormat("Failed to fetch %d quotes, %s %d", nr_quotes, mgr.getSymbol(), mgr.getTimeframe()));
                    return false;
            }
        }
        return true;
    }

    virtual bool updateIndicators() {
        if (!fetchQuotes()) {
            handleError("Failed to fetch quotes for indicator update");
            return false;
        };
        for (int nq = 0; nq < n_quote_mgrs; nq++) {
            QuoteMgr *mgr = quote_mgrs[nq];
            for (int ni = 0; ni < n_indicators; ni++) {
                PriceIndicator *in = indicators[ni];
                if(in.getSymbol() == mgr.getSymbol() && in.getTimeframe() == mgr.getTimeframe()) {
                    if (!in.updateVars(mgr)) {
                        handleError("Failed to update indicator " + in.indicatorName());
                        return false;
                    }
                }
            }
        }
        return true;
    }

    virtual bool initIndicators(const int nrquotes) {
        // FIXME implement a QuoteDispatcher class
        // and move the AddIndicator, UpdateIndicator process to there

        DEBUG("Initializing indicators for %d quotes", nrquotes);
        if (!fetchQuotes(nrquotes)) {
            handleError("Failed to fetch quotes for indicator initialization");
            return false;
        };
        for (int nq = 0; nq < n_quote_mgrs; nq++) {
            QuoteMgr *mgr = quote_mgrs[nq];
            DEBUG("Initializing for %s, %d", mgr.getSymbol(), mgr.getTimeframe());
            for (int ni = 0; ni < n_indicators; ni++) {
                PriceIndicator *in = indicators[ni];
                if(in.getSymbol() == mgr.getSymbol() && in.getTimeframe() == mgr.getTimeframe()) {
                    DEBUG("Initializing for indicator" + in.indicatorName());
                    if (!in.initVars(nrquotes, mgr)) {
                        handleError(StringFormat("Failed to initialize indicator %s with %d quotes", in.indicatorName(), nrquotes));
                        return false;
                    }
                }
            }
        }
        return true;
    }

    /// @brief initialize this EA, fetching initial quote information
    /// @param nr_quotes
    /// @return initialization result code
    virtual ENUM_INIT_RETCODE initialize(const int nr_quotes)
    {
        if (!initIndicators(nr_quotes))
        {
            showError("Unable to initialize quote data");
            return INIT_FAILED;
        }

        return INIT_SUCCEEDED;
    }

    virtual void deinitialize(const int dicode) = 0;

    virtual void handleTick()
    {
        if (!updateIndicators())
        {
            handleError("Unable to update indicator data");
        }
    }

    virtual bool continuableError(int errno)
    {
        switch (errno)
        {
        case ERR_TRADE_NOT_ALLOWED:
            // ensure the EA continues running analysis
            // when auto-trading is disabled
            return true;
        case ERR_TRADE_DISABLED:
            return true;
        case ERR_INVALID_STOPS: // 130
            // TBD under live tests
            return !__testing__;
        case ERR_NO_ERROR:
            return true;
        case ERR_NO_RESULT:
            return true;
        case ERR_SERVER_BUSY:
            return true;
        case ERR_BROKER_BUSY:
            return true;
        case ERR_TRADE_CONTEXT_BUSY:
            return true;
        case ERR_SYSTEM_BUSY:
            return true;
        case ERR_NO_MQLERROR:
            return true;
        default:
            return false;
        }
    };

    virtual int showError(string message)
    {
        int errno = GetLastError();
        printf("%s [%d] %s", message, errno, ErrorDescription(errno));
        return errno;
    }

    virtual void handleError(string message)
    {
        // TBD using MT4 SetUserError() internally, if it would not override
        // some other error code.

        const int errno = showError(message);
        if (continuableError(errno))
        {
            ResetLastError();
        }
        else
        {
            Print("Removing EA");
            ExpertRemove();
        }
    };

};

#endif
