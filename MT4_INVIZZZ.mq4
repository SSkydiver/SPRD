//+------------------------------------------------------------------+
//|                                                  MT4_INVIZZZ.mq4 |
//|                                          https://www.invizzz.com |
//+------------------------------------------------------------------+

// ДОБАВИТЬ ВОЗМОЖНОСТЬ ЗАКРЫВАТЬ ОТКРЫТЫЕ ПОЗИЦИИ (ВНЕДРИТЬ ПРИКАЗ CLOSE) !!!
// ДОБАВИТЬ В КАЧЕСТВЕ РЕКОМЕНДАЦИИ ПРИ ИСПОЛЬЗОВАНИИ ДАННОГО ЭКСПЕРТА НЕ ЗАКРЫВАТЬ ОКНО ГРАФИКА И НЕ МЕНЯТЬ ПО НЕМУ ТФ !!!

#property strict
// INPUT VARIABLES:
input string ID = "";
input string BrockerName = "";
// ------------------------------------- DEALS

#include <WinUser32.mqh>
#include "MT4_INVIZZZ.mqh"
#include "Functions.mqh"
#include "ORDERS.mqh"
#include "CURRENTPOSTARRAY.mqh"

#import "dHttp.dll"
string sendPOST(bool, string, int, bool);
#import


// Переменные, в которых будет записана разница между локальным и серверным временем:
MqlDateTime mqlDateTimeStructureDiff;
datetime difference;
int diff;
// ---------------------------------------------------------

// ------------ Аргументы dll - функции:
bool cotRequest = false;
// ---------------------------------------------------------
// ------------- Глобальные переменные:
string List = "";

string terminalName = "#MT4#";
string brockerName = BrockerName;
string addDescript = terminalName + brockerName;
string id = "";

ORDERS Orders[1000]; // Массив приказов от сервера.
CURRENTPOSTARRAY currentPriceAndSpreadToSent[1000];

int OnInit(){
   id = ID;
   
   // ------------ Определяем разницу серверного времени и локального:

   difference = fabs(TimeGMT() - TimeLocal());
   TimeToStruct(difference, mqlDateTimeStructureDiff);
   diff = mqlDateTimeStructureDiff.hour;
   diff = (TimeGMT() < TimeLocal()) ? diff : -diff;

   // ---------------------------------------------------------
   
   // ПРОВЕРКА ID НА КОРРЕКТНОСТЬ ВВОДА:
   if(id == ""){
      Alert("Не установлен ID !!!");
      return -1;
   }
   else{
      for(int i=0; i < StringLen(id); ++i){
         if(StringSubstr(id, i, 1) != "0" &&
            StringSubstr(id, i, 1) != "1" &&
            StringSubstr(id, i, 1) != "2" &&
            StringSubstr(id, i, 1) != "3" &&
            StringSubstr(id, i, 1) != "4" &&
            StringSubstr(id, i, 1) != "5" &&
            StringSubstr(id, i, 1) != "6" &&
            StringSubstr(id, i, 1) != "7" &&
            StringSubstr(id, i, 1) != "8" &&
            StringSubstr(id, i, 1) != "9"){
               Alert("НЕ КОРРЕКТНЫЙ ID !!!");
               return -1;
         }
      }
   }  
   // ---------------------------------------------------------

   // Получение списка всех инструментов торгового терминала:
   int hFile = FileOpenHistory("symbols.sel", FILE_BIN | FILE_READ);
   if(hFile < 0){
      Alert("Не удалось считать файл с инструментами \'symbols.sel\'... Работа эксперта будет прекращена!");
      return -1;
   }

   unsigned long length = (FileSize(hFile) - 4) / 128;
   
   int Offset = 116;
   FileSeek(hFile, 4, SEEK_SET);
   
   for(unsigned long i=0; i < length; ++i){
      string inst = FileReadString(hFile, 12);
      string tSize = DoubleToString(MarketInfo(inst, MODE_TICKSIZE), (int)MarketInfo(inst, MODE_DIGITS));
      List += inst + addDescript + " | " + tSize + ";";
      FileSeek(hFile, Offset, SEEK_CUR);
   }
   FileClose(hFile);
   // --------------------------------------------------
   
   // Отправляем POST запрос:
   string tempList = id + ";CREATE;" + List;
   string Answers = sendPOST(false, tempList, StringLen(tempList), true);
   // Здесь будем обрабатывать ответ от сервера при подключении, а именно соответствует ли ID:
   if(Answers == "ID_NOT_EXISTS"){
      Alert("ID, указанный в настройках эксперта не эквивалентен выделенному !!! Работа эксперта будет прекращена.");
      return -1;
   }
   else if(Answers == "ERROR_DISCONNECT"){
      Alert("Портал, по каким то причинам разорвал соединение...");
      return -2;
   }
   // --------------------------------------------------------------------
   
   EventSetMillisecondTimer(1000);
   return(INIT_SUCCEEDED);
}


void OnDeinit(const int reason){
      EventKillTimer();
      // ПЕРЕДАЕМ ID НА СЕРВЕР(Сервер это примет как приказ к исключению переданных  инструментов):
      string tempList = id + ";DELETE;" + List;
      sendPOST(false, tempList, StringLen(tempList), true);
}


void OnTimer(){ // Синхронный обработчик собитий...

   // В любом случае необходимо проверять состояние файла с приказами на сервере:
   // Отправляем POST запрос:
   string tempList = id + ";IDONLY;";
   string Answers = sendPOST(false, tempList, StringLen(tempList), false);
   
   if(Answers == "ID_NOT_EXISTS"){
      Alert("ID, указанный в настройках эксперта не эквивалентен выделенному !!! Работа эксперта будет прекращена.");
      OnDeinit(-1);
   }
   else if(Answers == "ERROR_DISCONNECT"){
      Alert("Портал, по каким то причинам разорвал соединение...");
      OnDeinit(-2);
   }
   else if(Answers != ""){
      // Парсим полученный ответ, разбив его на под строки по разделителю |:
      string arrayAnswers[1000]; // Массив ответов с приказами от сервера. 
      int arrayAnswersLength = 0;
      // rowCounters - количество строк.
      string temp = "";
      for(int i=0; i < StringLen(Answers); ++i){
         if(StringSubstr(Answers, i, 1) != "|"){
            temp += StringSubstr(Answers, i, 1);
         }
         else{
            arrayAnswers[arrayAnswersLength++] = temp;
            temp = "";
         }
      }
   
      temp = "";
      int counter = 0; // Счетчик для записи в свойства класса: 0 - значит first, 1 - значит second, 2 - значит third.
      for(int i=0; i < arrayAnswersLength; ++i){
         for(int j = 0; j < StringLen(arrayAnswers[i]); ++j){
            if(StringSubstr(arrayAnswers[i], j, 1) != ";"){
               temp += StringSubstr(arrayAnswers[i], j, 1);
            }
            else{
               if(counter == 0){
                  Orders[ORDERS::length].first = temp;
               }
               else if(counter == 1){
                  Orders[ORDERS::length].second = temp;
                  
                  // Выделяем название инструмента без терминала и брокера:
                  string name = ""; // Определяем название инструмента по которому хотим получить историю
                  for(int k=0; k < StringLen(temp); ++k){
                     if(StringSubstr(temp, k, 1) != "#"){
                        name += StringSubstr(temp, k, 1);
                     }
                     else{
                        break;
                     }
                  }
                     
                  Orders[ORDERS::length].nameWithout = name;
               }
               else if(counter == 2){
                  Orders[ORDERS::length].third = temp;
               }
               else{ // counter == 3
                  Orders[ORDERS::length].forth = temp;
               }
               counter++;
               counter = (counter > 3) ? 0 : counter;
               temp = "";
            }
         }
         ORDERS::length++;
      }
   }
   
   
   // Обработка ответов от сервера:
   if(ORDERS::length > 0){ // Если есть хотябы 1 приказ, то обрабатываем все имеющиеся приказы...
      for(int i=0; i < ORDERS::length; ++i){
            string name = Orders[i].nameWithout; // Короткое название инструмента
     
            // ОТСЕИВАЕМ ВСЕ ПРИКАЗЫ, ПРИШЕДШИЕ НЕ ДЛЯ ДАННОГО ТЕРМИНАЛА:
            bool deleteQueue = false;
            string instrument_terminal_name = name + terminalName + brockerName;
            
            if(instrument_terminal_name == Orders[i].second){
               if(Orders[i].first == "GETHISTORY"){ // Приказ на получение истории по инструменту.
                  // Определяем количество получаемой истории. Это может быть либо ALL либо значение:
                  // Изымаем историю по инструменту, приводим ее в надлежащий вид и отправляем на сервер:
                  // Получаем кол-во баров всей истории по инструменту:
                  
                  int historyLength = 0;
                  int tryCounter = 0;
                  while(tryCounter < 5){
                     if(historyLength == 0){
                        historyLength = iBars(name, (int)(StringToInteger(Orders[i].third)));
                     }
                     else{
                        break;
                     }
                     Sleep(1000);
                     tryCounter++;
                  }

                  historyLength = (historyLength > 3000) ? 3000 : historyLength;
                  // Подготавливаем запрос, считываем полезные данные и отправляем запрос в dll:
                  string sendInstrumentHistory = id + ";POSTHISTORY;" + Orders[i].second + "#" + Orders[i].third + ";";
                  
                  for(int j=historyLength-1; j >= 0; --j){
                     // Определяем время бара:
                     datetime tempTime = iTime(name, (int)StringToInteger(Orders[i].third), j);
                     MqlDateTime mqlDateTimeStructure;
                     TimeToStruct(tempTime, mqlDateTimeStructure);
                     mqlDateTimeStructure.hour + diff;
                     
                     int HOURES = mqlDateTimeStructure.hour;
                     int MINUTES = mqlDateTimeStructure.min;
                     int DAY = mqlDateTimeStructure.day;
                     int MONTH = mqlDateTimeStructure.mon;
                     int YEAR = mqlDateTimeStructure.year;
                     
                     string pref = "0";
                     string H = (HOURES < 10) ? pref + IntegerToString(HOURES) : IntegerToString(HOURES);
                     string Min = (MINUTES < 10) ? pref + IntegerToString(MINUTES) : IntegerToString(MINUTES);
                     string D = (DAY < 10) ? pref + IntegerToString(DAY) : IntegerToString(DAY);
                     string Mon = (MONTH < 10) ? pref + IntegerToString(MONTH) : IntegerToString(MONTH);
                     string Y = IntegerToString(YEAR);
                     
                     string barTime = H + ":" + Min + "&" + D + "/" + Mon + "/" + Y;

                     int epcilon = (int)MarketInfo(name, MODE_DIGITS);
                     int tFrame = (int)StringToInteger(Orders[i].third);
                     
                     double tempOpen = iOpen(name, tFrame, j);
                     double tempHigh = iHigh(name, tFrame, j);
                     double tempLow = iLow(name, tFrame, j);
                     double tempClose = iClose(name, tFrame, j);
                     if((tempOpen != 0.0) && (tempHigh != 0.0) && (tempLow != 0.0) && (tempClose != 0.0)){
                        sendInstrumentHistory += DoubleToString(tempOpen, epcilon) + ";" +
                                                 DoubleToString(tempHigh, epcilon) + ";" +
                                                 DoubleToString(tempLow, epcilon) + ";" +
                                                 DoubleToString(tempClose, epcilon) + ";" +
                                                 barTime + ";";
                     }
                  }
                  if(sendInstrumentHistory == id + ";POSTHISTORY;" + Orders[i].second + "#" + Orders[i].third + ";"){
                     sendInstrumentHistory = id + ";POSTHISTORY;"  + Orders[i].second + "#" + Orders[i].third + ";NONE;";
                  }
                  
                  string Ans = sendPOST(false, sendInstrumentHistory, StringLen(sendInstrumentHistory), false);
                  if(Answers == "ID_NOT_EXISTS"){
                     Alert("ID, указанный в настройках эксперта не эквивалентен выделенному !!! Работа эксперта будет прекращена.");
                     OnDeinit(-1);
                  }
                  else if(Ans == "ERROR_DISCONNECT"){
                     Alert("Портал, по каким то причинам разорвал соединение...");
                     OnDeinit(-2);
                  }
                  Alert(sendInstrumentHistory);
                  Alert("---------------------");
                  
                  
                  // -----------------------------------------------------
                  // Добавляем название в массив названий, по которому будет осуществляться поставка котировок автоматически...
                  // С проверкой на уникальность названия в массиве:
                  if(sendInstrumentHistory != id + ";POSTHISTORY;"  + Orders[i].second + "#" + Orders[i].third + ";NONE;"){
                     // Также определяем размер спрэда по инструменту и время текущего бара:
                     // Определяем время текущего бара:
                     datetime tempTime = iTime(name, (int)StringToInteger(Orders[i].third), 0);
                     MqlDateTime mqlDateTimeStructure;
                     TimeToStruct(tempTime, mqlDateTimeStructure);
                     mqlDateTimeStructure.hour + diff;
                        
                     int HOURES = mqlDateTimeStructure.hour;
                     int MINUTES = mqlDateTimeStructure.min;
                     int DAY = mqlDateTimeStructure.day;
                     int MONTH = mqlDateTimeStructure.mon;
                     int YEAR = mqlDateTimeStructure.year;
                        
                     string pref = "0";
                     string H = (HOURES < 10) ? pref + IntegerToString(HOURES) : IntegerToString(HOURES);
                     string Min = (MINUTES < 10) ? pref + IntegerToString(MINUTES) : IntegerToString(MINUTES);
                     string D = (DAY < 10) ? pref + IntegerToString(DAY) : IntegerToString(DAY);
                     string Mon = (MONTH < 10) ? pref + IntegerToString(MONTH) : IntegerToString(MONTH);
                     string Y = IntegerToString(YEAR);
                        
                     string barTime = H + ":" + Min + "&" + D + "/" + Mon + "/" + Y;
                     
                     if(!CURRENTPOSTARRAY::length){ // Если массив пуст, тогда добавляем инструмент в массив:
                        currentPriceAndSpreadToSent[CURRENTPOSTARRAY::length].instrumentName = name;
                        currentPriceAndSpreadToSent[CURRENTPOSTARRAY::length].timeFrame = Orders[i].third;
                        currentPriceAndSpreadToSent[CURRENTPOSTARRAY::length].lastTime = barTime;
                        currentPriceAndSpreadToSent[CURRENTPOSTARRAY::length].ask = DoubleToString(MarketInfo(name, MODE_ASK), (int)MarketInfo(name, MODE_DIGITS));
                        currentPriceAndSpreadToSent[CURRENTPOSTARRAY::length++].bid = DoubleToString(MarketInfo(name, MODE_BID), (int)MarketInfo(name, MODE_DIGITS));
                     }
                     else{ // А если массив не пуст, то сначало проверяем добавляемый элемент на его уникальность:
                        bool unique = true;
                        for(int k=0; k < CURRENTPOSTARRAY::length; ++k){
                           if(name == currentPriceAndSpreadToSent[k].instrumentName){
                              unique = false;
                              break;
                           }
                        }
                        if(unique){ // Если название уникально, тогда его тоже будем добавлять в массив названий:
                           currentPriceAndSpreadToSent[CURRENTPOSTARRAY::length].instrumentName = name;
                           currentPriceAndSpreadToSent[CURRENTPOSTARRAY::length].timeFrame = Orders[i].third;
                           currentPriceAndSpreadToSent[CURRENTPOSTARRAY::length].lastTime = barTime;
                           currentPriceAndSpreadToSent[CURRENTPOSTARRAY::length].ask = DoubleToString(MarketInfo(name, MODE_ASK), (int)MarketInfo(name, MODE_DIGITS));
                           currentPriceAndSpreadToSent[CURRENTPOSTARRAY::length++].bid = DoubleToString(MarketInfo(name, MODE_BID), (int)MarketInfo(name, MODE_DIGITS));
                        } // А если нет, то пусть идет нахуй.
                     }
                     // -----------------------------------------------------
                  }
            }
            else if(Orders[i].first == "BREAKPRICE"){ // Приказ на отмену поставок котировок.
               // Удаляем название инструмента из массива названий, по которому хотим отменить поставку котировок:
               for(int j=0; j < CURRENTPOSTARRAY::length; ++j){
                  if(name == currentPriceAndSpreadToSent[j].instrumentName){
                     for(int e=j; e < CURRENTPOSTARRAY::length - 1; ++e){
                        currentPriceAndSpreadToSent[e].instrumentName = currentPriceAndSpreadToSent[e+1].instrumentName;
                     } // Удалили найденный элемент путем смещения всех правых на единицу влево.
                     currentPriceAndSpreadToSent[CURRENTPOSTARRAY::length-1].instrumentName = ""; // Крайний элемент обнуляем.
                     currentPriceAndSpreadToSent[CURRENTPOSTARRAY::length-1].timeFrame = "";
                     currentPriceAndSpreadToSent[CURRENTPOSTARRAY::length-1].ask = "";
                     currentPriceAndSpreadToSent[CURRENTPOSTARRAY::length-1].bid = "";
                     CURRENTPOSTARRAY::length--; // А длина массива соответственно уменьшается на 1.
                  }
               }
            }
            else if(Orders[i].first == "BUY"){ // Приказ на покупку инструмента.
               // Заключаем ордер на buy:
               
               // РЕАЛИЗУЮ ПОТОМ...
               
               
            }
            else if(Orders[i].first == "SELL"){ // Приказ на продажу инструмента.
               // Заключаем ордер на sell:
               
               // РЕАЛИЗУЮ ПОТОМ...
               
            }
         }
      }
      
      // Очищаем массив типа Orders и обнуляем его длину:
      for(int i=0; i < ORDERS::length; ++i){
         Orders[i].first = "";
         Orders[i].second = "";
         Orders[i].third = "";
         Orders[i].forth = "";
      }
      ORDERS::length = 0; // Обнуляем длину массива с приказами.
   }
   // --------------------------------------------------------------------
   
   
   // ОТПРАВЛЯЕМ КОТИРОВКИ, ЕСЛИ ЕСТЬ ПОСТОЯННОЕ ТРЕБОВАНИЕ В ВИДЕ НАЛИЧИЯ В МАССИВЕ ДАННЫХ:
   if(CURRENTPOSTARRAY::length > 0){ // Если массив не пустой, значит поставляем котировки по инструментам массива:
      string sendPrices = "";
      for(int i=0; i < CURRENTPOSTARRAY::length; ++i){
         // Подготавливаем данные для каждого инструмента и отправляем POST запрос:
         string currentAsk = DoubleToString(MarketInfo(currentPriceAndSpreadToSent[i].instrumentName, MODE_ASK), (int)MarketInfo(currentPriceAndSpreadToSent[i].instrumentName, MODE_DIGITS)); // Текущая стоимость по аску.
         string currentBid = DoubleToString(MarketInfo(currentPriceAndSpreadToSent[i].instrumentName, MODE_BID), (int)MarketInfo(currentPriceAndSpreadToSent[i].instrumentName, MODE_DIGITS)); // Текущая стоимость по биду.
         // Определяем время текущего бара:
         datetime tempTime = iTime(currentPriceAndSpreadToSent[i].instrumentName, (int)StringToInteger(currentPriceAndSpreadToSent[i].timeFrame), 0);
         MqlDateTime mqlDateTimeStructure;
         TimeToStruct(tempTime, mqlDateTimeStructure);
         mqlDateTimeStructure.hour + diff;
                     
         int HOURES = mqlDateTimeStructure.hour;
         int MINUTES = mqlDateTimeStructure.min;
         int DAY = mqlDateTimeStructure.day;
         int MONTH = mqlDateTimeStructure.mon;
         int YEAR = mqlDateTimeStructure.year;
                     
         string pref = "0";
         string H = (HOURES < 10) ? pref + IntegerToString(HOURES) : IntegerToString(HOURES);
         string Min = (MINUTES < 10) ? pref + IntegerToString(MINUTES) : IntegerToString(MINUTES);
         string D = (DAY < 10) ? pref + IntegerToString(DAY) : IntegerToString(DAY);
         string Mon = (MONTH < 10) ? pref + IntegerToString(MONTH) : IntegerToString(MONTH);
         string Y = IntegerToString(YEAR);
                     
         string barTime = H + ":" + Min + "&" + D + "/" + Mon + "/" + Y;
         
         // Сравниваем текущее время с предыдущим, чтобы понять сформировался ли новый бар или нет:
         if(barTime == currentPriceAndSpreadToSent[i].lastTime){ // Значит бар не сформировался...
            sendPrices += id + ";POSTNEW;" + currentPriceAndSpreadToSent[i].instrumentName + addDescript + ";" + currentPriceAndSpreadToSent[i].timeFrame + ";" + currentAsk + ";" + currentBid + ";";
            
            int timeFr = (int)StringToInteger(currentPriceAndSpreadToSent[i].timeFrame);
            int epcilon = (int)MarketInfo(currentPriceAndSpreadToSent[i].instrumentName, MODE_DIGITS);
            
            sendPrices +=
                      DoubleToString(iOpen(currentPriceAndSpreadToSent[i].instrumentName, timeFr, 0), epcilon) + ";" +
                      DoubleToString(iHigh(currentPriceAndSpreadToSent[i].instrumentName, timeFr, 0), epcilon) + ";" +
                      DoubleToString(iLow(currentPriceAndSpreadToSent[i].instrumentName, timeFr, 0), epcilon) + ";" +
                      DoubleToString(iClose(currentPriceAndSpreadToSent[i].instrumentName, timeFr, 0), epcilon) + ";" +
                      barTime + ";|";
         }
         else{ // Значит сформировался новый бар...
            sendPrices += id + ";POSTNEWBAR;" + currentPriceAndSpreadToSent[i].instrumentName + addDescript + ";" + currentPriceAndSpreadToSent[i].timeFrame + ";" + currentAsk + ";" + currentBid + ";";
            
            sendPrices = sendPrices +
                      DoubleToString(iOpen(currentPriceAndSpreadToSent[i].instrumentName, (int)StringToInteger(currentPriceAndSpreadToSent[i].timeFrame), 1), (int)MarketInfo(currentPriceAndSpreadToSent[i].instrumentName, MODE_DIGITS)) + ";" +
                      DoubleToString(iHigh(currentPriceAndSpreadToSent[i].instrumentName, (int)StringToInteger(currentPriceAndSpreadToSent[i].timeFrame), 1), (int)MarketInfo(currentPriceAndSpreadToSent[i].instrumentName, MODE_DIGITS)) + ";" +
                      DoubleToString(iLow(currentPriceAndSpreadToSent[i].instrumentName, (int)StringToInteger(currentPriceAndSpreadToSent[i].timeFrame), 1), (int)MarketInfo(currentPriceAndSpreadToSent[i].instrumentName, MODE_DIGITS)) + ";" +
                      DoubleToString(iClose(currentPriceAndSpreadToSent[i].instrumentName, (int)StringToInteger(currentPriceAndSpreadToSent[i].timeFrame), 1), (int)MarketInfo(currentPriceAndSpreadToSent[i].instrumentName, MODE_DIGITS)) + ";" +
                      currentPriceAndSpreadToSent[i].lastTime + ";" +
                      DoubleToString(iOpen(currentPriceAndSpreadToSent[i].instrumentName, (int)StringToInteger(currentPriceAndSpreadToSent[i].timeFrame), 0), (int)MarketInfo(currentPriceAndSpreadToSent[i].instrumentName, MODE_DIGITS)) + ";" +
                      DoubleToString(iHigh(currentPriceAndSpreadToSent[i].instrumentName, (int)StringToInteger(currentPriceAndSpreadToSent[i].timeFrame), 0), (int)MarketInfo(currentPriceAndSpreadToSent[i].instrumentName, MODE_DIGITS)) + ";" +
                      DoubleToString(iLow(currentPriceAndSpreadToSent[i].instrumentName, (int)StringToInteger(currentPriceAndSpreadToSent[i].timeFrame), 0), (int)MarketInfo(currentPriceAndSpreadToSent[i].instrumentName, MODE_DIGITS)) + ";" +
                      DoubleToString(iClose(currentPriceAndSpreadToSent[i].instrumentName, (int)StringToInteger(currentPriceAndSpreadToSent[i].timeFrame), 0), (int)MarketInfo(currentPriceAndSpreadToSent[i].instrumentName, MODE_DIGITS)) + ";" +
                      barTime + ";|";
            
            currentPriceAndSpreadToSent[i].lastTime = barTime;
         }
         
         Print("_________________New bar: " + sendPrices);
         string Ans = sendPOST(true, sendPrices, StringLen(sendPrices), false);
         Print("+++++++++++++++++++++++++");
         if(Answers == "ID_NOT_EXISTS"){
            Alert("ID, указанный в настройках эксперта не эквивалентен выделенному !!! Работа эксперта будет прекращена.");
            OnDeinit(-1);
         }
         else if(Ans == "ERROR_DISCONNECT"){
            Alert("Портал, по каким то причинам разорвал соединение...");
            OnDeinit(-2);
         }
         
      }
   }
}