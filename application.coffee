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

CurrentSizes = clone ExpandedSizes

root.pan = {x: 0}
root.mouse =
  position: {x: -1, y: -1}
  within: false
  hot: false

layout = ->
  height = parseInt($('#wideband').css('height'))
  width = height*768/1024
  $('#wideband').css 'width', width
  bodyWidth = parseInt($('body').css('width'))
  $('#wideband').css 'left', bodyWidth / 2 - width / 2
  width = window.pan.width = parseInt($('#canvaspage').css('width'))
  height = parseInt($('#canvaspage').css('height'))
  c = $('canvas').get 0
  c.clientWidth = width
  c.width = c.clientWidth
  c.clientHeight = height
  c.height = c.clientHeight
  this.renderer.width = width
  this.renderer.height = height
  updateTween()

root.AppInit = ->
  c = $("canvas").get(0)
  gl = c.getContext("experimental-webgl", { antialias: true } )
  glerr("Your browser does not support floating-point textures.") unless gl.getExtension("OES_texture_float")
  glerr("Your browser does not support GLSL derivatives.") unless gl.getExtension("OES_standard_derivatives")
  width = parseInt($("#overlay").css('width'))
  height = parseInt($("#overlay").css('height'))
  root.renderer = new root.Renderer gl, width, height
  layout()

  $(window).resize -> layout()

  $(document).keydown (e) ->
    root.OnKeyDown('left') if e.keyCode is 37
    root.OnKeyDown('right') if e.keyCode is 39
    if e.keyCode is 32
      showingRight = root.pan.x is 0
      swipeDirection = if showingRight then -1 else +1
      swipePane(swipeDirection)

root.MouseClick = ->
  renderer.click()

root.UpdateLabels = UpdateLabels = ->
  labels = root.renderer.getCurrentLinkInfo()
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
    root.collapse = null
  root.expand.onComplete ->
    root.expand = null

  A.start()

UpdateNumeralSizes = ->
  $("#crossings").css('font-size', CurrentSizes.crossings)
  $("#superscript").css('font-size', CurrentSizes.numComponents)
  $("#subscript").css('font-size', CurrentSizes.index)
