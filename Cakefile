fs     = require 'fs'
{exec} = require 'child_process'

DevTips =
  """
  To experiment with coffescript, try this from the console:
  > coffee --require './js/gl-matrix-min.js'
  """

watchedFiles  = [
  'utility'
  'application'
  'knots'
  'renderer'
  'shaders'
  'tube'
]

graceful = false
linux = true
appname = 'knotgl'

workerCoffee = [
  'tube'
  'worker-core'
]

workerArtifacts = [
  'js/gl-matrix.js'
  'js/tube.js'
  'js/worker-core.js'
]

task 'worker', 'Build a monolithic worker from a collection of javascript and coffeescript files.', ->
  for file in workerCoffee
    console.info "coffee --bare --compile --output js #{file}.coffee"
    exec "coffee --bare --compile --output js #{file}.coffee", (err, stdout, stderr) ->
      console.log stdout + stderr
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
  exec 'coffee --compile --output js/ ./', (err, stdout, stderr) ->
    console.log stdout + stderr

task 'minify', 'Minify the resulting application file after build using Google Closure.', ->
  e = if linux then '/usr/lib/jvm/java/bin/java' else 'java'
  console.log 'Minifying...'
  exec "#{e} -jar \"./compiler.jar\" --js js/knotgl.js --js_output_file js/knotgl-min.js", (err, stdout, stderr) ->
    throw err if err and not graceful
    console.log stdout + stderr
    console.log 'Done.'

task 'watch', 'Watch prod source files and build changes', ->
  console.log "Watching for changes"
  for file in watchedFiles then do (file) ->
    watch = if linux then fs.watch else fs.watchFile
    watch "#{file}.coffee", (curr, prev) ->
      if +curr.mtime isnt +prev.mtime
        console.log "Saw change in #{file}.coffee"
        graceful = false
        invoke 'build'
        graceful = true
