# Requires
path = require('path')
FileModel = require(path.join __dirname, 'file.coffee')

# Layout Model
LayoutModel = FileModel.extend
#class LayoutModel extends FileModel
	
	# Model Type
	type: 'layout'

# Export
module.exports = LayoutModel
