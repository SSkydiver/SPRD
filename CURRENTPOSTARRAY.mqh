#ifndef __CURRENTPOSTARRAY__
#define __CURRENTPOSTARRAY__

// Массив инструментов, его длинна и спрэд для которых поставляются котировки:
class CURRENTPOSTARRAY{
public:
   string instrumentName; // Название инструмента без терминала и брокера.
   string timeFrame;
   string ask; // Текущий ask
   string bid; // Текущий bid
   
   string lastTime;
   
   static int length;
public:
   CURRENTPOSTARRAY(){
      instrumentName = "";
      timeFrame = "";
      ask = "";
      bid = "";
      lastTime = "";
   }

};

int CURRENTPOSTARRAY::length = 0;


#endif