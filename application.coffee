root = exports ? this

root.pan = {x: 0}

root.mouse =
  position: {x: -1, y: -1}
  within: false
  hot: false

root.AppInit = ->
  c = $('canvas').get(0)
  gl = c.getContext('experimental-webgl', { antialias: true } )
  glerr('Your browser does not support floating-point textures.') unless gl.getExtension('OES_texture_float')
  glerr('Your browser does not support GLSL derivatives.') unless gl.getExtension('OES_standard_derivatives')
  width = parseInt($('#overlay').css('width'))
  height = parseInt($('#overlay').css('height'))
  root.renderer = new root.Renderer gl, width, height
  layout()
  assignEventHandlers()

root.UpdateLabels = UpdateLabels = ->
  labels = root.renderer.getCurrentLinkInfo()
  $('#crossings').text(labels.crossings)
  $('#subscript').text(labels.index)
  $('#superscript').text(labels.numComponents)

root.AnimateNumerals = ->
  return if root.collapse? or root.expand?
  duration = 0.25 * root.renderer.transitionMilliseconds
  root.collapse = A = new TWEEN.Tween(CurrentSizes)
    .to(CollapsedSizes, duration)
    .easing(TWEEN.Easing.Quintic.In)
    .onUpdate(updateNumeralSizes)
  root.expand = B = new TWEEN.Tween(CurrentSizes)
    .to(ExpandedSizes, duration)
    .easing(TWEEN.Easing.Quintic.In)
    .onUpdate(updateNumeralSizes)
  A.chain(B)

  # Turns off the continuous label update until after the collapse
  root.UpdateLabels = null
  root.collapse.onComplete ->
    root.UpdateLabels = UpdateLabels
    root.collapse = null
  root.expand.onComplete ->
    root.expand = null

  A.start()

# PRIVATE UTILITIES #

assignEventHandlers = ->

  $(window).resize -> layout()

  $(document).keydown (e) ->
    root.renderer.moveSelection(-1) if e.keyCode is 37
    root.renderer.moveSelection(+1) if e.keyCode is 39
    if e.keyCode is 32
      showingRight = root.pan.x is 0
      swipeDirection = if showingRight then -1 else +1
      swipePane(swipeDirection)

  $('.arrow').mouseover ->
    $(this).css('color', '#385fa2')
    root.mouse.hot = 1

  $('.arrow').mouseout ->
    $(this).css({'color' : ''})
    root.mouse.hot = false

  $('.arrow').click ->
    isLeft = $(this).attr('id') is 'leftarrow'
    swipeDirection = if isLeft then -1 else +1
    swipePane(swipeDirection)

  $('#wideband').mousemove (e) ->
    p = $(this).position()
    x = root.mouse.position.x = e.clientX - p.left
    y = root.mouse.position.y = e.clientY - p.top
    root.mouse.within = 1

  $('#wideband').click (e) ->
    p = $(this).position()
    x = root.mouse.position.x = e.clientX - p.left
    y = root.mouse.position.y = e.clientY - p.top
    root.mouse.within = 1
    renderer.click()

  $('#wideband').mouseout ->
    root.mouse.position.x = -1
    root.mouse.position.y = -1
    root.mouse.within = false;

updateNumeralSizes = ->
  $('#crossings').css('font-size', CurrentSizes.crossings)
  $('#superscript').css('font-size', CurrentSizes.numComponents)
  $('#subscript').css('font-size', CurrentSizes.index)

swipePane = (direction) ->
  panTarget = if direction is -1 then root.pan.width else 0
  swipeDuration = 1000
  tween = new TWEEN.Tween(root.pan)
      .to({x: panTarget}, swipeDuration)
      .easing(TWEEN.Easing.Bounce.Out)
      .onUpdate(updateTween)
  tween.start()

updateTween = ->
  w = parseInt($('#canvaspage').css('width'))
  h = parseInt($('#canvaspage').css('height'))
  $('#leftpage').css('left', -w + root.pan.x)
  $('#leftpage').css('width', w - 40)
  $('#rightpage').css('left', 0 + root.pan.x)
  $('#rightpage').css('width', w - 40)

layout = ->
  height = parseInt($('#wideband').css('height'))
  width = height*768/1024
  $('#wideband').css 'width', width
  bodyWidth = parseInt($('body').css('width'))
  $('#wideband').css 'left', bodyWidth / 2 - width / 2
  width = root.pan.width = parseInt($('#canvaspage').css('width'))
  height = parseInt($('#canvaspage').css('height'))
  c = $('canvas').get 0
  c.clientWidth = width
  c.width = c.clientWidth
  c.clientHeight = height
  c.height = c.clientHeight
  this.renderer.width = width
  this.renderer.height = height
  updateTween()

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
