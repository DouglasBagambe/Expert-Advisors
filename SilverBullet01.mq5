//+------------------------------------------------------------------+
//|                                               SilverBullet01.mq5 |
//|                                  Copyright 2024, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"

#include <trade/trade.mqh>

class CFairValueGap : public CObject {
public:
   int direction; //up or down
   datetime time;
   double high;
   double low;
   
   void draw(datetime timeStart, datetime timeEnd){
      string objFvg = "SB FVG "+TimeToString(time);
      ObjectCreate(0, objFvg, OBJ_RECTANGLE, 0, time, low, timeStart, high);
      ObjectSetInteger(0, objFvg, OBJPROP_FILL, true);
      ObjectSetInteger(0, objFvg, OBJPROP_COLOR, clrLightGray);
      
      string objTrade = "SB Trade "+TimeToString(time);
      ObjectCreate(0, objTrade, OBJ_RECTANGLE, 0, time, low, timeEnd, high);
      ObjectSetInteger(0, objTrade, OBJPROP_FILL, true);
      ObjectSetInteger(0, objTrade, OBJPROP_COLOR, clrGray);
   }
   
   void drawTradeLevels(double tp, double sl, datetime timeStart, datetime timeEnd){
      string objTp = "SB TP "+TimeToString(time);
      ObjectCreate(0, objTp, OBJ_RECTANGLE, 0, timeStart, (direction > 0 ? high : low), timeEnd, tp);
      ObjectSetInteger(0, objTp, OBJPROP_FILL, true);
      ObjectSetInteger(0, objTp, OBJPROP_COLOR, clrLightGreen);
      
      string objSl = "SB SL "+TimeToString(time);
      ObjectCreate(0, objSl, OBJ_RECTANGLE, 0, timeStart, (direction > 0 ? high : low), timeEnd, sl);
      ObjectSetInteger(0, objSl, OBJPROP_FILL, true);
      ObjectSetInteger(0, objSl, OBJPROP_COLOR, clrOrange);
   }
};

input double Lots = 0.1;
input double RiskPercent = 0.5;
input int MinTpPoints = 150;

input ENUM_TIMEFRAMES Timeframe = PERIOD_M5;
input int MinFvgPoints = 10;

input int TimeStartHour = 3;
input int TimeEndHour = 4;

CTrade trade;
CFairValueGap* fvg;

int OnInit(){

   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason){
   ObjectsDeleteAll(0, "SB");
}

void OnTick(){
   static int lastDay = 0;
   
   MqlDateTime structTime;
   TimeCurrent(structTime);
   structTime.min = 0;
   structTime.sec = 0;
   
   structTime.hour = TimeStartHour;
   datetime timeStart = StructToTime(structTime);
   
   structTime.hour = TimeEndHour;
   datetime timeEnd = StructToTime(structTime);
   
   if(TimeCurrent() >= timeStart && TimeCurrent() < timeEnd){
      if(lastDay != structTime.day_of_year){
         delete fvg;
         
         for(int i = 1; i < 100; i++){
            if(iLow(_Symbol, Timeframe, i) - iHigh(_Symbol, Timeframe, i+2) > MinFvgPoints * _Point){//fvg up
               fvg = new CFairValueGap();
               fvg.direction = 1;
               fvg.time = iTime(_Symbol, Timeframe, i+1);
               fvg.high = iLow(_Symbol, Timeframe, i);
               fvg.low = iHigh(_Symbol, Timeframe, i+2);
               
               if(iLow(_Symbol, Timeframe, iLowest(_Symbol, Timeframe, MODE_LOW, i+1)) <= fvg.low){
                  delete fvg;
                  break; //continue;
               }
               fvg.draw(timeStart, timeEnd);
               
               lastDay = structTime.day_of_year;
               break;
            }
            if(iLow(_Symbol, Timeframe, i+2) - iHigh(_Symbol, Timeframe, i) > MinFvgPoints * _Point){//fvg down
               fvg = new CFairValueGap();
               fvg.direction = -1;
               fvg.time = iTime(_Symbol, Timeframe, i+1);
               fvg.high = iLow(_Symbol, Timeframe, i+2);
               fvg.low = iHigh(_Symbol, Timeframe, i);
               
               if(iHigh(_Symbol, Timeframe, iHighest(_Symbol, Timeframe, MODE_LOW, i+1)) >= fvg.high){
                  delete fvg;
                  break; //continue;
               }
               fvg.draw(timeStart, timeEnd);
               
               lastDay = structTime.day_of_year;
               break;
            }
         }
      }
      
      double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(CheckPointer(fvg) != POINTER_INVALID && fvg.direction > 0 && ask < fvg.high){
         double entry = ask;
         double tp = iHigh(_Symbol, Timeframe, iHighest(_Symbol, Timeframe, MODE_HIGH, iBarShift(_Symbol, Timeframe, fvg.time)));
         double sl = iLow(_Symbol, Timeframe, iLowest(_Symbol, Timeframe, MODE_LOW, 5, iBarShift(_Symbol, Timeframe, fvg.time)));
         double lots = Lots;
         if(Lots == 0) lots = calcLots(entry - sl);
         
         fvg.drawTradeLevels(tp, sl, timeStart, timeEnd);
         
         if(tp - entry > MinTpPoints * _Point){
            if(trade.Buy(lots, _Symbol, entry, sl, tp)){
               Print(__FUNCTION__, " > Buy signal...");
            }
         }
         
         delete fvg;
      }
      if(CheckPointer(fvg) != POINTER_INVALID && fvg.direction < 0 && bid > fvg.low){
         double entry = bid;
         double tp = iLow(_Symbol, Timeframe, iLowest(_Symbol, Timeframe, MODE_LOW, iBarShift(_Symbol, Timeframe, fvg.time)));
         double sl = iHigh(_Symbol, Timeframe, iHighest(_Symbol, Timeframe, MODE_HIGH, 5, iBarShift(_Symbol, Timeframe, fvg.time)));
         double lots = Lots;
         if(Lots == 0) lots = calcLots(sl - entry);
         
         fvg.drawTradeLevels(tp, sl, timeStart, timeEnd);
         
         if(entry - tp > MinTpPoints * _Point){
            if(trade.Sell(lots, _Symbol, entry, sl, tp)){
               Print(__FUNCTION__, " > Sell signal...");
            }
         }
         
         delete fvg;
      }
   }
}

double calcLots(double slDist){
   double risk = AccountInfoDouble(ACCOUNT_BALANCE) * RiskPercent / 100;
   
   double ticksize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double tickvalue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   
   if(ticksize == 0) return -1;
   
   double moneyPerLot = slDist / ticksize * tickvalue;
   
   if(moneyPerLot == 0) return -1;
   
   double lots = NormalizeDouble(risk/moneyPerLot, 2);
   return lots;
}