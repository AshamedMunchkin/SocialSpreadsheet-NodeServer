events = require 'events'
async = require 'async'

DEBUG = true

class Connection extends events.EventEmitter
  constructor: (@socket, @server) ->
    @buffer = ''
    @socket.setEncoding 'utf8'
    @socket.on 'data', (data) =>
      @buffer += String data
      @emit 'data'
    @socket.on 'error', (error) ->
      if error?
        console.log error
    console.log 'Connection created'
  
  start: ->
    @readUntil '\n', (command) => @primaryHandler command

  primaryHandler: (command) ->
    switch command
      when 'CREATE', 'JOIN'
        async.series(
          name: (callback) =>
            @readUntil '\n', (response) ->
              name = response.substring 5
              callback null, name
          password: (callback) =>
            @readUntil '\n', (response) ->
              password = response.substring 9
              callback null, password
          (error, results) =>
            switch command
              when 'CREATE'
                @server.create @, results.name, results.password
              else @server.join @, results.name, results.password
            @start()
        )
      when 'CHANGE'
        async.series(
          name: (callback) =>
            @readUntil '\n', (response) ->
              name = response.substring 5
              callback null, name
          version: (callback) =>
            @readUntil '\n', (response) ->
              version = response.substring 8
              callback null, version
          cell: (callback) =>
            @readUntil '\n', (response) ->
              cell = response.substring 5
              callback null, cell
          length: (callback) =>
            @readUntil '\n', (response) ->
              length = response.substring 7
              callback null, length
          content: (callback) =>
            @readUntil '\n', (content) ->
              callback null, content
          (error, results) =>
            @server.change(
              @, results.name, results.version, results.cell, results.content
            )
            @start()
        )
      when 'UNDO'
        async.series(
          name: (callback) =>
            @readUntil '\n', (response) ->
              name = response.substring 5
              callback null, name
          version: (callback) =>
            @readUntil '\n', (response) ->
              version = response.substring 8
              callback null, version
          (error, results) =>
            @server.undo @, results.name, results.version
            @start()
        )
      when 'SAVE', 'LEAVE'
        async.series(
          name: (callback) =>
            @readUntil '\n', (response) ->
              name = response.substring 5
              callback null, name
          (error, results) =>
            switch command
              when 'SAVE' then @server.save @, results.name
              else @server.leave @, results.name
            @start()
        )
      else
        @sendMessage(
          """
          ERROR

          """)
        @start()

  readUntil: (delimiter, callback) ->
    index = @buffer.indexOf delimiter
    if index isnt -1
      result = @buffer.substring 0, index
      @buffer = @buffer.substring index + delimiter.length
      console.log("\n#{result}") if DEBUG
      callback result
      return
    @once 'data', ->
      @readUntil delimiter, callback

  sendMessage: (message) ->
    console.log("\n#{message}") if DEBUG
    @socket.write message

module.exports = Connection