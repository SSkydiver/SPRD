#ifndef __ORDERS__
#define __ORDERS__

class ORDERS{
public:
   string first; // Тип приказа.
   string second; // Наименование инструмента
   string third; // Таймфрейм инструмента
   string forth; // Объем позиции или количество запрашиваемых баров для прогрузки истории.
   
   string nameWithout;
   
   static int length;
public:
   ORDERS(){
      first = "";
      second = "";
      third = "";
      forth = "";
      
      nameWithout = "";
   }
   
};

int ORDERS::length = 0;


#endif