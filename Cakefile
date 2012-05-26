fs     = require 'fs'
{exec} = require 'child_process'

appFiles  = [
  'application'
  'knots'
  'renderer'
  'shaders'
  'tube'
]

task 'build', 'Build single application file from source files', ->
  appname = 'knotgl'
  appContents = new Array remaining = appFiles.length
  for file, index in appFiles then do (file, index) ->
    fs.readFile "#{file}.coffee", 'utf8', (err, fileContents) ->
      throw err if err
      appContents[index] = fileContents
      process() if --remaining is 0
  process = ->
    fs.writeFile 'knotgl.coffee', appContents.join('\n\n'), 'utf8', (err) ->
      throw err if err
      exec 'coffee --output js --compile knotgl.coffee', (err, stdout, stderr) ->
        throw err if err
        console.log stdout + stderr
        fs.unlink 'knotgl.coffee', (err) ->
          throw err if err
        console.log 'Amalgam generated.  Minifying...'
        invoke 'minify'

# Uses Google Closure
task 'minify', 'Minify the resulting application file after build', ->
  exec '/usr/lib/jvm/java/bin/java -jar "./compiler.jar" --js js/knotgl.js --js_output_file js/knotgl-min.js', (err, stdout, stderr) ->
#  exec 'java -jar "./compiler.jar" --js js/knotgl.js --js_output_file js/knotgl-min.js', (err, stdout, stderr) ->
    throw err if err
    console.log stdout + stderr
    console.log 'Done.'

task 'watch', 'Watch prod source files and build changes', ->
  console.log "Watching for changes"

  for file in appFiles then do (file) ->
    fs.watch "#{file}.coffee", (curr, prev) ->
      if +curr.mtime isnt +prev.mtime
        console.log "Saw change in #{file}.coffee"
        invoke 'build'
