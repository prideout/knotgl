root = exports ? this

clone = utility.clone

root.Gallery = class Gallery
  row: ->
    row = @j if not row?
    @links[@j]
  link: (row,col) ->
    row = @j if not row?
    col = @i if not col?
    @links[row][col]
  constructor: ->
    @links = []
    for row in [0...12]
        @links[row] = []
        @links[row].theta = 0
        @links[row].loaded = false
        @links[row].loading = false
        continue if not metadata.Gallery[row]
        for id, col in metadata.Gallery[row].split(' ')
          link = []
          ranges = (x[1..] for x in metadata.Links when x[0] is id)[0]
          for range, c in ranges
            knot = {}
            knot.range = range
            knot.offset = vec3.create([0,0,0])
            knot.color = metadata.KnotColors[c]
            link.push(knot)
          link.iconified = 1
          link.alpha = 1
          link.ready = false
          link.id = [id, row, col]
          @links[row].push(link)
    @createTrivialLinks()
    [@j, @i] = [9, 0]
    @link().iconified = 0
  createTrivialLinks: ->
    trivialKnot = @link(8,1)[0]
    trivialLink = @link(0,0) # 0.1.1
    trivialLink.push(clone trivialKnot)
    trivialLink[0].offset = vec3.create([0.5,-0.25,0])
    trivialLink.hidden = true
    trivialLink = @link(8,0) # 0.2.1
    trivialLink.push(clone trivialKnot)
    trivialLink.push(clone trivialKnot)
    trivialLink[0].offset = vec3.create([0,0,0])
    trivialLink[1].color = metadata.KnotColors[1]
    trivialLink[1].offset = vec3.create([0.5,0,0])
    trivialLink = @link(10,8) # 0.3.1
    trivialLink.push(clone trivialKnot)
    trivialLink.push(clone trivialKnot)
    trivialLink.push(clone trivialKnot)
    trivialLink[0].offset = vec3.create([0,0,0])
    trivialLink[1].color = metadata.KnotColors[1]
    trivialLink[1].offset = vec3.create([0.5,0,0])
    trivialLink[2].color = metadata.KnotColors[2]
    trivialLink[2].offset = vec3.create([1.0,0,0])
