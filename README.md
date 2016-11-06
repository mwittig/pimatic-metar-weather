# pimatic-metar-weather

[![Npm Version](https://badge.fury.io/js/pimatic-metar-weather.svg)](http://badge.fury.io/js/pimatic-metar-weather)
[![Build Status](https://travis-ci.org/mwittig/pimatic-metar-weather.svg?branch=master)](https://travis-ci.org/mwittig/pimatic-metar-weather)
[![Dependency Status](https://david-dm.org/mwittig/pimatic-metar-weather.svg)](https://david-dm.org/mwittig/pimatic-metar-weather)

Pimatic plugin to obtain weather data from METAR reports.

## Introduction 

METAR is the abbreviation for *METeorological Aerodrome Reports* standardized by the [ICAO](http://www.icao.int/Pages/default.aspx).
It was introduced in 1968 to provide pilots with observational weather data to be used for pre-flight weather 
briefings, for example. Nowadays, METAR data can be obtained for about 9000 airport sites around the world. 
Typically, the accuracy of the measurement data is better than the data provided by the numerous public weather services.

Currently, the plugin is able to provide data for 

* air temperature at ground-level
* dew point temperature
* relative humidity
* barometric pressure
* wind speed, direction, and gust
* generalized cloud cover in percent based on octas where cover for different heights is accumulated
 
# Future work

There are a couple of things on my list:

* add information on precipitation (rain and snow if available)
* add switch to support imperial measures
* provide a textual report on visibility, clouds and precipitation
* add support for TAF forecasts

## Contributions

Contributions to the project are  welcome. You can simply fork the project and create a pull request with 
your contribution to start with. If you like this plugin, please consider &#x2605; starring 
[the project on github](https://github.com/mwittig/pimatic-metar-weather).

## Plugin Configuration

    {
          "plugin": "metar-weather",
          "debug": false,
    }

The plugin has the following configuration properties:

| Property          | Default  | Type    | Description                                 |
|:------------------|:---------|:--------|:--------------------------------------------|
| debug             | false    | Boolean | Debug mode. Writes debug messages to the pimatic log, if set to true |


## Device Configuration

![Screenshot](https://raw.githubusercontent.com/mwittig/pimatic-metar-weather/master/assets/screenshots/metar-weather.png)

The Metar Weather is provided to obtain weather data for a single location. 

    {
          "id": "metar-1",
          "name": "TXL",
          "class": "MetarWeather",
          "attributes": [
            "temperature",
            "dewPoint",
            "humidity",
            "pressure",
            "windSpeed",
            "windGust",
            "windDirection",
            "clouds"
          ],
          "stationCode": "EDDT",
          "interval": 30
    }
    
The location is identified by four letter station code. It can be looked up as follows: 
* [Europe](http://en.allmetsat.com/metar-taf/europe.php)
* [Africa](http://en.allmetsat.com/metar-taf/africa.php)
* [North America](http://en.allmetsat.com/metar-taf/north-america.php)
* [South America](http://en.allmetsat.com/metar-taf/south-america.php)
* [Asia](http://en.allmetsat.com/metar-taf/asia.php)
* [Australia, Oceania](http://en.allmetsat.com/metar-taf/australia-oceania.php)

The device has the following configuration properties:

| Property          | Default  | Type    | Description                                 |
|:------------------|:---------|:--------|:--------------------------------------------|
| interval          | 30       | Number  | The data acquisition time interval in minutes (minimum 30) |
| stationCode       | -        | String  | The 4-letter station code for the weather station |
| attributes        | "temperature" | Enum | The attribute to be exhibited by the device |

Links
* [Listing of METAR Stations](https://aviationweather.gov/docs/metar/stations.txt)
* [ICAO](http://www.icao.int/Pages/default.aspx)