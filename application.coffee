root = exports ? this
clone = root.utility.clone
box = root.utility.box

CollapsedSizes =
  crossings: 10
  numComponents: 5
  index: 5

ExpandedSizes =
  crossings: 100
  numComponents: 50
  index: 50

root.AppInit = ->
  root.CurrentSizes = clone ExpandedSizes
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
  return if root.collapse? or root.expand?
  duration = 0.25 * root.renderer.transitionMilliseconds
  root.collapse = A = new TWEEN.Tween(root.CurrentSizes)
    .to(CollapsedSizes, duration)
    .easing(TWEEN.Easing.Quintic.In)
    .onUpdate(UpdateNumeralSizes)
  root.expand = B = new TWEEN.Tween(root.CurrentSizes)
    .to(ExpandedSizes, duration)
    .easing(TWEEN.Easing.Quintic.In)
    .onUpdate(UpdateNumeralSizes)
  A.chain(B)

  # Turns off the continuous label update until after the collapse
  root.UpdateLabels = null
  root.collapse.onComplete ->
    root.UpdateLabels = UpdateLabels
    root.collapse = null
  root.expand.onComplete ->
    root.expand = null

  A.start()

UpdateNumeralSizes = ->
  $("#crossings").css('font-size', root.CurrentSizes.crossings)
  $("#superscript").css('font-size', root.CurrentSizes.numComponents)
  $("#subscript").css('font-size', root.CurrentSizes.index)
