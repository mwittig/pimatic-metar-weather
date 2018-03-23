module.exports = {
  title: "pimatic-metar-weather device config schema"
  MetarWeather: {
    title: "Metar Weather"
    description: "Metar Weather Data"
    type: "object"
    extensions: ["xLink", "xAttributeOptions"]
    properties:
      stationCode:
        description: "4-letter station code for the weather station"
        type: "string"
      attributes:
        type: "array"
        default: ["temperature"]
        format: "table"
        items:
          enum: ["temperature", "dewPoint", "humidity", "pressure", "windSpeed",
            "windDirection", "windGust", "clouds", "precipitation", "observationTime"]
      interval:
        description: "The time interval in minutes (minimum 30) at which the report will be queried"
        type: "number"
        default: 30
        minimum: 30
  }
  MetarWeatherTimeBased: {
    title: "Metar Weather"
    description: "Metar Weather Data"
    type: "object"
    extensions: ["xLink", "xAttributeOptions"]
    properties:
      stationCode:
        description: "4-letter station code for the weather station"
        type: "string"
      localTimezone:
        description: "The local time zone to be applied. If empty the timezone derived from the system will be used"
        type: "string"
        default: ""
      localUtcOffset:
        description: "Local timezone offset to be added localTimezone. Useful if target timezone is UTC"
        type: "number"
        default: 0
      targetTimezone:
        description: "The target time zone to be applied. If the timezone is running behind UTC the data of the previous day will be used"
        type: "string"
        default: "UTC"
      targetUtcOffset:
        description: "Target timezone offset to be added targetTimezone. Useful if target timezone is UTC"
        type: "number"
        default: 0
      attributes:
        type: "array"
        default: ["temperature"]
        format: "table"
        items:
          enum: ["temperature", "dewPoint", "humidity", "pressure", "windSpeed",
            "windDirection", "windGust", "clouds", "precipitation", "observationTime"]
      interval:
        description: "The time interval in minutes (minimum 30) at which the report will be queried"
        type: "number"
        default: 30
        minimum: 30
  }
}