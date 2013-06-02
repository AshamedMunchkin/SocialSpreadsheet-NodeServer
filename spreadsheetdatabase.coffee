mysql = require 'mysql'
async = require 'async'

DEBUG = true

class SpreadsheetDatabase
  constructor: ->
    @connection = mysql.createConnection(
      host: 'mysql.oscarmarshall.com'
      user: 'socialss'
      password: 'cs3505'
      database: 'socialspreadsheet'
    )

  getSpreadsheetId: (filename, callback) ->
    if DEBUG
      console.log "\nSpreadsheetDatabase.getSpreadsheetId(#{filename}, #{callback})"
      console.log "Query: SELECT id FROM Spreadsheets WHERE filename = #{filename}"
    @connection.query(
      'SELECT id FROM Spreadsheets WHERE filename = ?', [filename]
      (error, rows) ->
        if DEBUG
          console.log "Error: #{error}"
          console.log "Rows: #{rows}"
        if error?
          console.log error
          return
        if rows[0]? then callback rows[0].id else callback 0
    )

  createSpreadsheet: (filename, password, callback) ->
    if DEBUG
      console.log "\nSpreadsheetDatabase.createSpreadsheet(#{filename}, #{password}, #{callback})"
      console.log "Query: INSERT INTO Spreadsheets (filename, password) VALUES (#{filename}, #{password})"
    @connection.query(
      'INSERT INTO Spreadsheets (filename, password) VALUES (?, ?)'
      [filename, password]
      (error) ->
        console.log "Error: #{error}" if DEBUG
        callback not error?
    )

  getSpreadsheetPassword: (id, callback) ->
    if DEBUG
      console.log "\nSpreadsheetDatabase.getSpreadsheetPassword(#{id}, #{callback})"
      console.log "Query: SELECT password FROM Spreadsheets WHERE id = #{id}"
    @connection.query(
      'SELECT password FROM Spreadsheets WHERE id = ?', [id]
      (error, rows) ->
        if DEBUG
          console.log "Error: #{error}"
          console.log "Rows: #{rows}"
        callback rows[0].password
    )

  getSpreadsheetXml: (id, callback) ->
    if DEBUG
      console.log "\nSpreadsheetDatabase.getSpreadsheetXml(#{id}, #{callback})"
      console.log "Query: SELECT name, contents FROM Cells WHERE id = #{id}"
    @connection.query(
      'SELECT name, contents FROM Cells WHERE id = ?', [id], (error, rows) ->
        if DEBUG
          console.log("Error: #{error}")
          console.log("Rows: #{rows}")
        result =
          '<?xml version="1.0" encoding="utf-8"?><spreadsheet version="ps6">'
        async.eachSeries(
          rows
          (row, callback) ->
            result += '<cell>'
            result += "<name>#{row.name}</name>"
            result += "<contents>#{row.contents}</contents>"
            result += '<cell>'
            callback()
          ->
            result += '</spreadsheet>'
            callback result
        )
    )

  changeCell: (filename, cell, contents, callback) ->
    cell = cell.toUpperCase()
    async.auto(
      id: (callback) => @getSpreadsheetId filename, (id) -> callback null, id
      oldContents: (callback, results) =>
        @connection.query(
          'SELECT contents FROM Cells WHERE id = ? AND name = ?'
          [results.id, cell], (error, rows) ->
            callback null, if rows[0]? then rows[0].contents else ''
        )
      deleteOldCell: (callback, results) =>
        @connection.query(
          'DELETE FROM Cells WHERE id = ? AND name = ?', [results.id, cell]
          -> callback()
        )
      insertNewCell: (callback, results) =>
        if contents.length < 0
          callback()
          return
        @connection.query(
          'INSERT INTO Cells (id, name, contents) VALUES (?, ?, ?)'
          [results.id, cell, contents], -> callback()
        )
      (error, results) ->
        callback(
          cell: cell
          oldContents: results.oldContents
        )
    )

module.exports = SpreadsheetDatabase