# Yamaha AVR plugin
module.exports = (env) ->

  events = require 'events'
  Promise = env.require 'bluebird'
  types = env.require('decl-api').types
  _ = env.require 'lodash'
  commons = require('pimatic-plugin-commons')(env)
  rest = require('restler-promise')(Promise)


  # ###MetarWeatherPlugin class
  class MetarWeatherPlugin extends env.plugins.Plugin
    init: (app, @framework, @config) =>
      @debug = @config.debug || false
      @base = commons.base @, 'Plugin'
      # register devices
      deviceConfigDef = require("./device-config-schema")
      @base.debug "Registering device class MetarWeather"
      @framework.deviceManager.registerDeviceClass("MetarWeather", {
        configDef: deviceConfigDef.MetarWeather,
        createCallback: (config, lastState) =>
          return new MetarWeather(config, @, lastState)
      })

  class AttributeContainer extends events.EventEmitter
    constructor: () ->
      @values = {}

  class MetarWeather extends env.devices.Device
    attributeTemplates =
      status:
        description: "The actual status"
        type: types.string
      temperature:
        description: "Air temperature"
        type: types.number
        unit: '°C'
        acronym: 'T'
      dewPoint:
        description: "Dew Point Temperature"
        type: types.number
        unit: "°C"
        acronym: 'DT'
      humidity:
        description: "The actual degree of Humidity"
        type: types.number
        unit: '%'
        acronym: 'RH'
      pressure:
        description: "Air pressure"
        type: types.number
        unit: 'mbar'
        acronym: 'P'
      windSpeed:
        description: "Wind speed"
        type: types.number
        unit: 'm/s'
        acronym: 'WS'
      windGust:
        description: "Wind gust speed"
        type: types.number
        unit: 'm/s'
        acronym: 'GST'
      windDirection:
        description: "Direction from which the wind is blowing."
        type: types.string
        acronym: 'WD'
      clouds:
        description: "Cloudyness"
        type: types.number
        unit: '%'
        acronym: 'CLOUDS'

    constructor: (@config, @plugin, lastState) ->
      @id = @config.id
      @name = @config.name
      @debug = @plugin.debug || false
      @interval = 60000 * Math.max @config.__proto__.interval, @config.interval
      @base = commons.base @, @config.class
      @attributeValues = new AttributeContainer()
      @attributes = _.cloneDeep(@attributes)
      for attributeName in @config.attributes
        do (attributeName) =>
          if attributeTemplates.hasOwnProperty attributeName
            properties = attributeTemplates[attributeName]
            @attributes[attributeName] =
              description: properties.description
              type: properties.type
              unit: properties.unit if properties.unit?
              acronym: properties.acronym if properties.acronym?

            defaultValue = if properties.type is types.number then 0.0 else '-'
            @attributeValues.values[attributeName] = lastState?[attributeName]?.value or defaultValue

            @attributeValues.on properties.key, ((value) =>
              @base.debug "Received update for property #{properties.key}: #{value}"
              if value.value?
                @attributeValues.values[attributeName] = value.value
                @emit attributeName, value.value
            )

            @_createGetter(attributeName, =>
              return Promise.resolve @attributeValues.values[attributeName]
            )
          else
            @base.error "Configuration Error. No such attribute: #{attributeName} - skipping."
      super()
      if @config.stationCode?
        baseUrl = 'https://aviationweather.gov/adds/dataserver_current/httpparam?dataSource=metars&requestType=retrieve&format=xml'
        @weatherUrl = "#{baseUrl}&stationString=#{@config.stationCode}&hoursBeforeNow=3&mostRecent=true"
        @requestWeatherData()

    destroy: () ->
      @base.cancelUpdate()
      super

    skyConditionToPercentage: (value) ->
      conditions =
        CLR: 0
        SKC: 0
        CAVOK: 12.5
        NSC: 12.5
        FEW: 25
        SCT: 50
        BKN: 75
        OVC: 100
        OVX: 100

      if conditions[value]?
        return conditions[value]
      else
        return -1

    skyConditionToClouds: (value) ->
      conditions =
        CLR: "clear sky"
        SKC: "clear sky"
        CAVOK: "few clouds"
        NSC: "few clouds"
        FEW: "few clouds"
        SCT: "scattered clouds"
        BKN: "broken clouds"
        OVC: "overcast"
        OVX: "overcast"

      if conditions[value]?
        return conditions[value]
      else
        return '-'

    transformWindDirection: (value) ->
      direction =
        VRB: 0
        N: 11.25
        NNE: 33.75
        NE: 56.25
        ENE: 78.75
        E: 101.25
        ESE: 123.75
        SE: 146.25
        SSE: 168.75
        S: 191.25
        SSW: 213.75
        SW: 236.25
        WSW: 258.75
        W: 281.25
        WNW: 303.75
        NW: 326.25
        NNW: 348.75
        N2: 360.25

      for own k, v of direction
        if value < v or value is 0
          return k.replace 2
      return '-'

    knotsToMetersPerSecond: (knots) ->
      Math.round(knots * 4630 / 900) / 10

    inHgToMillibar: (inHg) ->
      Math.round(1013.2 * inHg / 29.92)

    milesToKm: (mph) ->
      Math.round(mph * 1.60934)

    calculateRelativeHumidity: (td, t) ->
      Math.round 100 * Math.exp((17.625*td)/(243.04+td)) / Math.exp((17.625*t)/(243.04+t))

    requestWeatherData: () =>
      return new Promise (resolve, reject) =>
        rest.get(@weatherUrl, {
          parser: rest.restler.parsers.xml
        })
        .then (result) =>
          @base.debug "Response: #{JSON.stringify(result.data)}" if result.data?
          if result.data?.response?.data?[0]?.METAR?[0]?
            data = result.data.response.data[0].METAR[0]
            @base.debug data
            @emit "temperature", parseFloat(data.temp_c) if data.temp_c?
            if data.dewpoint_c?
              dt = parseFloat(data.dewpoint_c)
              @emit "dewPoint", dt
              @emit "humidity", @calculateRelativeHumidity dt, parseFloat(data.temp_c) if data.temp_c?
            @emit "windSpeed", @knotsToMetersPerSecond parseFloat(data.wind_speed_kt) if data.wind_speed_kt?
            @emit "windGust", @knotsToMetersPerSecond parseFloat(data.wind_gust_kt) if data.wind_gust_kt?
            @emit "windDirection", @transformWindDirection parseFloat(data.wind_dir_degrees) if data.wind_dir_degrees?
            @emit "pressure", @inHgToMillibar parseFloat(data.altim_in_hg) if data.altim_in_hg?
            if data.sky_condition? and _.isArray data.sky_condition
              clouds = 0
              cover = 'CLR'
              for condition in data.sky_condition
                p = @skyConditionToPercentage condition.$.sky_cover
                if clouds < p
                  clouds = p
                  cover = condition.$.sky_cover
              @emit "clouds", clouds
#          if query.resultCode(result.data) is 0
#            resolve result.data
#          else
#            throw new Error "Command #{command} failed with return code #{query.resultCode result.data}"
        .catch (errorResult) =>
          reject if errorResult instanceof Error then errorResult else errorResult.error
        .finally () =>
          @base.scheduleUpdate @requestWeatherData, @interval

  # ###Finally
  # Create a instance of my plugin
  # and return it to the framework.
  return new MetarWeatherPlugin