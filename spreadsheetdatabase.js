// Generated by CoffeeScript 1.6.2
var DEBUG, SpreadsheetDatabase, async, mysql;

mysql = require('mysql');

async = require('async');

DEBUG = true;

SpreadsheetDatabase = (function() {
  function SpreadsheetDatabase() {
    this.connection = mysql.createConnection({
      host: 'mysql.oscarmarshall.com',
      user: 'socialss',
      password: 'cs3505',
      database: 'socialspreadsheet'
    });
  }

  SpreadsheetDatabase.prototype.getSpreadsheetId = function(filename, callback) {
    if (DEBUG) {
      console.log("\nSpreadsheetDatabase.getSpreadsheetId(" + filename + ", " + callback + ")");
      console.log("Query: SELECT id FROM Spreadsheets WHERE filename = " + filename);
    }
    return this.connection.query('SELECT id FROM Spreadsheets WHERE filename = ?', [filename], function(error, rows) {
      if (DEBUG) {
        console.log("Error: " + error);
        console.log("Rows: " + rows);
      }
      if (error != null) {
        console.log(error);
        return;
      }
      if (rows[0] != null) {
        return callback(rows[0].id);
      } else {
        return callback(0);
      }
    });
  };

  SpreadsheetDatabase.prototype.createSpreadsheet = function(filename, password, callback) {
    if (DEBUG) {
      console.log("\nSpreadsheetDatabase.createSpreadsheet(" + filename + ", " + password + ", " + callback + ")");
      console.log("Query: INSERT INTO Spreadsheets (filename, password) VALUES (" + filename + ", " + password + ")");
    }
    return this.connection.query('INSERT INTO Spreadsheets (filename, password) VALUES (?, ?)', [filename, password], function(error) {
      if (DEBUG) {
        console.log("Error: " + error);
      }
      return callback(error == null);
    });
  };

  SpreadsheetDatabase.prototype.getSpreadsheetPassword = function(id, callback) {
    if (DEBUG) {
      console.log("\nSpreadsheetDatabase.getSpreadsheetPassword(" + id + ", " + callback + ")");
      console.log("Query: SELECT password FROM Spreadsheets WHERE id = " + id);
    }
    return this.connection.query('SELECT password FROM Spreadsheets WHERE id = ?', [id], function(error, rows) {
      if (DEBUG) {
        console.log("Error: " + error);
        console.log("Rows: " + rows);
      }
      return callback(rows[0].password);
    });
  };

  SpreadsheetDatabase.prototype.getSpreadsheetXml = function(id, callback) {
    if (DEBUG) {
      console.log("\nSpreadsheetDatabase.getSpreadsheetXml(" + id + ", " + callback + ")");
      console.log("Query: SELECT name, contents FROM Cells WHERE id = " + id);
    }
    return this.connection.query('SELECT name, contents FROM Cells WHERE id = ?', [id], function(error, rows) {
      var result;

      if (DEBUG) {
        console.log("Error: " + error);
        console.log("Rows: " + rows);
      }
      result = '<?xml version="1.0" encoding="utf-8"?><spreadsheet version="ps6">';
      return async.eachSeries(rows, function(row, callback) {
        result += '<cell>';
        result += "<name>" + row.name + "</name>";
        result += "<contents>" + row.contents + "</contents>";
        result += '</cell>';
        return callback();
      }, function() {
        result += '</spreadsheet>';
        return callback(result);
      });
    });
  };

  SpreadsheetDatabase.prototype.changeCell = function(filename, cell, contents, callback) {
    var _this = this;

    cell = cell.toUpperCase();
    return async.auto({
      id: [
        function(callback) {
          return _this.getSpreadsheetId(filename, function(id) {
            return callback(null, id);
          });
        }
      ],
      oldContents: [
        'id', function(callback, results) {
          return _this.connection.query('SELECT contents FROM Cells WHERE id = ? AND name = ?', [results.id, cell], function(error, rows) {
            return callback(null, rows[0] != null ? rows[0].contents : '');
          });
        }
      ],
      deleteOldCell: [
        'oldContents', function(callback, results) {
          return _this.connection.query('DELETE FROM Cells WHERE id = ? AND name = ?', [results.id, cell], function() {
            return callback();
          });
        }
      ],
      insertNewCell: [
        'deleteOldCell', function(callback, results) {
          if (contents.length < 0) {
            callback();
            return;
          }
          return _this.connection.query('INSERT INTO Cells (id, name, contents) VALUES (?, ?, ?)', [results.id, cell, contents], function() {
            return callback();
          });
        }
      ]
    }, function(error, results) {
      return callback({
        cell: cell,
        oldContents: results.oldContents
      });
    });
  };

  return SpreadsheetDatabase;

})();

module.exports = SpreadsheetDatabase;
