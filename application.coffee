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

root.MouseClick = ->
  renderer.click()

root.UpdateLabels = UpdateLabels = ->
  labels = root.renderer.getCurrentLink()
  $("#crossings").text(labels.crossings)
  $("#subscript").text(labels.index)
  $("#superscript").text(labels.numComponents)

root.OnKeyDown = (keyname) ->
  switch keyname
    when 'left'  then root.renderer.moveSelection(-1)
    when 'right' then root.renderer.moveSelection(+1)

root.AnimateNumerals = ->
  root.collapse.stop() if root.collapse?
  root.expand.stop() if root.expand?
  duration = 0.25 * root.renderer.transitionMilliseconds
  root.collapse = A = new TWEEN.Tween(CurrentSizes)
    .to(CollapsedSizes, duration)
    .easing(TWEEN.Easing.Quintic.In)
    .onUpdate(UpdateNumeralSizes)
  root.expand = B = new TWEEN.Tween(CurrentSizes)
    .to(ExpandedSizes, duration)
    .easing(TWEEN.Easing.Quintic.In)
    .onUpdate(UpdateNumeralSizes)
  A.chain(B)

  # Turns off the continuous label update until after the collapse
  root.UpdateLabels = null
  root.collapse.onComplete ->
    root.UpdateLabels = UpdateLabels

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

CurrentSizes = clone ExpandedSizes

UpdateNumeralSizes = ->
  $("#crossings").css('font-size', CurrentSizes.crossings)
  $("#superscript").css('font-size', CurrentSizes.numComponents)
  $("#subscript").css('font-size', CurrentSizes.index)
