class window.Observations
  @live: (guy, value) ->
    goods = observations = null
    console.log 'live running'
    new Stream (s) ->
      s.listen 'value', fb('goods/%', value.id), (snap) ->
        goods = snap.val() || {}
        console.log 'got goods', goods
        s.emit new Observations(value, goods, observations) if observations
      s.listen 'value', fb('observations/%/%', guy, value.id), (snap) ->
        observations = snap.val() || {}
        console.log 'got observations', observations
        s.emit new Observations(value, goods, observations) if goods

  constructor: (@value, goods, observations) ->
    @relatives = {}
    @aliases = (if goods.aliases then Object.keys goods.aliases else [])
    delete goods.aliases
    for obj in [goods, observations]
      for rel, v of obj
        (@relatives[x] ||= {})[rel] = num for x, num of v

  # types of observations

  directObservations: ->
    item for item in Object.keys(@relatives) when @isDirectObservation(item)
  whyObservations: ->
    item for item in Object.keys(@relatives) when @isWhyObservation(item)
  howObservations: ->
    item for item in Object.keys(@relatives) when @isHowObservation(item)
  isDirectObservation: (x) ->
    it = @relatives[x]
    it.whatdrives? or it.quenches? or it.leadsto?
  isWhyObservation: (x) ->
    it = @relatives[x]
    it.whatrequires? or it.whatincludes? or it.whatdrives?
  isHowObservation: (x) ->
    it = @relatives[x]
    it.requires? or it.includes? or it.whatleadsto? or it.whatquenches?

  infixPhrase: (x) ->
    it = @relatives[x]
    switch
      when it.leadsto? && it.leadsto < 0.5
        return 'sucks for'
      when it.quenches
        return 'works for'
      when it.leadsto
        return 'led to'
      when it.whatdrives
        return 'trying for'
  whyPrefix: (x) ->
    it = @relatives[x]
    switch
      when it.whatrequires? then "it's required for"
      when it.quenches? then "it quenches"
      when it.leadsto? then "it leads to"
  howSuffix: (x) ->
    it = @relatives[x]
    switch
      when it.requires? then "is necessary"
      when it.quenches? then "works for you"
      when it.leadsto? then "leads to this"


  valence: (x) ->
    it = @relatives[x]
    switch
      when it.leadsto? && it.leadsto < 0.5
        return 'negative'
      when it.quenches or it.leadsto
        return 'positive'
      else
        return 'neutral'

  remove: (x) ->
    rel = ['quenches', 'leadsto', 'whatdrives'].filter((rel) -> @relatives[x][rel])[0]
    current_user.unobserves x, rel, @value

  @suffixPhrase: (rel, val) ->
    switch rel
      when 'whatleadsto'   then 'delivered'
      when 'whatquenches' then 'worked'

  @set: (guy, x, rel, y, val) ->
    inv = if rel.match(/^what/) then rel.replace('what', '') else "what#{rel}"
    if rel.match(/requires|includes/)
      fb('goods/%/%/%', x.id, rel, y.id).set true
      fb('goods/%/%/%', y.id, inv, x.id).set true
      return @set(guy, x, @up[rel], y, val)
    @_set(guy, x, rel, y, val, true)
    @_set(guy, y, inv, x, val, true)

  @_set: (guy, x, rel, y, val, starting) ->
    @_set(guy, x, @up[rel], y, val, false) if @up[rel]
    @unset(guy, x, @down[rel], y) if @down[rel] and starting
    fb('observations/%/%/%/%', guy, x.id, rel, y.id).set val

  @unset: (guy, x, rel, y) ->
    fb('observations/%/%/%/%', guy, x.id, rel, y.id).remove()
    @unset(guy, x, @down[rel], y) if @down[rel]

  @up: {
    includes:      'quenches',
    whatincludes:  'whatquenches',
    requires:      'whatleadsto',
    whatrequires:  'leadsto',
    quenches:     'leadsto',
    whatquenches: 'whatleadsto',
    leadsto:       'whatdrives',
    whatleadsto:   'drives'
  }

  @down: {
    drives:      'whatleadsto',
    whatdrives:  'leadsto',
    whatleadsto: 'whatquenches',
    leadsto:     'quenches'
  }
