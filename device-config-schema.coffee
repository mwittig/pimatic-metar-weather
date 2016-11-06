module.exports = {
  title: "pimatic-metar-weather device config schema"
  MetarWeather: {
    title: "Metar Weather"
    description: "Metar Weather Data"
    type: "object"
    extensions: ["xLink", "xPresentLabel", "xAbsentLabel"]
    properties:
      stationCode:
        description: "4-letter station code for the weather station"
        type: "string"
      attributes:
        type: "array"
        default: ["temperature"]
        format: "table"
        items:
          enum: ["temperature", "dewPoint", "humidity", "pressure", "windSpeed", "windDirection", "windGust", "clouds"]
      interval:
        description: "The time interval in minutes (minimum 30) at which the report will be queried"
        type: "number"
        default: 30
        minimum: 30
  }
}