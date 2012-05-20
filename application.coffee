root = exports ? this

DevTips =
  """
  In Chrome, use Ctrl+Shift+J to see console, Alt+Cmd+J on a Mac.
  To experiment with coffescript, try this from the console:
  > coffee --require './js/gl-matrix-min.js'
  """

root.AppInit = ->
  canvas = $("canvas")
  width = parseInt(canvas.css('width'))
  height = parseInt(canvas.css('height'))
  canvas.css('margin-left', -width/2)
  canvas.css('margin-top', -height/2)
  canvas.width = canvas.clientWidth
  canvas.height = canvas.clientHeight
  gl = canvas.get(0).getContext("experimental-webgl", { antialias: true } )
  glerr("Your browser does not support floating-point textures.") unless gl.getExtension("OES_texture_float")
  glerr("Your browser does not support GLSL derivatives.") unless gl.getExtension("OES_standard_derivatives")
  root.renderer = new root.Renderer gl, width, height

root.OnKeyDown = (keyname) ->
  root.renderer.changeSelection(-1) if keyname is 'left'
  root.renderer.changeSelection(+1) if keyname is 'right'