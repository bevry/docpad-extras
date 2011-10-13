###
Docpad by Benjamin Lupton
The easiest way to generate your static website.
###

# Requirements
fs = require 'fs'
path = require 'path'
sys = require 'sys'
caterpillar = require 'caterpillar'
util = require 'bal-util'
exec = require('child_process').exec
growl = require('growl')
express = false
watchTree = false
queryEngine = false
packageJSON = JSON.parse fs.readFileSync("#{__dirname}/../package.json").toString()
require "#{__dirname}/prototypes.coffee"


# -------------------------------------
# Docpad

class Docpad
	# Options
	rootPath: null
	outPath: 'out'
	srcPath: 'src'
	corePath: "#{__dirname}/.."
	skeleton: 'bootstrap'
	maxAge: false
	logLevel: 6
	version: packageJSON.version

	# Docpad
	generating: false
	loading: true
	generateTimeout: null
	actionTimeout: null
	server: null
	port: 9778
	logger: null

	# Models
	File: null
	Layout: null
	Document: null
	layouts: null
	documents: null
	
	# Plugins
	pluginsArray: []
	pluginsObject: {}

	# Skeletons
	skeletons:
		bootstrap:
			repo: 'https://github.com/balupton/bootstrap.docpad.git'


	# ---------------------------------
	# Main

	# Init
	constructor: ({rootPath,outPath,srcPath,skeleton,maxAge,port,server,logLevel}={}) ->
		# Options
		@pluginsArray = []
		@pluginsObject = {}
		@port = port  if port
		@maxAge = maxAge  if maxAge
		@server = server  if server
		@rootPath = path.normalize(rootPath || process.cwd())
		@outPath = path.normalize(outPath || "#{@rootPath}/#{@outPath}")
		@srcPath = path.normalize(srcPath || "#{@rootPath}/#{@srcPath}")
		@skeleton = skeleton  if skeleton

		# Logger
		@logger = new caterpillar.Logger
			transports:
				level: logLevel or @logLevel
				formatter:
					module: module
		
		# Version Check
		@compareVersion()
		
		# Load Plugins
		@loadPlugins null, =>
			@loading = false
	
	# Layout Document
	createDocument: (data) ->
		# Create
		document = new @Document(data)
		docpad = @

		# Prepare event
		document.layouts = @layouts
		document.logger = @logger
		document.triggerRenderEvent = (args...) ->
			args.unshift('render')
			docpad.triggerEvent.apply(docpad,args)
		
		# Return document
		document
	
	# Create Layout
	createLayout: (data) ->
		# Create
		layout = new @Layout(data)
		docpad = @

		# Prepare
		layout.layouts = @layouts
		layout.logger = @logger
		layout.triggerRenderEvent = (args...) ->
			args.unshift('render')
			docpad.triggerEvent.apply(docpad,args)
		
		# Return layout
		layout

	# Clean Models
	cleanModels: (next) ->
		File = @File = require("#{__dirname}/file.coffee")
		Layout = @Layout = class extends File
		Document = @Document = class extends File
		layouts = @layouts = new queryEngine.Collection
		documents = @documents = new queryEngine.Collection
		Layout::save = ->
			layouts[@id] = @
		Document::save = ->
			documents[@id] = @
		next()  if next

	# Compare versions
	compareVersion: ->
		util.packageCompare
			local: "#{__dirname}/../package.json"
			remote: 'https://raw.github.com/balupton/docpad/master/package.json'
			newVersionCallback: (details) =>
				growl.notify 'There is a new version of docpad available'
				@logger.log 'notice', """
					There is a new version of docpad available, you should probably upgrade...
					current version:  #{details.local.version}
					new version:      #{details.remote.version}
					grab it here:     #{details.remote.homepage}
					"""

	# Initialise the Skeleton
	initialiseSkeleton: (skeleton, destinationPath, next) ->
		# Prepare
		logger = @logger
		skeletonRepo = @skeletons[skeleton].repo
		logger.log 'info', "[#{skeleton}] Initialising the Skeleton to #{destinationPath}"
		snoring = false
		notice = setTimeout(
			->
				snoring = true
				logger.log 'notice', "[#{skeleton}] This could take a while, grab a snickers"
			2000
		)

		# Async
		tasks = new util.Group (err) ->
			logger.log 'info', "[#{skeleton}] Initialised the Skeleton"  unless err
			next err
		tasks.total = 2
		
		# Pull
		logger.log 'debug', "[#{skeleton}] Pulling in the Skeleton"
		child = exec(
			# Command
			"git init; git remote add skeleton #{skeletonRepo}; git pull skeleton master"
			
			# Options
			{
				cwd: destinationPath
			}

			# Next
			(err,stdout,stderr) ->
				# Output
				if err
					console.log stdout.replace(/\s+$/,'')  if stdout
					console.log stderr.replace(/\s+$/,'')  if stderr
					return next err
				
				# Log
				logger.log 'debug', "[#{skeleton}] Pulled in the Skeleton"

				# Submodules
				path.exists "#{destinationPath}/.gitmodules", (exists) ->
					tasks.complete()  unless exists
					logger.log 'debug', "[#{skeleton}] Initialising Submodules for Skeleton"
					child = exec(
						# Command
						'git submodule init; git submodule update; git submodule foreach --recursive "git init; git checkout master; git submodule init; git submodule update"'
						
						# Options
						{
							cwd: destinationPath
						}

						# Next
						(err,stdout,stderr) ->
							# Output
							if err
								console.log stdout.replace(/\s+$/,'')  if stdout
								console.log stderr.replace(/\s+$/,'')  if stderr
								return tasks.complete(err)  
							
							# Complete
							logger.log 'debug', "[#{skeleton}] Initalised Submodules for Skeleton"
							tasks.complete()
					)
				
				# NPM
				path.exists "#{destinationPath}/package.json", (exists) ->
					tasks.complete()  unless exists
					logger.log 'debug', "[#{skeleton}] Initialising NPM for Skeleton"
					child = exec(
						# Command
						'npm install'

						# Options
						{
							cwd: destinationPath
						}

						# Next
						(err,stdout,stderr) ->
							# Output
							if err
								console.log stdout.replace(/\s+$/,'')  if stdout
								console.log stderr.replace(/\s+$/,'')  if stderr
								return tasks.complete(err)  
							
							# Complete
							logger.log 'debug', "[#{skeleton}] Initialised NPM for Skeleton"
							tasks.complete()
					)
		)
	
	# Handle
	action: (action,next=null) ->
		# Prepare
		logger = @logger
		next or= -> process.exit()

		# Clear
		if @actionTimeout
			clearTimeout(@actionTimeout)
			@actionTimeout = null

		# Check
		if @loading
			@actionTimeout = setTimeout(
				=>
					@action(action, next)
				1000
			)
			return
		
		# Handle
		switch action
			when 'skeleton', 'scaffold'
				@skeletonAction (err) ->
					return @error(err)  if err
					next()

			when 'generate'
				@generateAction (err) ->
					return @error(err)  if err
					next()

			when 'watch'
				@watchAction (err) ->
					return @error(err)  if err
					logger.log 'info', 'DocPad is now watching you...'

			when 'server', 'serve'
				@serverAction (err) ->
					return @error(err)  if err
					logger.log 'info', 'DocPad is now serving you...'

			else
				@skeletonAction (err) =>
					return @error(err)  if err
					@generateAction (err) =>
						return @error(err)  if err
						@serverAction (err) =>
							return @error(err)  if err
							@watchAction (err) =>
								return @error(err)  if err
								logger.log 'info', 'DocPad is now watching and serving you...'
	

	# Handle an error
	error: (err) ->
		@logger.log 'err', "An error occured: #{err}\n", err  if err



	# ---------------------------------
	# Plugins

	# Register a Plugin
	# next(err)
	registerPlugin: (plugin,next) ->
		# Prepare
		logger = @logger
		error = null

		# Plugin Path
		if typeof plugin is 'string'
			try
				pluginPath = plugin
				plugin = require pluginPath
				return @registerPlugin plugin, next
			catch err
				logger.log 'warn', 'Unable to load plugin', pluginPath
				logger.log 'debug', err
		
		# Loaded Plugin
		else if plugin and (plugin.name? or plugin::name?)
			plugin = new plugin  if typeof plugin is 'function'
			@pluginsObject[plugin.name] = plugin
			@pluginsArray.push plugin
			@pluginsArray.sort (a,b) -> a.priority < b.priority
			logger.log 'debug', "Loaded plugin [#{plugin.name}]"
		
		# Unknown Plugin Type
		else
			logger.log 'warn', 'Unknown plugin type', plugin
		
		# Forward
		next error
	

	# Get a plugin by it's name
	getPlugin: (pluginName) ->
		@pluginsObject[pluginName]


	# Trigger a plugin event
	# next(err)
	triggerEvent: (eventName,data,next) ->
		# Async
		logger = @logger
		tasks = new util.Group (err) ->
			logger.log 'debug', "Plugins completed for #{eventName}"
			next err
		tasks.total = @pluginsArray.length

		# Cycle
		for plugin in @pluginsArray
			data.docpad = @
			data.logger = logger
			data.util = util
			plugin[eventName].apply plugin, [data,tasks.completer()]


	# Load Plugins
	loadPlugins: (pluginsPath, next) ->
		# Prepare
		logger = @logger

		# Load
		unless pluginsPath
			# Async
			tasks = new util.Group (err) ->
				logger.log 'debug', 'Plugins loaded'
				next err
			
			tasks.push => @loadPlugins "#{__dirname}/plugins", tasks.completer()
			if @rootPath isnt __dirname and path.existsSync "#{@rootPath}/plugins"
				tasks.push => @loadPlugins "#{@rootPath}/plugins", tasks.completer()
			
			tasks.async()

		else
			util.scandir(
				# Path
				pluginsPath,

				# File Action
				(fileFullPath,fileRelativePath,nextFile) =>
					if /\.plugin\.[a-zA-Z0-9]+/.test(fileRelativePath)
						@registerPlugin fileFullPath, nextFile
					else
						nextFile()
				
				# Dir Action
				false,

				# Next
				(err) ->
					logger.log 'debug', "Plugins loaded for #{pluginsPath}"
					next err
			)


	# ---------------------------------
	# Actions

	# Clean the database
	generateClean: (next) ->
		# Prepare
		logger = @logger
		logger.log 'debug', 'Cleaning started'

		# Models
		@cleanModels()
		
		# Async
		tasks = new util.Group (err) ->
			logger.log 'debug', 'Cleaning finished'  unless err
			next err
		tasks.total = 2

		# Layouts
		@layouts.remove {}, (err) ->
			logger.log 'debug', 'Cleaned layouts'  unless err
			tasks.complete err
		
		# Documents
		@documents.remove {}, (err) ->
			logger.log 'debug', 'Cleaned documents'  unless err
			tasks.complete err


	# Check if the file path is ignored
	# next(err,ignore)
	filePathIgnored: (fileFullPath,next) ->
		if path.basename(fileFullPath).startsWith('.') or path.basename(fileFullPath).finishesWith('~')
			next null, true
		else
			next null, false


	# Parse the files
	generateParse: (next) ->
		# Requires
		logger = @logger
		docpad = @
		logger.log 'debug', 'Parsing files'

		# Paths
		layoutsSrcPath = @srcPath+'/layouts'
		documentsSrcPath = @srcPath+'/documents'

		# Async
		tasks = new util.Group (err) ->
			return next(err)  if err
			logger.log 'debug', 'Parsed files'  unless err
			next()
		tasks.total = 2

		# Layouts
		util.scandir(
			# Path
			layoutsSrcPath,

			# File Action
			(fileFullPath,fileRelativePath,nextFile) ->
				# Ignore?
				docpad.filePathIgnored fileFullPath, (err,ignore) ->
					return nextFile(err)  if err or ignore
					layout = docpad.createLayout(
							fullPath: fileFullPath
							relativePath: fileRelativePath
					)
					layout.load (err) ->
						return nextFile err  if err
						layout.save()
						nextFile err
				
			# Dir Action
			false,

			# Next
			(err) ->
				logger.log 'warn', 'Failed to parse layouts', err  if err
				tasks.complete err
		)

		# Documents
		util.scandir(
			# Path
			documentsSrcPath,

			# File Action
			(fileFullPath,fileRelativePath,nextFile) ->
				# Ignore?
				docpad.filePathIgnored fileFullPath, (err,ignore) ->
					return nextFile(err)  if err or ignore
					document = docpad.createDocument(
						fullPath: fileFullPath
						relativePath: fileRelativePath
					)
					document.load (err) ->
						return nextFile err  if err
						document.save()
						nextFile err
			
			# Dir Action
			false,

			# Next
			(err) ->
				logger.log 'warn', 'Failed to parse documents', err  if err
				tasks.complete err
		)

	# Generate contextualize
	generateContextualize: (next) ->
		# Prepare
		docpad = @
		logger = @logger
		logger.log 'debug', 'Contextualizing files'

		# Async
		tasks = new util.Group (err) ->
			return next(err)  if err
			logger.log 'debug', 'Contextualized files'
			next()
		
		# Fetch
		documents = @documents.find({}).sort({'date':-1})
		tasks.total += documents.length

		# Scan all documents
		documents.forEach (document) ->
			document.contextualize tasks.completer()

	# Generate render
	generateRender: (next) ->
		# Prepare
		docpad = @
		logger = @logger
		logger.log 'debug', 'Rendering files'

		# Async
		tasks = new util.Group (err) ->
			return next(err)  if err
			logger.log 'debug', 'Rendered files'
			next()
		
		# Prepare site data
		Site = site =
			date: new Date()

		# Prepare template data
		documents = @documents.find({}).sort({'date':-1})
		templateData = 
			documents: documents
			document: null
			Documents: documents
			Document: null
			site: site
			Site: site

		# Trigger Helpers
		@triggerEvent 'renderStarted', {documents,templateData}, (err) ->
			return next err  if err
			# Render documents
			tasks.total += documents.length
			documents.forEach (document) ->
				templateData.document = templateData.Document = document
				document.render(
					templateData
					tasks.completer()
				)


	# Write files
	generateWriteFiles: (next) ->
		# Prepare
		logger = @logger
		logger.log 'debug', 'Writing files'

		# Determine Path
		filesPath = @srcPath+'/files'
		path.exists filesPath, (exists) =>
			# Public Path
			filesPath = @srcPath+'/public'  unless exists

			# Write
			util.cpdir(
				# Src Path
				filesPath,
				# Out Path
				@outPath
				# Next
				(err) ->
					logger.log 'debug', 'Wrote files'  unless err
					next err
			)


	# Write documents
	generateWriteDocuments: (next) ->
		# Prepare
		logger = @logger
		outPath = @outPath
		logger.log 'debug', 'Writing documents'

		# Async
		tasks = new util.Group (err) ->
			logger.log 'debug', 'Wrote documents'  unless err
			next err

		# Find documents
		@documents.find {}, (err,documents,length) ->
			# Error
			return tasks.exit err  if err

			# Cycle
			tasks.total += length
			documents.forEach (document) ->
				# Generate path
				fileFullPath = "#{outPath}/#{document.url}" #relativeBase+'.html'
				# Ensure path
				util.ensurePath path.dirname(fileFullPath), (err) ->
					# Error
					return tasks.exit err  if err

					# Write document
					fs.writeFile fileFullPath, document.contentRendered, (err) ->
						tasks.complete err


	# Write
	generateWrite: (next) ->
		# Prepare
		logger = @logger
		logger.log 'debug', 'Writing everything'

		# Async
		tasks = new util.Group (err) ->
			logger.log 'debug', 'Wrote everything'  unless err
			next err
		tasks.total = 2

		# Files
		@generateWriteFiles tasks.completer()
		
		# Documents
		@generateWriteDocuments tasks.completer()


	# Generate
	generateAction: (next) ->
		# Prepare
		docpad = @
		logger = @logger
		queryEngine = require('query-engine')  unless queryEngine

		# Clear
		if @generateTimeout
			clearTimeout(@generateTimeout)
			@generateTimeout = null

		# Check
		if @generating
			logger.log 'notice', 'Generate request received, but we are already busy generating... waiting...'
			@generateTimeout = setTimeout(
				=>
					@generateAction next
				500
			)
		else
			logger.log 'info', 'Generating...'
			@generating = true

		# Continue
		path.exists @srcPath, (exists) ->
			# Check
			if exists is false
				return next new Error 'Cannot generate website as the src dir was not found'

			# Log
			logger.log 'debug', 'Cleaning the out path'

			# Continue
			util.rmdir docpad.outPath, (err,list,tree) ->
				if err
					logger.log 'err', 'Failed to clean the out path', docpad.outPath
					return next err
				logger.log 'debug', 'Cleaned the out path'

				# Generate Clean
				docpad.generateClean (err) ->
					return next err  if err
					# Clean Completed
					docpad.triggerEvent 'cleanFinished', {}, (err) ->
						return next err  if err

						# Generate Parse
						docpad.generateParse (err) ->
							return next err  if err
							# Parse Completed
							docpad.triggerEvent 'parseFinished', {}, (err) ->
								return next err  if err

								# Generate Contextualize
								docpad.generateContextualize (err) ->
										# Contextualize Completed
										docpad.triggerEvent 'contextualizeFinished', {}, (err) ->
											return next err  if err

											# Generate Render
											docpad.generateRender (err) ->
												return next err  if err
												# Render Completed
												docpad.triggerEvent 'renderFinished', {}, (err) ->
													return next err  if err

													# Generate Write
													docpad.generateWrite (err) ->
														# Write Completed
														docpad.triggerEvent 'writeFinished', {}, (err) ->
															return next(err)  if err
															growl.notify (new Date()).toLocaleTimeString(), title: 'Website Generated'
															logger.log 'info', 'Generated'
															docpad.cleanModels()
															docpad.generating = false
															next()


	# Watch
	watchAction: (next) ->
		# Prepare
		logger = @logger
		docpad = @
		watchTree = require 'watch-tree'	unless watchTree
		logger.log 'Watching setup starting...'

		# Watch the src directory
		watcher = watchTree.watchTree(docpad.srcPath)
		watcher.on 'fileDeleted', (path) ->
			docpad.generateAction ->
				logger.log 'Regenerated due to file delete at '+(new Date()).toLocaleString()
		watcher.on 'fileCreated', (path,stat) ->
			docpad.generateAction ->
				logger.log 'Regenerated due to file create at '+(new Date()).toLocaleString()
		watcher.on 'fileModified', (path,stat) ->
			docpad.generateAction ->
				logger.log 'Regenerated due to file change at '+(new Date()).toLocaleString()

		# Log
		logger.log 'Watching setup'

		# Next
		next()


	# Skeleton
	skeletonAction: (next) ->
		# Prepare
		logger = @logger
		docpad = @
		skeleton = @skeleton
		destinationPath = @rootPath

		# Copy
		path.exists docpad.srcPath, (exists) =>
			# Check
			if exists
				logger.log 'notice', 'Cannot place skeleton as the desired structure already exists'
				return next()
			
			# Initialise Skeleton
			logger.log 'info', "About to initialise the skeleton [#{skeleton}] to [#{destinationPath}]"
			@initialiseSkeleton skeleton, destinationPath, (err) ->
				return next err


	# Server
	serverAction: (next) ->
		# Prepare
		logger = @logger
		express = require 'express'			unless express

		# Server
		if @server
			listen = false
		else
			listen = true
			@server = express.createServer()

		# Configuration
		@server.configure =>
			# Routing
			if @maxAge
				@server.use express.static @outPath, maxAge: @maxAge
			else
				@server.use express.static @outPath

		# Route something
		@server.get /^\/docpad/, (req,res) ->
			res.send 'DocPad!'
		
		# Start server listening
		if listen
			@server.listen @port
			logger.log 'info', 'Express server listening on port', @server.address().port, 'and directory', @outPath

		# Plugins
		@triggerEvent 'serverFinished', {@server}, (err) ->
			# Forward
			next err

# API
docpad =
	Docpad: Docpad
	createInstance: (config) ->
		return new Docpad(config)

# Export
module.exports = docpad
