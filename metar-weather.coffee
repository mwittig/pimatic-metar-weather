# metar weather plugin
module.exports = (env) ->

  events = require 'events'
  Promise = env.require 'bluebird'
  types = env.require('decl-api').types
  _ = env.require 'lodash'
  commons = require('pimatic-plugin-commons')(env)
  rest = require('restler-promise')(Promise)
  moment = require 'moment-timezone'


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
      @framework.deviceManager.registerDeviceClass("MetarWeatherTimeBased", {
        configDef: deviceConfigDef.MetarWeatherTimeBased,
        createCallback: (config, lastState) =>
          return new MetarWeatherTimeBased(config, @, lastState)
      })

  class AttributeContainer extends events.EventEmitter
    constructor: () ->
      @values = {}

  class MetarWeather extends env.devices.Device
    @attributeTemplates =
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
      precipitation:
        description: "Precipitation"
        type: types.string
        acronym: 'PPT'
      observationTime:
        description: "UTC time stamp of the observation record"
        type: types.string
        acronym: 'OT'

    constructor: (@config, @plugin, lastState) ->
      @id = @config.id
      @name = @config.name
      @debug = @plugin.debug || false
      @interval = 60000 * Math.max @config.__proto__.interval, @config.interval
      @base = commons.base @, @config.class
      @attributeValues = new AttributeContainer()
      @attributes = _.cloneDeep(@attributes)
      @attributeHash = {}
      for attributeName in @config.attributes
        do (attributeName) =>
          if MetarWeather.attributeTemplates.hasOwnProperty attributeName
            @attributeHash[attributeName] = true
            properties = MetarWeather.attributeTemplates[attributeName]
            @attributes[attributeName] =
              description: properties.description
              type: properties.type
              unit: properties.unit if properties.unit?
              acronym: properties.acronym if properties.acronym?

            defaultValue = if properties.type is types.number then 0.0 else '-'
            @attributeValues.values[attributeName] = lastState?[attributeName]?.value or defaultValue

            @attributeValues.on attributeName, ((value) =>
              @base.debug "Received update for attribute #{attributeName}: #{value}"
              if value?
                @attributeValues.values[attributeName] = value
                @emit attributeName, value
            )

            @_createGetter(attributeName, =>
              return Promise.resolve @attributeValues.values[attributeName]
            )
          else
            @base.error "Configuration Error. No such attribute: #{attributeName} - skipping."
      super()
      if @config.stationCode?
        baseUrl = 'https://aviationweather.gov/adds/dataserver_current/httpparam?dataSource=metars&requestType=retrieve&format=xml'
        @weatherUrl = "#{baseUrl}&stationString=#{@config.stationCode}"
        @defaultQuery = "&hoursBeforeNow=3&mostRecent=true"
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

    skyConditionsToClouds: (conditions) ->
      clouds = 0
      for condition in conditions
        c = @skyConditionToPercentage condition.$.sky_cover
        if  c > clouds
          clouds = c
      return clouds

    weatherToPrecipitation: (weather) ->
      conditions =
        "-": "light"
        "+": "heavy"
        VC: "in the vicinity"
        MI: "shallow"
        PR: "partial"
        BC: "patches"
        DR: "low drifting"
        BL: "blowing"
        SH: "showers"
        TS: "thunderstorm"
        FZ: "freezing"
        RA: "rain"
        DZ: "drizzle"
        SN: "snow"
        SG: "snow grains"
        IC: "ice crystals"
        PL: "ice pellets"
        GR: "hail"
        GS: "small hail"
        UP: "unknown precipitation"

      condition = []
      if weather?
        offset = 0
        while offset < weather.length
          for own key, value of conditions
            if weather.startsWith key, offset
              condition.push value
              offset += key.length - 1
              break
          offset += 1

      unless condition.length is 0
        return condition.join ' '
      else
        return 'none'


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
          return k.replace 2, ''
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
      rest.get(@weatherUrl + @defaultQuery, {
        parser: rest.restler.parsers.xml
      })
      .then (result) =>
        @base.debug "Response: #{JSON.stringify(result.data)}" if result.data?
        if result.data?.response?.data?[0]?.METAR?[0]?
          data = result.data.response.data[0].METAR[0]

          if @attributeHash.observationTime? and _.isArray(data.observation_time)
            @attributeValues.emit "observationTime", data.observation_time[0]

          if @attributeHash.temperature? and _.isArray(data.temp_c)
            @attributeValues.emit "temperature", parseFloat(data.temp_c)

          if @attributeHash.dewPoint? and _.isArray(data.dewpoint_c)
            @attributeValues.emit "dewPoint", parseFloat(data.dewpoint_c)

          if @attributeHash.humidity? and _.isArray(data.temp_c) and _.isArray(data.dewpoint_c)
            @attributeValues.emit "humidity", @calculateRelativeHumidity parseFloat(data.dewpoint_c), parseFloat(data.temp_c)

          if @attributeHash.windSpeed? and _.isArray(data.wind_speed_kt)
            @attributeValues.emit "windSpeed", @knotsToMetersPerSecond parseFloat(data.wind_speed_kt)

          if @attributeHash.windGust? and _.isArray(data.wind_gust_kt)
            @attributeValues.emit "windGust", @knotsToMetersPerSecond parseFloat(data.wind_gust_kt)

          if @attributeHash.windDirection? and _.isArray(data.wind_dir_degrees)
            @attributeValues.emit "windDirection", @transformWindDirection parseFloat(data.wind_dir_degrees)

          if @attributeHash.pressure? and _.isArray(data.altim_in_hg)
            @attributeValues.emit "pressure", @inHgToMillibar parseFloat(data.altim_in_hg)

          if @attributeHash.clouds? and _.isArray data.sky_condition
            @attributeValues.emit "clouds", @skyConditionsToClouds data.sky_condition

          if @attributeHash.precipitation?
            if _.isArray data.wx_string
              @attributeValues.emit "precipitation", @weatherToPrecipitation(data.wx_string.join ' ')
            else
              @attributeValues.emit "precipitation", "none"
        else
          throw new Error "Response does not contain metar"

      .catch (errorResult) =>
        @base.error if errorResult instanceof Error then errorResult else errorResult.error
      .finally () =>
        @base.scheduleUpdate @requestWeatherData, @interval

  class MetarWeatherTimeBased extends MetarWeather
    constructor: (@config, @plugin, lastState) ->
      @localTimezone = @config.localTimezone.trim().replace(/\ /g , "_")
      @localTimezone = moment.tz.guess() if @localTimezone is ""
      @targetTimezone = @config.targetTimezone.trim().replace(/\ /g , "_")
      @localUtcOffset = parseInt(@config.localUtcOffset) * -1
      @targetUtcOffset = parseInt(@config.targetUtcOffset) * -1
      super(@config, @plugin, lastState)

    destroy: () ->
      super()

    _getTimezoneOffsetString: (offset) ->
      sign = '+'
      if offset < 0
        sign = '-'
        offset *= -1
      hours = '0' + Math.floor(offset).toString()
      minutes = '0' + (Math.round(offset % 1 * 60)).toString()
      sign + hours.substr(hours.length - 2) + minutes.substr(minutes.length - 2)

    requestWeatherData: () =>
      baseTime =
        moment.utc(moment().tz(@localTimezone).utcOffset(@localUtcOffset, true)).format("YYYY-MM-DDTHH:mm:ss")
      targetTimezoneOffset =
        moment.tz.zone(@targetTimezone).parse(Date.UTC()) + @targetUtcOffset * 60

      targetZoneOffset = @_getTimezoneOffsetString(targetTimezoneOffset / -60)
      refDate = new Date(moment(baseTime + targetZoneOffset).tz('UTC').format())
      if targetTimezoneOffset > 0
        hoursBeforeNow = Math.round(targetTimezoneOffset / 60) + 24
        # a positive offset means time at the target is behind the local time
        # this we need to take the measurement data of the previous day
        refDate.setDate(refDate.getDate() - 1)
      else
        hoursBeforeNow = Math.round(Math.abs(targetTimezoneOffset) / 60)

      @base.debug "refDate=#{refDate.toISOString()}; targetTimezoneOffset=#{targetTimezoneOffset}"
      @base.debug "hoursBeforeNow=#{hoursBeforeNow}; baseTime=#{baseTime}"
      rest.get(@weatherUrl + "&hoursBeforeNow=#{hoursBeforeNow}", {
        parser: rest.restler.parsers.xml
      })
      .then (result) =>
        #@base.debug "Response: #{JSON.stringify(result.data)}" if result.data?
        if result.data?.response?.data?[0]?.METAR?[0]?
          # obtain the data record with the observation time which is closest to the refDate
          dataPoints = result.data.response.data[0].METAR
          bestDate = dataPoints.length
          bestDiff = -(new Date(0,0,0)).valueOf()
          currDiff = 0
          for item, index in dataPoints
            currDiff = Math.abs(new Date(dataPoints[index].observation_time[0]) - refDate);
            if currDiff < bestDiff
              bestDate = index
              bestDiff = currDiff

          data = result.data.response.data[0].METAR[bestDate]

          if _.isArray(data.observation_time)
            @base.debug "Using observation data record #{bestDate}
              filed at #{data.observation_time[0]}"

            if @attributeHash.observationTime?
              @attributeValues.emit "observationTime", data.observation_time[0]

          if @attributeHash.temperature? and _.isArray(data.temp_c)
            @attributeValues.emit "temperature", parseFloat(data.temp_c)

          if @attributeHash.dewPoint? and _.isArray(data.dewpoint_c)
            @attributeValues.emit "dewPoint", parseFloat(data.dewpoint_c)

          if @attributeHash.humidity? and _.isArray(data.temp_c) and _.isArray(data.dewpoint_c)
            @attributeValues.emit "humidity", @calculateRelativeHumidity parseFloat(data.dewpoint_c), parseFloat(data.temp_c)

          if @attributeHash.windSpeed? and _.isArray(data.wind_speed_kt)
            @attributeValues.emit "windSpeed", @knotsToMetersPerSecond parseFloat(data.wind_speed_kt)

          if @attributeHash.windGust? and _.isArray(data.wind_gust_kt)
            @attributeValues.emit "windGust", @knotsToMetersPerSecond parseFloat(data.wind_gust_kt)

          if @attributeHash.windDirection? and _.isArray(data.wind_dir_degrees)
            @attributeValues.emit "windDirection", @transformWindDirection parseFloat(data.wind_dir_degrees)

          if @attributeHash.pressure? and _.isArray(data.altim_in_hg)
            @attributeValues.emit "pressure", @inHgToMillibar parseFloat(data.altim_in_hg)

          if @attributeHash.clouds? and _.isArray data.sky_condition
            @attributeValues.emit "clouds", @skyConditionsToClouds data.sky_condition

          if @attributeHash.precipitation?
            if _.isArray data.wx_string
              @attributeValues.emit "precipitation", @weatherToPrecipitation(data.wx_string.join ' ')
            else
              @attributeValues.emit "precipitation", "none"
        else
          throw new Error "Response does not contain metar"

      .catch (errorResult) =>
        @base.error if errorResult instanceof Error then errorResult else errorResult.error
      .finally () =>
        @base.scheduleUpdate @requestWeatherData, @interval

        # ###Finally
  # Create a instance of my plugin
  # and return it to the framework.
  return new MetarWeatherPlugin
