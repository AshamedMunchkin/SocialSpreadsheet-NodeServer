SpreadsheetServer = require './spreadsheetserver.js'

if process.argv.length isnt 3
  console.log 'Command line argument should be port number'
  return

spreadsheetServer = new SpreadsheetServer process.argv[2]