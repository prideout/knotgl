root = exports ? this
clone = root.utility.clone
box = root.utility.box

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

root.UpdateLabels = ->
  InitializeNumerals()
  UpdateNumeralText()

root.OnKeyDown = (keyname) ->
  dirty = false
  if keyname is 'left'
    dirty = root.renderer.changeSelection(-1)
  if keyname is 'right'
    dirty = root.renderer.changeSelection(+1)
  InitializeNumerals()
  return if not dirty
  duration = 0.25 * root.renderer.transitionMilliseconds
  A = new TWEEN.Tween(Numerals.size)
    .to(CollapsedSizes, duration)
    .easing(TWEEN.Easing.Quintic.In)
    .onUpdate(UpdateNumeralSizes);
  B = new TWEEN.Tween(Numerals.size)
    .to(ExpandedSizes, duration)
    .easing(TWEEN.Easing.Quintic.In)
    .onUpdate(UpdateNumerals);
  A.chain(B)
  A.start()

## PRIVATE ##

CollapsedSizes =
  crossings: 10
  numComponents: 5
  index: 5

ExpandedSizes =
  crossings: 100
  numComponents: 50
  index: 50

Numerals =
  size: clone ExpandedSizes
  text: {}
  dirty: {}

InitializeNumerals = ->
  labels = root.renderer.getCurrentLink()
  for key of labels
    Numerals.dirty[key] = Numerals.text[key] isnt labels[key]
    Numerals.text[key] = labels[key]

UpdateNumeralSizes = ->
  $("#crossings").css('font-size', Numerals.size.crossings)
  $("#superscript").css('font-size', Numerals.size.numComponents)
  $("#subscript").css('font-size', Numerals.size.index)

UpdateNumerals = ->
  UpdateNumeralSizes()
  UpdateNumeralText()

UpdateNumeralText = ->
  $("#crossings").text(Numerals.text.crossings)
  $("#subscript").text(Numerals.text.index)
  $("#superscript").text(Numerals.text.numComponents)
