###
 * index.coffee
###
# This allows you to control whether queries are automatically mapped
exports.auto_map_queries = true

# Make Document and Embed available from the package
document = require './lib/document'
exports.Document = document.Document
exports.Embed = document.Embed

