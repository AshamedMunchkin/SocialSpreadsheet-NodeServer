async = require 'async'
net = require 'net'
SpreadsheetDatabase = require './spreadsheetdatabase'
Connection = require './connection'

class SpreadsheetServer
  constructor: (port) ->
    @editSessions = []
    @spreadsheetDatabase = new SpreadsheetDatabase()

    server = net.createServer (socket) => new Connection(socket, @).start()
    server.listen port
    console.log 'Spreadsheet Server running'

  create: (connection, filename, password) ->
    async.auto(
      getSpreadsheetId: [
        (callback) =>
          @spreadsheetDatabase.getSpreadsheetId filename, (id) ->
            if id isnt 0
              error =
                code: 'FAIL'
                message: 'The spreadsheet already exists.'
            callback error
      ]

      createSpreadsheet: [
        'getSpreadsheetId'
        (callback) =>
          @spreadsheetDatabase.createSpreadsheet filename, password, ->
            callback()
      ]

      createOk: [
        'createSpreadsheet'
        (callback) ->
          connection.sendMessage(
            """
            CREATE OK
            Name:#{filename}
            Password:#{password}

            """
          )
          callback()
      ]

      (error) ->
        switch
          when not error? then return
          else
            connection.sendMessage(
              """
              CREATE FAIL
              Name:#{filename}
              #{error.message}

              """
            )
    )

  join: (connection, filename, password) ->
    async.auto(
      getSpreadsheetId: [
        (callback) =>
          @spreadsheetDatabase.getSpreadsheetId filename, (id) ->
            if id is 0
              error =
                code: 'FAIL'
                message: 'Spreadsheet does not exist.'
            callback error, id
      ]

      isPasswordCorrect: [
        'getSpreadsheetId'
        (callback, results) =>
          @spreadsheetDatabase.getSpreadsheetPassword(
            results.getSpreadsheetId, (spreadsheetPassword) ->
              correct = password is spreadsheetPassword
              if not correct
                error =
                  code: 'FAIL'
                  message: 'Incorrect password.'
              callback error
          )
      ]

      getSpreadsheetXml: [
        'isPasswordCorrect'
        (callback, results) =>
          @spreadsheetDatabase.getSpreadsheetXml(
            results.getSpreadsheetId, (xml) -> callback null, xml
          )
      ]

      createEditSession: [
        'isPasswordCorrect'
        (callback) =>
          @editSessions[filename] ?=
            version: 1
            dones: []
            clients: []
          callback()
      ]

      getVersion: [
        'createEditSession'
        (callback) =>
          callback null, @editSessions[filename].version
      ]

      addClient: [
        'createEditSession'
        (callback) =>
          @editSessions[filename].clients.push connection
          callback()
      ]

      joinOk: [
        'getSpreadsheetXml', 'getVersion'
        (callback, results) ->
          connection.sendMessage(
            """
            JOIN OK
            Name:#{filename}
            Version:#{results.getVersion}
            Length:#{results.getSpreadsheetXml.length}
            #{results.getSpreadsheetXml}

            """
          )
          callback()
      ]

      (error) ->
        switch
          when not error? then return
          else
            connection.sendMessage(
              """
              JOIN FAIL
              Name:#{filename}
              #{error.message}

              """
            )
    )

  change: (connection, filename, version, cell, contents) ->
    async.auto(
      checkName: [
        (callback) =>
          callback @checkName(connection, filename)
      ]

      checkVersion: [
        'checkName'
        (callback) =>
          callback @checkVersion(version, filename)
      ]

      changeCell: [
        'checkVersion'
        (callback) =>
          @spreadsheetDatabase.changeCell filename, cell, contents, (done) ->
            callback null, done
      ]

      pushDone: [
        'changeCell'
        (callback, results) =>
          @editSessions[filename].dones.push results.changeCell
          callback()
      ]

      incrementVersion: [
        'checkVersion'
        (callback) =>
          callback null, ++@editSessions[filename].version
      ]

      changeOk: [
        'incrementVersion'
        (callback, results) ->
          connection.sendMessage(
            """
            CHANGE OK
            Name:#{filename}
            Version:#{results.incrementVersion}

            """
          )
          callback()
      ]

      update: [
        'incrementVersion'
        (callback, results) =>
          @update(
            connection, filename, results.incrementVersion, cell, contents
            ->
              callback()
          )
      ]

      (error) ->
        switch
          when not error? then return
          when error.code is 'FAIL'
            connection.sendMessage(
              """
              CHANGE FAIL
              Name:#{filename}
              #{error.message}

              """
            )
          else
            connection.sendMessage(
              """
              CHANGE WAIT
              Name:#{filename}
              Version:#{error.version}

              """
            )
    )

  undo: (connection, filename, version) ->
    async.auto(
      checkName: [
        (callback) =>
          callback @checkName(connection, filename)
      ]

      checkVersion: [
        'checkName'
        (callback) =>
          callback @checkVersion(version, filename)
      ]

      popDone: [
        'checkVersion'
        (callback) =>
          done = @editSessions[filename].dones.pop()
          if not done?
            error =
              code: 'END'
              version: @editSessions[filename].version
          callback error, done
      ]

      changeCell: [
        'popDone'
        (callback, results) =>
          @spreadsheetDatabase.changeCell(
            filename, results.popDone.cell, results.popDone.oldContents, ->
              callback
          )
      ]

      incrementVersion: [
        'popDone'
        (callback) =>
          callback null, ++@editSessions[filename].version
      ]

      undoOk: [
        'incrementVersion'
        (callback, results) ->
          connection.sendMessage(
            """
            UNDO OK
            Name:#{filename}
            Version:#{results.incrementVersion}
            Cell:#{results.popDone.cell}
            Length:#{results.popDone.oldContents.length}
            #{results.popDone.oldContents}

            """
          )
          callback()
      ]

      update: [
        'incrementVersion'
        (callback, results) =>
          @update(
            connection, filename, results.incrementVersion
            results.popDone.cell, results.popDone.oldContents
            ->
              callback()
          )
      ]

      (error) ->
        switch
          when not error? then return
          when error.code is 'FAIL'
            connection.sendMessage(
              """
              UNDO FAIL
              Name:#{filename}
              #{error.message}

              """
            )
          when error.code is 'WAIT'
            connection.sendMessage(
              """
              UNDO WAIT
              Name:#{filename}
              Version:#{error.version}

              """
            )
          else
            connection.sendMessage(
              """
              UNDO END
              Name:#{filename}
              Version:#{error.version}

              """
            )
    )

  save: (connection, filename) ->
    async.auto(
      checkName: [
        (callback) =>
          callback @checkName(connection, filename)
      ]

      saveOk: [
        (callback) ->
          connection.sendMessage(
            """
            SAVE OK
            Name:#{filename}

            """
          )
      ]

      (error) ->
        switch
          when not error? then return
          else
            connection.sendMessage(
              """
              SAVE FAIL
              Name:#{filename}
              #{error.message}

              """
            )
    )

  leave: (connection, filename) ->
    @editSessions[filename].clients.splice(
      @editSessions[filename].clients.indexOf(connection), 1
    )
    if @editSessions[filename].clients.length is 0
      @editSessions.splice @editSessions.indexOf(filename), 1

  checkName: (connection, filename) ->
    if @editSessions[filename].clients.indexOf(connection) is -1
      error =
        code: 'FAIL'
        message: 'You are not connected to that spreadsheet.' 
    return error

  checkVersion: (version, filename) ->
    correctVersion = @editSessions[filename].version
    console.log "Version: #{version}"
    console.log "Correct Version: #{correctVersion}"
    console.log version is correctVersion.toString()
    if version isnt correctVersion.toString()
      error =
        code: 'WAIT'
        version: correctVersion
    return error

  update: (connection, filename, version, cell, contents, callback) ->
    updateMessage =
      """
      UPDATE
      Name:#{filename}
      Version:#{version}
      Cell:#{cell}
      Length:#{contents.length}
      #{contents}

      """
    async.each(
      @editSessions[filename].clients
      (peer, callback) ->
        return if peer is connection
        peer.sendMessage(updateMessage)
        callback()
      (error) ->
        callback()
    )

module.exports = SpreadsheetServer