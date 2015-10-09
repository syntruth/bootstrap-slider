class Slider
  defaults:
    min         : 0
    max         : 10
    step        : 1
    value       : 5
    selection   : 'before'
    tooltip     : 'show'
    handle      : 'round'
    orientation : 'horizontal'
    formater    : (value) -> value

  pickerHTML: """
              <div class="slider">
                <div class="slider-track">
                  <div class="slider-selection"></div>
                  <div class="slider-handle"></div>
                  <div class="slider-handle"></div>
                </div>
                <div class="tooltip">
                  <div class="tooltip-arrow"></div>
                  <div class="tooltip-inner"></div>
                </div>
              </div>
              """

  over:   false
  inDrag: false

  constructor: (element, options) ->
    @options = $.extend {}, @defaults, options
    @element = $(element)
    @picker  = $(@pickerHTML)

    @picker.insertBefore @element
    @picker.append @element

    this._setup()

    this.layout()

    @picker[0].id = @id if @id

    return this

  showTooltip: () ->
    @tooltip.addClass 'in'

    @over = true

    return this

  hideTooltip: () ->
    @tooltip.removeClass('in') unless @inDrag

    @over = false

    return this

  layout: () ->
    @handle1Stype[@stylePos] = "#{@percentage[0]}%"
    @handle2Stype[@stylePos] = "#{@percentage[1]}%"

    min = Math.min(@percentage[0], @percentage[1])
    abs = Math.abs(@percentage[0] - @percentage[1])

    if @orientation is 'vertical'
      @selectionElStyle.top    = "#{min}%"
      @selectionElStyle.height = "#{abs}%"
    else
      @selectionElStyle.left   = "#{min}%"
      @selectionElStyle.width  = "#{abs}%"

    tip = if @range
      "#{@formater @value[0]} : #{@formater @value[1]}"
    else
      "#{@formater @value[0]}"

    @tooltipInner.text tip
    @tooltip[0].style[@stylePos] = this._tooltipPx @range

    return this

  mousedown: (ev) ->
    # Touch: Get the original event
    ev = ev.originalEvent if @touchCapable and ev.type is 'touchstart'

    @offset = @picker.offset()
    @size   = @picker[0][@sizePos]

    percentage = this.getPercentage ev

    if @range
      diff1 = Math.abs(@percentage[0] - percentage)
      diff2 = Math.abs(@percentage[1] - percentage)

      @dragged = if diff1 < diff2 then 0 else 1
    else
      @dragged = 0

    @percentage[@dragged] = percentage

    this.layout()

    $(document).on
      mousemove: $.proxy(this.mousemove, this)
      mouseup:   $.proxy(this.mouseup, this)

    if @touchCapable
      # Touch: Bind touch events
      $(document).on
        touchmove: $.proxy(this.mousemove, this)
        touchend:  $.proxy(this.mouseup, this)

    @inDrag = true

    val = this.calculateValue()

    @element.trigger type: 'slideStart', value: val
    @element.trigger type: 'slide',      value: val

    return false

  mousemove: (ev) ->
    # Touch: Get the original event
    ev = ev.originalEvent if @touchCapable and ev.type is 'touchmove'

    percentage = this.getPercentage ev

    if @range
      if @dragged is 0 and @percentage[1] < percentage
        @percentage[0] = @percentage[1]
        @dragged       = 1
      else if @dragged is 1 and @percentage[0] > percentage
        @percentage[1] = @percentage[0]
        @dragged       = 0

    @percentage[@dragged] = percentage

    this.layout()

    val = this.calculateValue()

    @element.trigger type: 'slide', value: val
    @element.data('value', val).prop('value', val)

    return false

  mouseup: (ev) ->
    $(document).off mousemove: this.mousemove, mouseup: this.mouseup

    if @touchCapable
      $(document).off touchmove: this.mousemove, touchend: this.mouseup

    @inDrag = false

    this.hideTooltip() if @over is false

    val = this.calculateValue()

    @element.trigger type: 'slideStop', value: val
    @element.data('value', val).prop('value', val)

    return false

  calculateValue: () ->
    firstVal = this._calcValue @percentage[0]

    if @range
      @value = val = [firstVal, this._calcValue(@percentage[1])]
    else
      val    = firstVal
      @value = [val, @value[1]]

    return val

  getPercentage: (ev) ->
    ev = ev.touches[0] if @touchCapable
    p2 = @percentage[2]

    p = (ev[@mousePos] - @offset[@stylePos]) * 100 / @size
    p = Math.round(p / p2) * p2
    m = Math.min 100, p

    return Math.max(0, m)

  getValue: () -> if @range then @value else @value[0]

  setValue: (val) ->
    @value = val

    if @range
      @value[0] = Math.max(@min, Math.min(@max, @value[0]))
      @value[1] = Math.max(@min, Math.min(@max, @value[1]))
    else
      @value = [Math.max(@min, Math.min(@max, @value))]

      @handle2.addClass('hide')

      @value[1] = if @selection is 'after' then @max else @min

    @diff = @max - @min

    this._setupPercentage()

    this.layout()

    return this

  update: (options = {}) ->
    @options = $.extend {}, @options, options

    this._setup()

    return this

  _calcValue: (value) ->
    @min + Math.round((@diff * value / 100) / @step) * @step

  _tooltipPx: (isRange = false) ->
    diff  = @percentage[1] - @percentage[0]
    outer = if @orientation is 'vertical'
      @tooltip.outerHeight() / 2
    else
      @tooltip.outerWidth() / 2

    size = if isRange
      @size * ((@percentage[0] + diff) / 2) / 100 - outer
    else
      @size * @percentage[0] / 100 - outer

    return "#{size}px"

  _setup: () ->
    this._setupSettings()
    this._setupTooltip()
    this._setupOrientation()
    this._setupTouch()
    this._setupSelection()
    this._setupHandle()
    this._setupValue()
    this._setupPercentage()
    this._setupEvents()

    return

  _setupSettings: () ->
    @id = @element.data('slider-id') or @options.id

    @doTooltip = @element.data('slider-tooltip')       or @options.tooltip
    @orientation = @element.data('slider-orientation') or @options.orientation

    @min   = @element.data('slider-min')   or @options.min
    @max   = @element.data('slider-max')   or @options.max
    @step  = @element.data('slider-step')  or @options.step
    @value = @element.data('slider-value') or @options.value

    @formater = @options.formater

    @range  = @value[1] isnt undefined
    @diff   = @max - @min
    @offset = @picker.offset()

    return

  _setupTooltip: () ->
    @tooltip      = @picker.find '.tooltip'
    @tooltipInner = @tooltip.find '.tooltip-inner'

    return

  _setupOrientation: () ->
    if @orientation is 'vertical'
      @stylePos = 'top'
      @mousePos = 'pageY'
      @sizePos  = 'offsetHeight'

      @picker.addClass('slider-vertical')
      @tooltip.addClass('right')[0].style.left = '100%'
    else
      @orientation = 'horizontal'
      @stylePos    = 'left'
      @mousePos    = 'pageX'
      @sizePos     = 'offsetWidth'

      @picker.addClass('slider-horizontal').css('width', @element.outerWidth())

      top = -@tooltip.outerHeight() - 14

      @tooltip.addClass('top')[0].style.top = "#{top}px"

    @size = @picker[0][@sizePos]

    return

  _setupTouch: () ->
    if typeof Modernizr isnt 'undefined' and Modernizr.touch
      @touchCapable = true

    return

  _setupSelection: () ->
    @selection = @element.data('slider-selection') or @options.selection

    @selectionEl      = @picker.find('.slider-selection')
    @selectionElStyle = @selectionEl[0].style

    @selectionEl.addClass('hide') if @selection is 'none'

    return

  _setupHandle: () ->
    @handle1      = @picker.find('.slider-handle:first')
    @handle1Stype = @handle1[0].style
    @handle2      = @picker.find('.slider-handle:last')
    @handle2Stype = @handle2[0].style

    handle = @element.data('slider-handle') or @options.handle

    switch handle
      when 'round'
        @handle1.addClass('round')
        @handle2.addClass('round')

      when 'triangle'
        @handle1.addClass('triangle')
        @handle2.addClass('triangle')

    return

  _setupValue: () ->
    if @range
      @value[0] = Math.max(@min, Math.min(@max, @value[0]))
      @value[1] = Math.max(@min, Math.min(@max, @value[1]))
    else
      @value = [Math.max(@min, Math.min(@max, @value))]

      @handle2.addClass('hide')

      if @selection == 'after'
        @value[2] = @max
      else
        @value[1] = @min

    return

  _setupPercentage: () ->
    @percentage = [
      this._calcPercentage(@value[0]),
      this._calcPercentage(@value[1]),
      @step * 100 / @diff
    ]

    return

  _setupEvents: () ->
    event = if @touchCapable then 'touchstart' else 'mousedown'

    @picker.on event, $.proxy(this.mousedown, this)

    if @doTooltip is 'show'
      @picker.on
        mouseenter: $.proxy(this.showTooltip, this)
        mouseleave: $.proxy(this.hideTooltip, this)
    else
      @tooltip.addClass 'hide'

    return

  _calcPercentage: (value) -> (value - @min) * 100 / @diff


window.jQuery.fn.slider = (option, val) ->
  $this = $(this)
  data  = $this.data('slider')

  return data[option](val) if data

  if option and typeof option is 'object'
    data = new Slider this, option

    $this.data 'slider', data

  return

window.jQuery.fn.slider.Constructor = Slider
