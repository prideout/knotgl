root = exports ? this

# When the document is loaded, construct a Display object etc.
$ ->
  c = $('canvas').get 0
  gl = c.getContext 'experimental-webgl', { antialias: true }
  glerr('Your browser does not support floating-point textures.') unless gl.getExtension('OES_texture_float')
  glerr('Your browser does not support GLSL derivatives.') unless gl.getExtension('OES_standard_derivatives')
  width = parseInt $('#overlay').css('width')
  height = parseInt $('#overlay').css('height')
  root.display = new root.Display(gl, width, height)
  layout()
  assignEventHandlers()
  window.requestAnimationFrame tick, c

root.AnimateNumerals = ->
  return if collapsing or expanding
  duration = 0.25 * root.display.transitionMilliseconds
  collapse = new TWEEN.Tween(root.numeralSizes)
    .to(metadata.CollapsedSizes, duration)
    .easing(TWEEN.Easing.Quintic.In)
    .onUpdate(updateNumeralSizes)
    .onComplete(-> collapsing = false)
  expand = new TWEEN.Tween(root.numeralSizes)
    .to(metadata.ExpandedSizes, duration)
    .easing(TWEEN.Easing.Quintic.In)
    .onUpdate(updateNumeralSizes)
    .onComplete(-> expanding = false)
  collapsing = expanding = true
  collapse.chain expand
  collapse.start()

# Update the universe at the browser's discretion.
tick = ->
  window.requestAnimationFrame(tick, $("canvas").get 0)
  TWEEN.update()

  # Update the Alexander-Briggs labels unless they're collapse-animating.
  if not collapsing
    labels = root.display.getCurrentLinkInfo()
    $('#crossings').text labels.crossings
    $('#subscript').text labels.index
    $('#superscript').text labels.numComponents

  # If we're on the gallery page, update the mouse-over row.
  if root.pageIndex is 0
    numRows = root.display.gallery.links.length
    if root.mouse.moved
      h = root.display.height / numRows
      highlightRow = Math.floor(root.mouse.position.y / h)
      highlightRow = null if highlightRow >= numRows
      highlightRow = -1 if $('#grasshopper').is ':hover'
      root.display.highlightRow = highlightRow
    $('#highlight-row').css('visibility', 'visible')
    top = root.display.highlightRow * root.display.height / numRows
    $('#highlight-row').css('top', top)

  # The HTML/CSS layer can mark the mouse as hot (window.mouse.hot),
  # or the coffeescript logic can make it hot (this.hotMouse).
  cursor = if root.display.hotMouse or root.mouse.hot or root.pageIndex is 0 then 'pointer' else ''
  $('#rightpage').css {'cursor' : cursor}
  $('#leftpage').css {'cursor' : cursor}

  # Ask the root.display to render (it makes WebGL calls)
  root.display.render() if root.display.ready

  # Lastly, reset the mouse-moved flag so we'll know if an event occured.
  root.mouse.moved = false

assignEventHandlers = ->
  $(window).resize -> layout()
  $(document).keydown (e) ->
    root.display.moveSelection(0,-1) if e.keyCode is 38 # up
    root.display.moveSelection(0,+1) if e.keyCode is 40 # down
    root.display.moveSelection(-1,0) if e.keyCode is 37 # left
    root.display.moveSelection(+1,0) if e.keyCode is 39 # right
    swipePane() if e.keyCode is 32 # space
    exportScreenshot() if e.keyCode is 83 # s
  $('.arrow').mouseover ->
    $(this).css('color', '#385fa2')
    root.mouse.hot = true
  $('.arrow').mouseout ->
    $(this).css({'color' : ''})
    root.mouse.hot = false
  $('.arrow').click -> swipePane()
  $('#grasshopper').click (e) -> e.stopPropagation()
  $('#wideband').mousemove (e) ->
    p = $(this).position()
    x = root.mouse.position.x = e.clientX - p.left
    y = root.mouse.position.y = e.clientY - p.top
    root.mouse.within = 1
    root.mouse.moved = true
  $('#wideband').click (e) ->
    p = $(this).position()
    x = root.mouse.position.x = e.clientX - p.left
    y = root.mouse.position.y = e.clientY - p.top
    root.mouse.within = 1
    root.display.click()
    if root.pageIndex is 0 and not root.swipeTween?
      return if not root.display.highlightRow?
      root.display.changeSelection(
        root.display.gallery.i
        root.display.highlightRow)
      swipePane()
      return
  $('#wideband').mouseout ->
    root.mouse.position.x = -1
    root.mouse.position.y = -1
    root.mouse.within = false

exportScreenshot = ->
  c = $('canvas').get 0
  root.display.render()
  imgUrl = c.toDataURL("image/png")
  window.open(imgUrl, '_blank')
  window.focus()

updateNumeralSizes = ->
  $('#crossings').css('font-size', root.numeralSizes.crossings)
  $('#superscript').css('font-size', root.numeralSizes.numComponents)
  $('#subscript').css('font-size', root.numeralSizes.index)

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
  root.display.width = width
  root.display.height = height
  root.pan.x = getPagePosition(root.pageIndex)
  updateSwipeAnimation()

swipePane = ->
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

root.pageIndex = 1
root.pan = {x: 0}
root.mouse =
  position: {x: -1, y: -1}
  within: false
  hot: false
  moved: false
root.numeralSizes = utility.clone metadata.ExpandedSizes
collapsing = expanding = false
