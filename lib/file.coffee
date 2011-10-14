# Requires
util = require 'bal-util'
fs = require 'fs'
path = require 'path'
yaml = null

# Define
class File
	# Required
	layouts: []
	triggerRenderEvent: null
	logger: null

	# Auto
	id: null
	basename: null
	extensions: []
	extension: null
	filename: null
	fullPath: null
	relativePath: null
	relativeBase: null
	content: null
	contentSrc: null
	contentRaw: null
	contentRendered: null

	# User
	title: null
	date: null
	slug: null
	url: null
	ignore: false
	tags: []
	relatedDocuments: []

	# Constructor
	constructor: (fileMeta) ->
		# Delete prototype references
		@layouts = []
		@extensions = []
		@tags = []
		@relatedDocuments = []

		# Copy over meta data
		for own key, value of fileMeta
			@[key] = value

	# Load
	# next(err)
	load: (next) ->
		# Log
		@logger.log 'debug', "Reading the file #{@relativePath}"

		# Async
		tasks = new util.Group (err) =>
			if err
				@logger.log 'err', "Failed to read the file #{@relativePath}"
				return next(err)
			else
				@normalize (err) =>
					return next(err)  if err
					@logger.log 'debug', "Read the file #{@relativePath}"
					next()
		tasks.total = 2

		# Stat the file
		fs.stat @fullPath, (err,fileStat) =>
			return next(err)  if err
			@date = new Date(fileStat.ctime)  unless @date
			tasks.complete()

		# Read the file
		fs.readFile @fullPath, (err,data) =>
			return next(err)  if err
			@parse data.toString(), tasks.completer()
		
		# Chain
		@
	
	# Parse data
	# next(err)
	parse: (fileData,next) ->
		# Handle data
		fileData = fileData.replace(/\r\n?/gm,'\n').replace(/\t/g,'    ')
		fileBody = fileData
		fileMeta = {}
	
		# YAML
		match = /^\s*([\-\#][\-\#][\-\#]+) ?(\w*)\s*/.exec(fileData)
		if match
			# Positions
			seperator = match[1]
			a = match[0].length
			b = fileData.indexOf("\n#{seperator}",a)+1
			c = b+3

			# Parts
			fileHead = fileData.substring(a,b)
			fileBody = fileData.substring(c)
			parser = match[2] or 'yaml'

			# Language
			switch parser
				when 'coffee', 'cson'
					coffee = require 'coffee-script'  unless coffee
					fileMeta = coffee.eval(fileHead)
				
				when 'yaml'
					yaml = require 'yaml'  unless yaml
					fileMeta = yaml.eval(fileHead)
				
				else
					err = new Error("Unknown meta parser [#{parser}]")
					return next(err)

		# Update Meta
		@content = fileBody
		@contentSrc = fileBody
		@contentRaw = fileData
		@contentRendered = fileBody
		@title = @title or @basename or @filename
	
		# Correct meta data
		fileMeta.date = new Date(fileMeta.date)  if fileMeta.date? and fileMeta.date

		# Apply user meta
		for own key, value of fileMeta
			@[key] = value
		
		# Next
		next()
		@
	
	# Normalise data
	# next(err)
	normalize: (next) ->
		# Prepare
		@filename = @basename  if !@filename and @basename
		@basename = @filename  if !@basename and @filename
		@fullPath = @basename  if !@fullPath and @basename
		@relativePath = @fullPath  if !@relativePath and @fullPath
		
		# Names
		@basename = path.basename(@fullPath)
		@filename = @basename
		@basename = @filename.replace(/\..*/, '')

		# Extension
		@extensions = @filename.split /\./g
		@extensions.shift()
		@extension = @extensions[0]

		# Paths
		fullDirPath = path.dirname(@fullPath) or ''
		relativeDirPath = path.dirname(@relativePath).replace(/^\.$/,'') or ''
		@relativeBase = (if relativeDirPath.length then relativeDirPath+'/' else '')+@basename
		@id = @relativeBase

		# Next
		next()
		@
	
	# Contextualize data
	# next(err)
	contextualize: (next) ->
		@getEve (err,eve) =>
			return next(err)  if err
			@extensionRendered = eve.extension
			@filenameRendered = "#{@basename}.#{@extensionRendered}"
			@url or= "/#{@relativeBase}.#{@extensionRendered}"
			@slug or= util.generateSlugSync @relativeBase
			@title or= @filenameRendered
			next()
		
		# Chain
		@
	
	# Get Layout
	# next(err,layout)
	getLayout: (next) ->
		# Check
		return next new Error('This document does not have a layout')  unless @layout

		# Find parent
		@layouts.findOne {relativeBase:@layout}, (err,layout) =>
			# Check
			if err
				return next(err)
			else if not layout
				err = new Error "Could not find the layout: #{@layout}"
				return next(err)
			else
				return next(null, layout)
	
	# Get Eve
	# next(err,layout)
	getEve: (next) ->
		if @layout
			@getLayout (err,layout) ->
				return next(err)  if err
				layout.getEve(next)
		else
			next(null,@)
	
	# Render
	# next(err,finalExtension)
	render: (templateData,next) ->
		# Log
		@logger.log 'debug', "Rendering the file #{@relativePath}"

		# Prepare
		@contentRendered = @content
		@content = @contentSrc

		# Async
		tasks = new util.Group (err) =>
			return next(err)  if err

			# Reset content
			@content = @contentSrc

			# Wrap in layout
			if @layout
				@getLayout (err,layout) =>
					return next(err)  if err
					templateData.content = @contentRendered
					layout.render templateData, (err) =>
						@contentRendered = layout.contentRendered
						@logger.log 'debug', "Rendering completed for #{@relativePath}"
						next err
			else
				@logger.log 'debug', "Rendering completed for #{@relativePath}"
				next err
		
		# Check tasks
		if @extensions.length <= 1
			# No rendering necessary
			tasks.total = 1
			tasks.complete()
			return
		
		# Clone extensions
		extensions = []
		for extension in @extensions
			extensions.unshift extension

		# Cycle through all the extension groups
		previousExtension = null
		for extension in extensions
			# Has a previous extension
			if previousExtension
				# Event data
				eventData = 
					inExtension: previousExtension
					outExtension: extension
					templateData: templateData
					file: @
				
				# Create a task to run
				tasks.push ((eventData) => =>
					# Render through plugins
					@triggerRenderEvent eventData, (err) =>
						return tasks.exit(err)  if err

						# Update rendered content
						@contentRendered = @content

						# Complete
						tasks.complete(err)
				
				)(eventData)

			# Cycle
			previousExtension = extension
		
		# Run tasks synchronously
		tasks.sync()

		# Chain
		@

# Export
module.exports = File
