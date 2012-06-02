fs     = require 'fs'
{exec} = require 'child_process'

tips =
  """
  To experiment with coffescript REPL, try this from the console:
  > coffee --require './js/gl-matrix-min.js'
  Press Ctrl+V to enter multi-line mode, Ctrl+D to exit.
  """

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

graceful = false
linux = true

task 'worker', 'Build a monolithic worker from a collection of js and coffee files', ->
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

task 'minify', 'Minify the resulting application file after build using Google Closure', ->
  e = if linux then '/usr/lib/jvm/java/bin/java' else 'java'
  console.log 'Minifying...'
  exec "#{e} -jar \"./compiler.jar\" --js js/knotgl.js --js_output_file js/knotgl-min.js", (err, stdout, stderr) ->
    throw err if err and not graceful
    console.log stdout + stderr
    console.log 'Done.'

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
