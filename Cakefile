fs     = require 'fs'
{exec} = require 'child_process'

coffeeFiles = [
  'utility'
  'application'
  'gallery'
  'metadata/knots'
  'display'
  'shaders'
  'tube'
  'worker-core'
]

bareFiles = [
  'utility'
  'shaders'
  'metadata/knots'
]

workerArtifacts = [
  'js/gl-matrix.js'
  'js/tube.js'
  'js/worker-core.js'
]

minifyFiles = [
  'gl-matrix'
  'Tween'
  'RequestAnimationFrame'
  'utility'
  'knots'
  'gallery'
  'application'
  'display'
  'shaders'
  'worker'
]

graceful = false
linux = false

task 'worker', 'Build worker.js by combining a set of js files', ->
  appContents = new Array remaining = workerArtifacts.length
  for file, index in workerArtifacts then do (file, index) ->
    fs.readFile file, 'utf8', (err, fileContents) ->
      throw err if err and not graceful
      appContents[index] = fileContents
      process() if --remaining is 0
  process = ->
    fs.writeFile 'js/worker.js', appContents.join('\n\n'), 'utf8', (err) ->
      throw err if err

task 'build', 'Compile CoffeeScript from *.coffee to js/*.js', ->
  for file in coffeeFiles
    flags = if bareFiles.indexOf(file) isnt -1 then '--bare ' else ''
    exec "coffee --compile #{flags} --output js/ #{file}.coffee", (err, stdout, stderr) ->
      console.log stdout + stderr
  invoke 'worker'

task 'minify', 'Minify an assortment of js files using Google Closure', ->
  e = if linux then '/usr/lib/jvm/java/bin/java' else 'java'
  console.log 'Minifying...'
  for file in minifyFiles
    exec "#{e} -jar \"./compiler.jar\" --js js/#{file}.js --js_output_file js/#{file}.min.js", (err, stdout, stderr) ->
      throw err if err and not graceful
      console.log stdout + stderr

task 'watch', 'Watch prod source files and build changes', ->
  console.log "Watching for changes"
  for file in coffeeFiles then do (file) ->
    watch = if linux then fs.watch else fs.watchFile
    watch "#{file}.coffee", (curr, prev) ->
      if +curr.mtime isnt +prev.mtime
        console.log "Saw change in #{file}.coffee"
        graceful = false
        invoke 'build'
        graceful = true

task 'tips', 'Print some development tips', ->
  tips =
    """
    To experiment with coffescript REPL, try this from the console:
    > coffee --require './js/gl-matrix.js'
    Press Ctrl+V to enter multi-line mode, Ctrl+D to exit.
    """
  console.info tips
