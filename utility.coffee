root = exports ? this
root.utility = {}
utility = root.utility

# Deep copy (why doesn't JS have this natively?)
utility.clone = (obj) ->
  if not obj? or typeof obj isnt 'object'
    return obj
  newInstance = new obj.constructor()
  for key of obj
    newInstance[key] = clone obj[key]
  return newInstance

# Axis-aligned bounding box.
# Just like CSS, Y increases downwards.
# Left-top boundary is inclusive, right-bottom is exclusive.
utility.aabb = class aabb

  constructor: (@left, @top, @right, @bottom) ->

  @createFromCorner: (leftTop, size) ->
    [left, top] = leftTop
    [right, bottom] = [left + size[0], top + size[1]]
    new aabb left, top, right, bottom

  @createFromCenter: (center, size) ->
    [hw, hh] = [size[0]/2, size[1]/2]
    [left, top] = [center[0] - hw, center[1] - hh]
    [right, bottom] = [center[0] + hw, center[1] + hh]
    new aabb left, top, right, bottom

  setFromCenter: (center, size) ->
    [hw, hh] = [size[0]/2, size[1]/2]
    [@left, @top] = [center[0] - hw, center[1] - hh]
    [@right, @bottom] = [center[0] + hw, center[1] + hh]

  contains: (x,y) -> x >= @left and x < @right and y >= @top and y < @bottom
  width: -> @right - @left
  height: -> @bottom - @top
  centerx: -> (@left + @right) / 2
  centery: -> (@bottom + @top) / 2
  size: -> [@width(), @height()]
  viewport: (gl) -> gl.viewport @left, @top, @width(), @height()
  translated: (x,y) -> new aabb @left+x,@top+y,@right+x,@bottom+y

  @intersect: (a, b) -> new aabb(
    Math.max(a.left,b.left),
    Math.max(a.top,b.top),
    Math.min(a.right,b.right),
    Math.min(a.bottom,b.bottom))

  degenerate: -> @left >= @right or @top >= @bottom

  inflate: (delta) ->
    @left -= delta
    @top -= delta
    @right += delta
    @bottom += delta

  deflate: (delta) ->
    @left += delta
    @top += delta
    @right -= delta
    @bottom -= delta

  @lerp: (a, b, t) ->
    w = (1-t) * a.width()  + t * b.width()
    h = (1-t) * a.height() + t * b.height()
    x = (1-t) * a.centerx() + t * b.centerx()
    y = (1-t) * a.centery() + t * b.centery()
    aabb.createFromCenter [x,y], [w,h]
