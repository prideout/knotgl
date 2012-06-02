root = exports ? this

root.pageIndex = 1
root.pan = {x: 0}
root.mouse =
  position: {x: -1, y: -1}
  within: false
  hot: false

CurrentSizes = utility.clone metadata.ExpandedSizes
collapsing = expanding = false

$ ->
  c = $('canvas').get 0
  gl = c.getContext('experimental-webgl', { antialias: true } )
  glerr('Your browser does not support floating-point textures.') unless gl.getExtension('OES_texture_float')
  glerr('Your browser does not support GLSL derivatives.') unless gl.getExtension('OES_standard_derivatives')
  width = parseInt($('#overlay').css('width'))
  height = parseInt($('#overlay').css('height'))
  root.renderer = new root.Renderer gl, width, height
  layout()
  assignEventHandlers()
  window.requestAnimationFrame(tick, c)

root.AnimateNumerals = ->
  return if collapsing or expanding
  duration = 0.25 * root.renderer.transitionMilliseconds
  collapse = new TWEEN.Tween(CurrentSizes)
    .to(metadata.CollapsedSizes, duration)
    .easing(TWEEN.Easing.Quintic.In)
    .onUpdate(updateNumeralSizes)
    .onComplete(-> collapsing = false)
  expand = new TWEEN.Tween(CurrentSizes)
    .to(metadata.ExpandedSizes, duration)
    .easing(TWEEN.Easing.Quintic.In)
    .onUpdate(updateNumeralSizes)
    .onComplete(-> expanding = false)
  collapsing = expanding = true
  collapse.chain expand
  collapse.start()

root.SwipePane = ->
  return if root.swipeTween?
  root.pageIndex = 1 - root.pageIndex
  panTarget = getPagePosition(root.pageIndex)
  swipeDuration = 1000
  root.swipeTween = new TWEEN.Tween(root.pan)
      .to({x: panTarget}, swipeDuration)
      .easing(TWEEN.Easing.Bounce.Out)
      .onUpdate(updateSwipeAnimation)
      .onComplete(-> root.swipeTween = null)
  root.swipeTween.start()

tick = ->

  r = root.renderer

  # Request the next tick cycle on vertical refresh (vsync).
  window.requestAnimationFrame(tick, $("canvas").get 0)

  # Update all the tweening workers for snazzy animations and whatnot.
  TWEEN.update()

  # Update the Alexander-Briggs labels unless they're collapse-animating.
  if not collapsing
    labels = r.getCurrentLinkInfo()
    $('#crossings').text labels.crossings
    $('#subscript').text labels.index
    $('#superscript').text labels.numComponents

  # If we're on the gallery page, update the mouse-over row.
  if root.pageIndex is 0
    h = r.height / r.links.length
    highlightRow = Math.floor(root.mouse.position.y / h)
    highlightRow = null if highlightRow >= r.links.length
    highlightRow = -1 if $('#grasshopper').is ':hover'
    $('#highlight-row').css('visibility', 'visible')
    top = highlightRow * r.height / r.links.length
    $('#highlight-row').css('top', top)
  else
    highlightRow = r.selectedRow
  r.highlightRow = highlightRow

  # The HTML/CSS layer can mark the mouse as hot (window.mouse.hot),
  # or the coffeescript logic can make it hot (this.hotMouse).
  cursor = if root.renderer.hotMouse or root.mouse.hot or root.pageIndex is 0 then 'pointer' else ''
  $('#rightpage').css {'cursor' : cursor}
  $('#leftpage').css {'cursor' : cursor}

  # Lastly, ask the renderer to do its magic.
  r.render() if r.ready

assignEventHandlers = ->

  $(window).resize -> layout()

  $(document).keydown (e) ->
    root.renderer.moveSelection(0,-1) if e.keyCode is 38 # up
    root.renderer.moveSelection(0,+1) if e.keyCode is 40 # down
    root.renderer.moveSelection(-1,0) if e.keyCode is 37 # left
    root.renderer.moveSelection(+1,0) if e.keyCode is 39 # right
    root.SwipePane() if e.keyCode is 32 # space
    exportScreenshot() if e.keyCode is 83 # s

  $('.arrow').mouseover ->
    $(this).css('color', '#385fa2')
    root.mouse.hot = true

  $('.arrow').mouseout ->
    $(this).css({'color' : ''})
    root.mouse.hot = false

  $('.arrow').click -> root.SwipePane()

  $('#grasshopper').click (e) -> e.stopPropagation()

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
    root.mouse.within = false

exportScreenshot = ->
  c = $('canvas').get 0
  root.renderer.render()
  imgUrl = c.toDataURL("image/png")
  window.open(imgUrl, '_blank')
  window.focus()

updateNumeralSizes = ->
  $('#crossings').css('font-size', CurrentSizes.crossings)
  $('#superscript').css('font-size', CurrentSizes.numComponents)
  $('#subscript').css('font-size', CurrentSizes.index)

getPagePosition = (pageIndex) ->
  pageWidth = parseInt($('#canvaspage').css('width'))
  if pageIndex is 1 then 0 else pageWidth

updateSwipeAnimation = ->
  w = parseInt($('#canvaspage').css('width'))
  h = parseInt($('#canvaspage').css('height'))
  $('#leftpage').css('left', -w + root.pan.x)
  $('#leftpage').css('width', w)
  $('#rightpage').css('left', 0 + root.pan.x)
  $('#rightpage').css('width', w)

layout = ->
  height = parseInt($('#wideband').css('height'))
  width = height*768/1024
  $('#wideband').css 'width', width
  bodyWidth = parseInt($('body').css('width'))
  $('#wideband').css 'left', bodyWidth / 2 - width / 2
  width = parseInt($('#canvaspage').css('width'))
  root.swipeTween.stop() if root.swipeTween?
  height = parseInt($('#canvaspage').css('height'))
  c = $('canvas').get 0
  c.clientWidth = width
  c.width = c.clientWidth
  c.clientHeight = height
  c.height = c.clientHeight
  this.renderer.width = width
  this.renderer.height = height
  root.pan.x = getPagePosition(root.pageIndex)
  updateSwipeAnimation()

