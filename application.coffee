root = exports ? this

DevTips =
  """
  In Chrome, use Ctrl+Shift+J to see console, Alt+Cmd+J on a Mac.
  To experiment with coffescript, try this from the console:
  > coffee --require './js/gl-matrix-min.js'
  """

clone = (obj) ->
  if not obj? or typeof obj isnt 'object'
    return obj
  newInstance = new obj.constructor()
  for key of obj
    newInstance[key] = clone obj[key]
  return newInstance

root.AppInit = ->
  c = $("canvas").get(0)
  gl = c.getContext("experimental-webgl", { antialias: true } )
  glerr("Your browser does not support floating-point textures.") unless gl.getExtension("OES_texture_float")
  glerr("Your browser does not support GLSL derivatives.") unless gl.getExtension("OES_standard_derivatives")
  width = parseInt($("#overlay").css('width'))
  height = parseInt($("#overlay").css('height'))
  root.renderer = new root.Renderer gl, width, height

CollapsedSizes =
  crossings: 2
  numComponents: 1
  index: 1

ExpandedSizes =
  crossings: 100
  numComponents: 50
  index: 50

root.Numerals =
  size: clone(ExpandedSizes)
  text: {}
  dirty: {}

root.UpdateNumeralSizes = ->
  $("#crossings").css('font-size', root.Numerals.size.crossings)
  $("#superscript").css('font-size', root.Numerals.size.numComponents)
  $("#subscript").css('font-size', root.Numerals.size.index)

root.UpdateNumerals = ->
  UpdateNumeralSizes()
  $("#crossings").text(root.Numerals.text.crossings)
  $("#subscript").text(root.Numerals.text.index)
  $("#superscript").text(root.Numerals.text.numComponents)

root.OnKeyDown = (keyname) ->

  # First ask the renderer to respond
  root.renderer.changeSelection(-1) if keyname is 'left'
  root.renderer.changeSelection(+1) if keyname is 'right'

  # Next figure out the text content of the three labels
  [crossings, numComponents, index] = root.renderer.getCurrentLink().split('.')
  numComponents = "" if numComponents == 1

  # TODO loop over keys instead of this repititive stuff
  root.Numerals.dirty.crossings = root.Numerals.text.crossings isnt crossings
  root.Numerals.dirty.numComponents = root.Numerals.text.numComponents isnt numComponents
  root.Numerals.dirty.index = root.Numerals.text.index isnt index
  root.Numerals.text.crossings = crossings
  root.Numerals.text.numComponents = numComponents
  root.Numerals.text.index = index

  # Now configure the tweening animation as two steps (collapse and expand)
  duration = 0.25 * root.renderer.transitionMilliseconds
  A = new TWEEN.Tween(root.Numerals.size)
    .to(CollapsedSizes, duration)
    .easing(TWEEN.Easing.Quintic.In)
    .onUpdate(root.UpdateNumeralSizes);
  B = new TWEEN.Tween(root.Numerals.size)
    .to(ExpandedSizes, duration)
    .easing(TWEEN.Easing.Quintic.In)
    .onUpdate(root.UpdateNumerals);
  A.chain(B)
  A.start()
