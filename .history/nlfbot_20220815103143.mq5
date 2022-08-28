//
// EA Studio Expert Advisor
//
// Created with: Expert Advisor Studio
// Website: https://eatradingacademy.com/software/expert-advisor-studio/
//
// Copyright 2021, Forex Software Ltd.
//

// Risk Disclosure
//
// Futures and forex trading contains substantial risk and is not for every investor.
// An investor could potentially lose all or more than the initial investment.
// Risk capital is money that can be lost without jeopardizing ones’ financial security or life style.
// Only risk capital should be used for trading and only those with sufficient risk capital should consider trading.

#property copyright "Forex Software Ltd."
#property version   "2.16"
#property strict

static input string StrategyProperties__ = "------------"; // ------ Expert Properties ------
static input double Entry_Amount = 0.10; // Entry lots
input int Stop_Loss   = 28000; // Stop Loss (pips)
input int Take_Profit = 21000; // Take Profit (pips)
double FirstEntryPrice = 0.0;
double SecondEntryPrice = 0.0;
double nextEntryPrice = 0.0;
double previousEntryPrice = 0.0;
int SecondEntryPriceDeviation = 7000;

double SecondEntryStopLoss = 0.0;
double SecondEntryTakeProfit = 0.0;
static input string Ind0 = "------------";// ----- Stochastic Signal -----
input int Ind0Param0 = 30; // %K Period
input int Ind0Param1 = 70; // %D Period
input int Ind0Param2 = 3; // Slowing
static input string Ind1 = "------------";// ----- RVI Signal -----
input int Ind1Param0 = 24; // Period
static input string Ind2 = "------------";// ----- Envelopes -----
input int Ind2Param0 = 8; // Period
input double Ind2Param1 = 7.20; // Deviation %

static input string ExpertSettings__ = "------------"; // ------ Expert Settings ------
static input int Magic_Number = 13033797; // Magic Number

#define TRADE_RETRY_COUNT 4
#define TRADE_RETRY_WAIT  100
#define OP_FLAT           -1
#define OP_BUY             ORDER_TYPE_BUY
#define OP_SELL            ORDER_TYPE_SELL
#define OP_BUY_STOP        ORDER_TYPE_BUY_STOP
#define OP_SELL_STOP       ORDER_TYPE_SELL_STOP

// Session time is set in seconds from 00:00
int sessionSundayOpen           = 0;     // 00:00
int sessionSundayClose          = 86400; // 24:00
int sessionMondayThursdayOpen   = 0;     // 00:00
int sessionMondayThursdayClose  = 86400; // 24:00
int sessionFridayOpen           = 0;     // 00:00
int sessionFridayClose          = 86400; // 24:00
bool sessionIgnoreSunday        = false;
bool sessionCloseAtSessionClose = false;
bool sessionCloseAtFridayClose  = false;
bool orderSuccess               = false;
bool positionModified           = false;
bool buyPending                 = false;
bool sellPending                = false;
const double sigma=0.000001;

double posType          = OP_FLAT;
ulong  posTicket        = 0;
double posLots          = 0;
double posStopLoss      = 0;
double posTakeProfit    = 0;
double mainEntryAmount  = 0;
double lastCommand      = OP_FLAT;

datetime barTime;
int      digits;
double   pip;
double   stopLevel;
bool     isTrailingStop=false;

ENUM_ORDER_TYPE_FILLING orderFillingType;

int ind0handler;
int ind1handler;
int ind2handler;

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int OnInit()
  {
   barTime          = Time(0);
   
   digits           = (int) SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   pip              = GetPipValue(digits);
   stopLevel        = (int) SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   orderFillingType = GetOrderFillingType();
   isTrailingStop   = isTrailingStop && Stop_Loss > 0;
  

   ind0handler = iStochastic(NULL,0,Ind0Param0,Ind0Param1,Ind0Param2,MODE_SMA,STO_LOWHIGH);
   ind1handler = iRVI(NULL,0,Ind1Param0);
   ind2handler = iEnvelopes(NULL,0,Ind2Param0,0,MODE_SMA,PRICE_CLOSE,Ind2Param1);

   const ENUM_INIT_RETCODE initRetcode = ValidateInit();
   
   return (initRetcode);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OnTick()
  {
   //Print("================================");
   //PRINT("================================");
   //Print("================================");
   
   datetime time=Time(0);
   if(posType!=OP_FLAT)
     {
      //ManageClose();
      ManageNextPosition();
      UpdatePosition();
     }
   if(time>barTime)
     {
      barTime=time;
      OnBar();
     }
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OnBar()
  {
   UpdatePosition();

   //if(posType!=OP_FLAT && IsForceSessionClose())
     //{
      //ClosePosition();
      //return;
     //}

   //if(IsOutOfSession())
      //return;

   //if(posType!=OP_FLAT && isTrailingStop)
     //{
      //double trailingStop=GetTrailingStop();
      //ManageTrailingStop(trailingStop);
      //UpdatePosition();
     //}

   if(posType==OP_FLAT)
     {
      ManageOpen();
      UpdatePosition();
      
     }
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void UpdatePosition()
  {
   posType   = OP_FLAT;
   posTicket = 0;
   posLots   = 0;
   int posTotal=PositionsTotal();
   
   
   
   for(int posIndex=0;posIndex<posTotal;posIndex++)
     {
      const ulong ticket=PositionGetTicket(posIndex);
      
      if(PositionSelectByTicket(ticket) &&
         PositionGetString(POSITION_SYMBOL)==_Symbol &&
         PositionGetInteger(POSITION_MAGIC)==Magic_Number)
        {
         posType       = (int) PositionGetInteger(POSITION_TYPE);
         posLots       = NormalizeDouble(PositionGetDouble(POSITION_VOLUME), 2);
         posTicket     = ticket;
         FirstEntryPrice = NormalizeDouble(PositionGetDouble(POSITION_PRICE_OPEN), digits);
         //Print("open price", NormalizeDouble(PositionGetDouble(POSITION_PRICE_OPEN), digits), " open stop loss - ", NormalizeDouble(PositionGetDouble(POSITION_SL), digits), " open take profit - ", NormalizeDouble(PositionGetDouble(POSITION_TP), digits));
         posStopLoss   = NormalizeDouble(PositionGetDouble(POSITION_SL), digits);
         posTakeProfit = NormalizeDouble(PositionGetDouble(POSITION_TP), digits);
         if (!positionModified){
            ModifyPosition(ticket);
            
         }
         break;
        }
     }
     
     //if (posTotal == 0 && positionModified && posType ==OP_FLAT){
      //positionModified = false;
      //buyPending = false;
      //sellPending = false;
      //FirstEntryPrice = 0.0;
      //SecondEntryPrice = 0.0;
      //nextEntryPrice = 0.0;
      //previousEntryPrice = 0.0;
      //SecondEntryStopLoss = 0.0;
      //SecondEntryTakeProfit = 0.0;
      //}
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+



void ManageNextPosition()
{ 
   //--- check if bid or ask is greater than last pending 
   if (positionModified){
      MqlTick tick;SymbolInfoTick(_Symbol, tick);
      double entryPrice = 0.0;
     
      //Print("first Entry price : ", FirstEntryPrice, " previous entry price: ", previousEntryPrice, " next entry price: ", nextEntryPrice, " second entry price: ", SecondEntryPrice);
      if (lastCommand == OP_BUY_STOP){
         
         bool createPending = tick.ask >= previousEntryPrice;
         entryPrice = nextEntryPrice;
         Comment("TRY SELL STOP ------ ", " createPending ", createPending, " sell Pending ", sellPending, " Tick.ask - ", tick.ask, " next Entry price ", nextEntryPrice, " previous Entry price ", previousEntryPrice);
         
         if (createPending && sellPending){
            Print("GOT IN BUY STOP IS EXEC");
            ManageOrderSendPending(OP_SELL_STOP, Entry_Amount, SecondEntryStopLoss, SecondEntryTakeProfit, 0, entryPrice);
            
         }
      }else if (lastCommand == OP_SELL_STOP){
         
         bool createPending = tick.bid <= previousEntryPrice;
         entryPrice = nextEntryPrice;
         Comment("TRY BUY STOP ------ ", " createPending ", createPending, " buy Pending ", buyPending," Tick.ask - ", tick.ask, " next Entry price ", nextEntryPrice, " previous Entry price ", previousEntryPrice);
         
         if(createPending && buyPending){
            Print("GOT IN SELL STOP IS EXEC");
            ManageOrderSendPending(OP_BUY_STOP, Entry_Amount, SecondEntryStopLoss, SecondEntryTakeProfit, 0, entryPrice);
            
         }
      }
   }
   
   
   //--- true check if last command is buy_stop or sell stop
   
   //--- if last command is buy stop open sell stop else do otherwise
   
   
   
}


void ManageOpen()
  {
   double ind0buffer0[]; CopyBuffer(ind0handler,MAIN_LINE,1,2,ind0buffer0);
   double ind0buffer1[]; CopyBuffer(ind0handler,SIGNAL_LINE,1,2,ind0buffer1);
   double ind0val1 = ind0buffer0[1];
   double ind0val2 = ind0buffer1[1];
   bool ind0long  = ind0val1 > ind0val2 + sigma;
   bool ind0short = ind0val1 < ind0val2 - sigma;

   double ind1buffer0[]; CopyBuffer(ind1handler,0,1,3,ind1buffer0);
   double ind1buffer1[]; CopyBuffer(ind1handler,1,1,3,ind1buffer1);
   double ind1val1 = ind1buffer0[2] - ind1buffer1[2];
   bool ind1long  = ind1val1 > 0 + sigma;
   bool ind1short = ind1val1 < 0 - sigma;

   const bool canOpenLong  = ind0long && ind1long;
   const bool canOpenShort = ind0short && ind1short;

   if(canOpenLong && canOpenShort) return;

   if(canOpenLong)
      OpenPosition(OP_BUY);
      
   else if(canOpenShort)
      OpenPosition(OP_SELL);
      
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void ManageClose()
  {
   double ind2buffer0[]; CopyBuffer(ind2handler,0,1,2,ind2buffer0);
   double ind2buffer1[]; CopyBuffer(ind2handler,1,1,2,ind2buffer1);
   double ind2upBand1 = ind2buffer0[1];
   double ind2dnBand1 = ind2buffer1[1];
   double ind2upBand2 = ind2buffer0[0];
   double ind2dnBand2 = ind2buffer1[0];
   bool ind2long  = Open(0) > ind2dnBand1 + sigma && Open(1) < ind2dnBand2 - sigma;
   bool ind2short = Open(0) < ind2upBand1 - sigma && Open(1) > ind2upBand2 + sigma;

   if(posType==OP_BUY && ind2long)
      return;
      //ClosePosition();
   else if(posType==OP_SELL && ind2short)
      return;
      //ClosePosition();
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OpenPosition(int command)
  {
   //const double stopLoss   = GetStopLossPrice(command);
   //const double takeProfit = GetTakeProfitPrice(command);
   
   ManageOrderSend(command,Entry_Amount,0);
  }
  
 void OpenPendingPosition(int command)
  {
   const double stopLoss   = SecondEntryStopLoss;
   const double takeProfit = SecondEntryTakeProfit;
   const double entryPrice = SecondEntryPrice;
   
   Print("pending Stop Loss - ", stopLoss, " pending take profit - ", takeProfit, " first entry price -", FirstEntryPrice, " entry price - ", entryPrice);
   ManageOrderSendPending(command,Entry_Amount,stopLoss,takeProfit,0, entryPrice);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
//void ClosePosition()
 // {
  // const int command=posType==OP_BUY ? OP_SELL : OP_BUY;
  // ManageOrderSend(command,posLots,0,0,posTicket);
  //}
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void ManageOrderSend(int command,double lots, ulong ticket)
  {
   
   for(int attempt=0; attempt<TRADE_RETRY_COUNT; attempt++)
     {
      if(IsTradeContextFree())
        {
         ResetLastError();
         MqlTick         tick;    SymbolInfoTick(_Symbol,tick);
         MqlTradeRequest request; ZeroMemory(request);
         MqlTradeResult  result;  ZeroMemory(result);
         
         double stopLoss = GetStopLossPrice(command,tick.bid, tick.ask);
         double takeProfit = GetTakeProfitPrice(command,tick.bid, tick.ask);
         
         request.action       = TRADE_ACTION_DEAL;
         request.symbol       = _Symbol;
         request.volume       = lots;
         request.type         = command==OP_BUY ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
         request.price        = command==OP_BUY ? tick.ask : tick.bid;
         request.type_filling = orderFillingType;
         request.deviation    = 10;
         request.sl           = stopLoss; 
         request.tp           = takeProfit;
         request.magic        = Magic_Number;
         request.position     = ticket;
         request.comment      = IntegerToString(Magic_Number);

         bool isOrderCheck = CheckOrder(request);
         bool isOrderSend  = false;

         if(isOrderCheck)
           {
            isOrderSend=OrderSend(request,result);
           }

         if(isOrderCheck && isOrderSend && result.retcode==TRADE_RETCODE_DONE)
            Print("ORDER EXECUTED SUCCESFULY");
            
            FirstEntryPrice = command==OP_BUY ? tick.ask : tick.bid;
            SecondEntryPrice = GetSecondEntryPrice(command, tick.bid, tick.ask);
            orderSuccess = true;
            return;
        }
      Sleep(TRADE_RETRY_WAIT);
      orderSuccess = false;
      Print("Order Send retry no: "+IntegerToString(attempt+2));
     }
  }
  
  
  void ManageOrderSendPending(int command,double lots,double stopLoss,double takeProfit,ulong ticket, double entryPrice)
  {
   for(int attempt=0; attempt<TRADE_RETRY_COUNT; attempt++)
     {
      if(IsTradeContextFree())
        {
         ResetLastError();
         MqlTick         tick;    SymbolInfoTick(_Symbol,tick);
         MqlTradeRequest request; ZeroMemory(request);
         MqlTradeResult  result;  ZeroMemory(result);

         request.action       = TRADE_ACTION_PENDING;
         
         request.symbol       = _Symbol;
         request.volume       = lots;
         request.type         = command==OP_BUY_STOP ? ORDER_TYPE_BUY_STOP : ORDER_TYPE_SELL_STOP;
         request.price        = entryPrice;
         request.type_filling = orderFillingType;
         request.deviation    = 2;
         request.sl           = stopLoss; 
         request.tp           = takeProfit;
         request.magic        = Magic_Number;
         request.position     = ticket;
         request.comment      = IntegerToString(Magic_Number);

         bool isOrderCheck = CheckOrder(request);
         bool isOrderSend  = false;

         if(isOrderCheck)
           {
            isOrderSend=OrderSend(request,result);
           }

         if(isOrderCheck && isOrderSend && result.retcode==TRADE_RETCODE_DONE)
            Print("ORDER EXECUTED SUCCESFULY PENDING");
            
            
           
            if (command==OP_BUY_STOP){
               sellPending = true;
               buyPending = false;
            }else {
               buyPending = true;
               sellPending = false;
            }
            orderSuccess = true;
            SecondEntryStopLoss = takeProfit;
            SecondEntryTakeProfit = stopLoss;
            double swapper;
            
            // swapp the two prices
            swapper = previousEntryPrice;
            previousEntryPrice = nextEntryPrice;
            nextEntryPrice = swapper;
            
            lastCommand = command;
            
            return;
        }
      Sleep(TRADE_RETRY_WAIT);
      orderSuccess = false;
      Print("Order Send retry no: "+IntegerToString(attempt+2));
     }
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void ModifyPosition(ulong ticket)
  {
  Print("TRYING TO MODIFY POSITION,");
   for(int attempt=0; attempt<TRADE_RETRY_COUNT; attempt++)
     {
      if(IsTradeContextFree())
        {
         ResetLastError();
         MqlTick         tick;    SymbolInfoTick(_Symbol,tick);
         MqlTradeRequest request; ZeroMemory(request);
         MqlTradeResult  result;  ZeroMemory(result);
         
         PositionSelectByTicket(ticket);
         double openPrice = NormalizeDouble(PositionGetDouble(POSITION_PRICE_OPEN), digits);
         double stopLoss = PositionGetInteger(POSITION_TYPE) == OP_BUY? openPrice - Stop_Loss * pip: openPrice + Stop_Loss * pip;
         double takeProfit = PositionGetInteger(POSITION_TYPE) == OP_BUY? openPrice + Take_Profit * pip: openPrice - Take_Profit * pip;
         SecondEntryTakeProfit = stopLoss;
         SecondEntryStopLoss = takeProfit;
         SecondEntryPrice = PositionGetInteger(POSITION_TYPE) == OP_BUY? openPrice - SecondEntryPriceDeviation * pip: openPrice + SecondEntryPriceDeviation * pip;
         FirstEntryPrice = openPrice;
         nextEntryPrice = SecondEntryPrice;
         previousEntryPrice = FirstEntryPrice;

         Print("Second Entry TP : ",  SecondEntryTakeProfit, " ticket : ", ticket, " Second Entry SL : ", SecondEntryStopLoss, " Second Entry Price ", SecondEntryPrice, " first Entry price : ", openPrice, " stop loss : ", stopLoss, " take profit: ", takeProfit );
         
         request.action   = TRADE_ACTION_SLTP;
         request.symbol   = _Symbol;
         request.sl       = stopLoss;
         request.tp       = takeProfit;
         request.magic    = Magic_Number;
         request.position = ticket;
         request.comment  = IntegerToString(Magic_Number);

         bool isOrderCheck = CheckOrder(request);
         bool isOrderSend  = false;

         if(isOrderCheck)
           {
            isOrderSend=OrderSend(request,result);
           }

         if(isOrderCheck && isOrderSend && result.retcode==TRADE_RETCODE_DONE){
         
             Print("MODIFICATION WAS SUCCESSFUL");
             positionModified = true;
               
             if (PositionGetInteger(POSITION_TYPE) == OP_BUY){
               Print("EXECUTED SELL STOP");
               OpenPendingPosition(OP_SELL_STOP);
               
              
             }else {
               Print("EXECUTED BUY STOP");
               OpenPendingPosition(OP_BUY_STOP);
               
             }
              
            return;
            }
        }
      Sleep(TRADE_RETRY_WAIT);
      Print("Order Send retry no: "+IntegerToString(attempt+2));
     }
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool CheckOrder(MqlTradeRequest &request)
  {
   MqlTradeCheckResult check; ZeroMemory(check);
   const bool isOrderCheck=OrderCheck(request,check);
   if(isOrderCheck) return (true);


   if(check.retcode==TRADE_RETCODE_INVALID_FILL)
     {
      switch(orderFillingType)
        {
         case  ORDER_FILLING_FOK:
            orderFillingType=ORDER_FILLING_IOC;
            break;
         case  ORDER_FILLING_IOC:
            orderFillingType=ORDER_FILLING_RETURN;
            break;
         case  ORDER_FILLING_RETURN:
            orderFillingType=ORDER_FILLING_FOK;
            break;
        }

      request.type_filling=orderFillingType;

      const bool isNewCheck=CheckOrder(request);

      return (isNewCheck);
     }

   Print("Error with OrderCheck: "+check.comment);
   return (false);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double GetStopLossPrice(int command, double bid, double ask)
  {
   
   if(Stop_Loss==0) return (0);
   const double delta    = MathMax(pip*Stop_Loss, _Point*stopLevel);
   const double price    = command==OP_BUY ? bid : ask;
   const double stopLoss = command==OP_BUY ? price-delta : price+delta;
   const double normalizedStopLoss = NormalizeDouble(stopLoss, _Digits);

   return (normalizedStopLoss);
  }
  
double GetSecondEntryPrice(int command, double bid, double ask)
  {
   const double delta    = pip*SecondEntryPriceDeviation;
   const double price    = command==OP_BUY ? ask: bid;
   const double secondEntry = command==OP_BUY ? price+delta : price-delta;
   const double normalizedSecondEntry = NormalizeDouble(secondEntry, _Digits);

   Print("max delta - ", delta, " normalised second entry - ", normalizedSecondEntry, " pip -", pip, "first entry price - ", FirstEntryPrice, " point - ", _Point, " stopLevel - ", stopLevel, " PIP * SECOND ENTRY - ", pip*SecondEntryPriceDeviation, " POINT * STOPLEVEL - ", _Point*stopLevel);
   return (normalizedSecondEntry);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double GetTrailingStop()
  {
   MqlTick tick; SymbolInfoTick(_Symbol,tick);
   const double stopLevelPoints = _Point*stopLevel;
   const double stopLossPoints  = pip*Stop_Loss;

   if(posType==OP_BUY)
     {
      const double stopLossPrice=High(1)-stopLossPoints;
      if(posStopLoss<stopLossPrice-pip)
        {
         if(stopLossPrice<tick.bid)
           {
            const double fixedStopLossPrice = (stopLossPrice>=tick.bid-stopLevelPoints)
                                              ? tick.bid - stopLevelPoints
                                              : stopLossPrice;

            return (fixedStopLossPrice);
           }
         else
           {
            return (tick.bid);
           }
        }
     }

   else if(posType==OP_SELL)
     {
      const double stopLossPrice=Low(1)+stopLossPoints;
      if(posStopLoss>stopLossPrice+pip)
        {
         if(stopLossPrice>tick.ask)
           {
            if(stopLossPrice<=tick.ask+stopLevelPoints)
               return (tick.ask + stopLevelPoints);
            else
               return (stopLossPrice);
           }
         else
           {
            return (tick.ask);
           }
        }
     }

   return (posStopLoss);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void ManageTrailingStop(double trailingStop)
  {
   MqlTick tick; SymbolInfoTick(_Symbol,tick);

   if(posType==OP_BUY && MathAbs(trailingStop-tick.bid)<_Point)
     {
      //ClosePosition();
      return;
     }

   else if(posType==OP_SELL && MathAbs(trailingStop-tick.ask)<_Point)
     {
      //ClosePosition();
      return;
     }

   else if(MathAbs(trailingStop-posStopLoss)>_Point)
     {
      posStopLoss=NormalizeDouble(trailingStop,digits);
      //ModifyPosition(posStopLoss,posTakeProfit,posTicket);
     }
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double GetTakeProfitPrice(int command, double bid, double ask)
  {
   if(Take_Profit==0) return (0);
   const double delta      = MathMax(pip*Take_Profit, _Point*stopLevel);
   const double price      = command==OP_BUY ? bid : ask;
   const double takeProfit = command==OP_BUY ? price+delta : price-delta;
   const double normalizedTakeProfit = NormalizeDouble(takeProfit, _Digits);

   return (normalizedTakeProfit);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
datetime Time(int bar)
  {
   datetime buffer[]; ArrayResize(buffer,1);
   const int result=CopyTime(_Symbol,_Period,bar,1,buffer);
   return (result==1 ? buffer[0] : 0);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double Open(int bar)
  {
   double buffer[]; ArrayResize(buffer,1);
   const int result=CopyOpen(_Symbol,_Period,bar,1,buffer);
  
   return (result==1 ? buffer[0] : 0);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double High(int bar)
  {
   double buffer[]; ArrayResize(buffer,1);
   const int result=CopyHigh(_Symbol,_Period,bar,1,buffer);
   return (result==1 ? buffer[0] : 0);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double Low(int bar)
  {
   double buffer[]; ArrayResize(buffer,1);
   const int result=CopyLow(_Symbol,_Period,bar,1,buffer);
   return (result==1 ? buffer[0] : 0);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double Close(int bar)
  {
   double buffer[]; ArrayResize(buffer,1);
   const int result=CopyClose(_Symbol,_Period,bar,1,buffer);
   return (result==1 ? buffer[0] : 0);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double GetPipValue(int digit)
  {
   if(digit==4 || digit==5)
      return (0.0001);
   if(digit==2 || digit==3)
      return (0.01);
   if(digit==1)
      return (0.1);
   return (1);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool IsTradeContextFree()
  {
   if(MQL5InfoInteger(MQL5_TRADE_ALLOWED)) return (true);

   uint startWait=GetTickCount();
 

   while(true)
     {
      if(IsStopped()) return (false);

      uint diff=GetTickCount()-startWait;
      if(diff>30*1000)
        {
      
         return (false);
        }

      if(MQL5InfoInteger(MQL5_TRADE_ALLOWED)) return (true);

      Sleep(TRADE_RETRY_WAIT);
     }

   return (true);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool IsOutOfSession()
  {
   MqlDateTime time0; TimeToStruct(Time(0),time0);
   const int weekDay           = time0.day_of_week;
   const long timeFromMidnight = Time(0)%86400;
   const int periodLength      = PeriodSeconds(_Period);

   if(weekDay==0)
     {
      if(sessionIgnoreSunday) return (true);

      const int lastBarFix = sessionCloseAtSessionClose ? periodLength : 0;
      const bool skipTrade = timeFromMidnight<sessionSundayOpen ||
                             timeFromMidnight+lastBarFix>sessionSundayClose;

      return (skipTrade);
     }

   if(weekDay<5)
     {
      const int lastBarFix = sessionCloseAtSessionClose ? periodLength : 0;
      const bool skipTrade = timeFromMidnight<sessionMondayThursdayOpen ||
                             timeFromMidnight+lastBarFix>sessionMondayThursdayClose;

      return (skipTrade);
     }

   const int lastBarFix=sessionCloseAtFridayClose || sessionCloseAtSessionClose ? periodLength : 0;
   const bool skipTrade=timeFromMidnight<sessionFridayOpen || timeFromMidnight+lastBarFix>sessionFridayClose;

   return (skipTrade);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool IsForceSessionClose()
  {
   if(!sessionCloseAtFridayClose && !sessionCloseAtSessionClose) return (false);

   MqlDateTime time0; TimeToStruct(Time(0),time0);
   
   const int weekDay           = time0.day_of_week;
   const long timeFromMidnight = Time(0)%86400;
   const int periodLength      = PeriodSeconds(_Period);
   
   bool forceExit=false;
   if(weekDay==0 && sessionCloseAtSessionClose)
     {
      forceExit=timeFromMidnight+periodLength>sessionSundayClose;
     }
   else if(weekDay<5 && sessionCloseAtSessionClose)
     {
      forceExit=timeFromMidnight+periodLength>sessionMondayThursdayClose;
     }
   else if(weekDay==5)
     {
      forceExit=timeFromMidnight+periodLength>sessionFridayClose;
     }

   return (forceExit);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
ENUM_ORDER_TYPE_FILLING GetOrderFillingType()
  {
   const int oftIndex=(int) SymbolInfoInteger(_Symbol,SYMBOL_FILLING_MODE);
   const ENUM_ORDER_TYPE_FILLING fillType=(ENUM_ORDER_TYPE_FILLING)(oftIndex>0 ? oftIndex-1 : oftIndex);

   return (fillType);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
ENUM_INIT_RETCODE ValidateInit()
  {
   return (INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
/*STRATEGY MARKET Premium Data; BTCUSD; H1 */
/*STRATEGY CODE {"properties":{"entryLots":1,"tradeDirectionMode":0,"stopLoss":100,"takeProfit":21000,"useStopLoss":false,"useTakeProfit":true,"isTrailingStop":false},"openFilters":[{"name":"Stochastic Signal","listIndexes":[2,0,0,0,0],"numValues":[30,70,3,0,0,0]},{"name":"RVI Signal","listIndexes":[2,0,0,0,0],"numValues":[24,0,0,0,0,0]}],"closeFilters":[{"name":"Envelopes","listIndexes":[5,3,0,0,0],"numValues":[8,7.2,0,0,0,0]}]} */
