/* 
 * Copyright (c) 2011, Tristan Linnell <tris@canthack.org>
 *
 * Permission to use, copy, modify, and/or distribute this software for any
 * purpose with or without fee is hereby granted, provided that the above
 * copyright notice and this permission notice appear in all copies.
 *
 * THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
 * WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
 * MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
 * ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
 * WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
 * ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
 * OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
*/

//TemperatureSensor.pde by Tris Linnell, Can't Hack, Won't Hack.
//An Arduino temperature sensor project with SD card logging,
//LCD display output and a reset switch. Writes the temperature
//to the SD card every minute.

#include <LiquidCrystal.h>
#include <SD.h>

const int lcdx = 20;
const int lcdy = 4;

LiquidCrystal lcd(7, 6, 5, 4, 3, 2);

float high = -99999;
float low = 99999;   //high and low temperatures
boolean SDError = false;
unsigned long lastReadingTime = 0L;
float temparray[10]; //array for rolling average
int tempposition = 0; //index into circular buffer above

const int resetPin = 8;
const int inputPin = 0;

const int chipSelect = 10;

char * logFilename = "Temps.txt";

byte celcius[8] = {
	B01000,
	B10100,
	B01000,
	B00000,
	B00011,
	B00100,
	B00011,
	B00000
};

void displayStatus(String s, boolean doClear)
{
  lcd.clear();
  lcd.setCursor(0,0);
  lcd.print(s);
  
  if (doClear)
  {
    delay(2000);
    lcd.clear();
  }
}

void setup() 
{ 
  analogReference(INTERNAL);
  pinMode(resetPin, INPUT);
  pinMode(10, OUTPUT);
  
  lcd.begin(lcdx, lcdy);
  lcd.createChar(0, celcius);
  
  displayStatus("Temperature Sensor", true);  
  displayStatus("Init SD Card...", false);
  
  if (!SD.begin(chipSelect)) {
    displayStatus("SD Card Error", true);  
    displayStatus("No Logging", true); 
    SDError = true;
  }
  else
  {
    boolean newFile = !SD.exists(logFilename);
    File tempFile = SD.open(logFilename, FILE_WRITE);

    if (tempFile) 
    {      
      if (newFile)
      {
        tempFile.println("Arduino Temperature Sensor");
        tempFile.println("  by Tristan Linnell, Can't Hack Won't Hack");
        tempFile.println("  tris@canthack.org   http://canthack.org ");
        tempFile.println();
      }
      
      tempFile.println("**** New Session ****");
      tempFile.close();
    }  
    else 
    {
      displayStatus("Error writing SD File.", true);
      SDError = true;
    }   
  }
  
  lcd.clear();
} 
 
void loop() 
{ 
  if (!SDError)
  {
    lcd.setCursor(lcdx-2, lcdy-1);
    lcd.print("SD"); 
  }
  else
  {
    lcd.setCursor(lcdx-2, lcdy-1);
    lcd.print("  ");
  }
  
  //average results in circular buffer...
  
  //read analog in from the L35
  int input = analogRead(inputPin);
  
  //convert to a voltage
  float voltage = (float)input * 1.1; //internal aref
  voltage /= 1024.0; //10 bit analogue in
  
  temparray[tempposition] = voltage * 100.0;
    
  tempposition++;
  
  if (tempposition >= 10)
    tempposition = 0;
    
    delay(10);

  float temp = 0.0;
  
  for(int i = 0 ; i< 10 ; i++)
  {
    temp += temparray[i];
  }
  temp /= 10.0;
  
  //set high and low, or reset them if the switch
  //has been pressed
  
  if (digitalRead(resetPin) == HIGH)  //todo. use an interrupt for this...
  {
    high = low = temp;
    writeToSD("High and Low reset");
  }
  else
  {
    if(temp < low)
      low = temp;
    
    if(temp > high)
      high = temp;
  }
  
  //write current and high/low to the LCD...
  
  //current
  lcd.setCursor(0,0);
  lcd.print((temp));
  lcd.write(0); //degrees c symbol
  lcd.print("    ");
  
  //low
  lcd.setCursor(0,1);
  lcd.print("Lo:");
  lcd.print((low));
  lcd.write(0); //degrees c symbol
  
  //high
  lcd.print("  Hi:");
  lcd.print((high));
  lcd.write(0); //degrees c symbol 
  lcd.print("    ");
  
  //also write to the SD card, but only every minute...
  
  if ((millis() - lastReadingTime) > (1000L *60L))
  {
    lastReadingTime = millis();
    writeToSD(String(round(lastReadingTime / (1000L *60L))) + "\t" + String(round(temp)) + " \tLo:" + String(round(low)) + "\tHi:" + String(round(high)));
  }  

  delay(200);
} 

void writeToSD(String s)
{ 
  if (!SDError)
  {
    File tempFile = SD.open(logFilename, FILE_WRITE);

    if (tempFile) 
    {
      tempFile.println(s);
      tempFile.close();
    }  
    else 
    {
      displayStatus("SD Error.", true);
      SDError = true;
    }  
  }   
}
