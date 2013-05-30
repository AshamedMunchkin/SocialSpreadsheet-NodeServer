class SpreadsheetServer
  constructor: (port) ->
    net = require 'net'
    #SpreadsheetDatabase = require './spreadsheetdatabase.js'

    #@spreadsheetDatabase = new SpreadsheetDatabase()

    server = net.createServer() #@handleAccept
    server.listen port

  create: (connection, filename, password) ->
    if @spreadsheetDatabase.doesSpreadsheetExist(filename) is yes
      connection.write """
                       CREATE FAIL
                       Name:#{filename}
                       The spreadsheet already exists.

                       """
      return

    @spreadsheetDatabase.createSpreadsheet filename, password
    connection.write """
                     CREATE OK
                     Name:#{filename}
                     Password:#{password}

                     """

  join: (connection, filename, password) ->
    if @spreadsheetDatabase.doesSpreadsheetExist(filename) is no
      connection.write """
                       JOIN FAIL
                       Name:#{filename}
                       Spreadsheet does not exist.

                       """
      return

    if password isnt @spreadsheetDatabase.getSpreadsheetPassword filename
      connection.write """
                       JOIN FAIL
                       Name:#{filename}
                       Incorrect password.

                       """
      return

    xml = @spreadsheetDatabase.getSpreadsheetXml filename
    version = @getVersion filename
    connection.write """
                     JOIN OK
                     Name:#{filename}
                     Version:#{version}
                     Length:#{xml.length}
                     #{xml}

                     """

    @editSessions[filename] ?=
      version: 0
      dones: []
      clients: []
    @editSessions[filename].clients.push connection

  change: (connection, filename, version, cell, contents) ->
    if checkName(conneciton, filename) is no
      connection.write """
                       CHANGE FAIL
                       Name:#{filename}
                       You are not connected to that spreadsheet.

                       """
      return

    if version isnt @getVersion filename
      connection.write """
                       CHANGE WAIT
                       Name:#{filename}
                       Version:#{@editSessions[filename].version}

                       """
      return

    @spreadsheetDatabase.changeCell filename, contents, (done) =>
      @editSessions[filename].dones.push done

    connection.write """
                     CHANGE OK
                     Name:#{filename}
                     Version:#{version = ++@editSessions[filename].version}

                     """

    updateMessage = """
                    UPDATE
                    Name:#{filename}
                    Version:#{version}
                    Cell:#{cell}
                    Length:#{length}
                    #{contents}

                    """
    peer.write(updateMessage) for peer in @editSessions[filename].clients \
        when peer isnt connection

    undo: (connection, filename, version) ->


module.exports = SpreadsheetServer