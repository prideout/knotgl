root = exports ? this

DevTips =
  """
  In Chrome, use Ctrl+Shift+J to see console, Alt+Cmd+J on a Mac.
  To experiment with coffescript, try this from the console:
  > coffee --require './js/gl-matrix-min.js'
  """

root.AppInit = ->

  window.onresize = ->
    width = parseInt($("#overlay").css('width'))
    height = parseInt($("#overlay").css('height'))
    $("canvas").css('margin-top', -height/2)
    $("#overlay").css('margin-top', -height/2)
    c = $("canvas").get(0)
    c.clientWidth = width
    c.width = c.clientWidth
    c.clientHeight = height
    c.height = c.clientHeight
    if root.renderer?
      root.renderer.width = width
      root.renderer.height = height

  c = $("canvas").get(0)
  gl = c.getContext("experimental-webgl", { antialias: true } )
  glerr("Your browser does not support floating-point textures.") unless gl.getExtension("OES_texture_float")
  glerr("Your browser does not support GLSL derivatives.") unless gl.getExtension("OES_standard_derivatives")

  width = parseInt($("#overlay").css('width'))
  height = parseInt($("#overlay").css('height'))
  root.renderer = new root.Renderer gl, width, height

  window.onresize()

root.OnKeyDown = (keyname) ->
  root.renderer.changeSelection(-1) if keyname is 'left'
  root.renderer.changeSelection(+1) if keyname is 'right'
