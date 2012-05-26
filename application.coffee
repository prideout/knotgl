root = exports ? this

DevTips =
  """
  In Chrome, use Ctrl+Shift+J to see console, Alt+Cmd+J on a Mac.
  To experiment with coffescript, try this from the console:
  > coffee --require './js/gl-matrix-min.js'
  """

root.AppInit = ->
  c = $("canvas").get(0)
  gl = c.getContext("experimental-webgl", { antialias: true } )
  glerr("Your browser does not support floating-point textures.") unless gl.getExtension("OES_texture_float")
  glerr("Your browser does not support GLSL derivatives.") unless gl.getExtension("OES_standard_derivatives")
  width = parseInt($("#overlay").css('width'))
  height = parseInt($("#overlay").css('height'))
  root.renderer = new root.Renderer gl, width, height

root.NumeralSizes =
  crossings: 100
  superscript: 50
  subscript: 50

root.UpdateNumeralSizes = ->
  $("#crossings").css('font-size', root.NumeralSizes.crossings)
  $("#superscript").css('font-size', root.NumeralSizes.superscript)
  $("#subscript").css('font-size', root.NumeralSizes.subscript)

root.UpdateNumerals = ->
  UpdateNumeralSizes()
  linkName = root.renderer.getCurrentLink()
  $("#crossings").text(linkName)

root.OnKeyDown = (keyname) ->

  root.renderer.changeSelection(-1) if keyname is 'left'
  root.renderer.changeSelection(+1) if keyname is 'right'
     
  duration = 0.25 * root.renderer.transitionMilliseconds

  A =
    crossings: 2
    superscript: 1
    subscript: 1

  B =
    crossings: 100
    superscript: 50
    subscript: 50

  A = new TWEEN.Tween(root.NumeralSizes)
    .to(A, duration)
    .easing(TWEEN.Easing.Quintic.In)
    .onUpdate(root.UpdateNumeralSizes);

  B = new TWEEN.Tween(root.NumeralSizes)
    .to(B, duration)
    .easing(TWEEN.Easing.Quintic.In)
    .onUpdate(root.UpdateNumerals);

  A.chain(B)
  A.start()
