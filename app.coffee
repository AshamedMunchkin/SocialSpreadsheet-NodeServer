SpreadsheetServer = require './spreadsheetserver'

if process.argv.length isnt 3
  console.log 'Command line argument should be port number'
  return

new SpreadsheetServer process.argv[2]