_                 = require '../../vendor/lodash'
React             = require 'react'
ReactRedux        = require 'react-redux'
PureRenderMixin   = require 'react-addons-pure-render-mixin'
timm              = require 'timm'
tinycolor         = require 'tinycolor2'
moment            = require 'moment'
chalk             = require 'chalk'
ColoredText       = require './030-coloredText'
Icon              = require './910-icon'
actions           = require '../actions/actions'
k                 = require '../../gral/constants'
ansiColors        = require '../../gral/ansiColors'

#-====================================================
# ## Story
#-====================================================
mapStateToProps = (state) -> 
  timeType: state.settings.timeType
mapDispatchToProps = (dispatch) ->
  onToggleTimeType: -> dispatch actions.toggleTimeType()
  onToggleExpanded: (pathStr) -> dispatch actions.toggleExpanded pathStr
  onToggleHierarchical: (pathStr) -> dispatch actions.toggleHierarchical pathStr
  onToggleAttachment: (pathStr, recordId) -> 
    dispatch actions.toggleAttachment pathStr, recordId

_Story = React.createClass
  displayName: 'Story'

  #-----------------------------------------------------
  propTypes:
    story:                  React.PropTypes.object.isRequired
    level:                  React.PropTypes.number.isRequired
    seqFullRefresh:         React.PropTypes.number.isRequired
    # From Redux.connect
    timeType:               React.PropTypes.string.isRequired
    onToggleTimeType:       React.PropTypes.func.isRequired
    onToggleExpanded:       React.PropTypes.func.isRequired
    onToggleHierarchical:   React.PropTypes.func.isRequired
    onToggleAttachment:     React.PropTypes.func.isRequired

  #-----------------------------------------------------
  render: -> 
    if @props.story.fWrapper 
      return <div>{@renderRecords()}</div>
    if @props.level is 1 then return @renderRootStory()
    return @renderNormalStory()

  renderRootStory: ->
    {level, story} = @props
    <div className="rootStory" style={_style.outer level, story}>
      <div 
        className="rootStoryTitle" 
        style={_style.rootStoryTitle}
        onClick={@toggleHierarchical}
      >
        {story.title.toUpperCase()}
      </div>
      {@renderRecords()}
    </div>

  renderNormalStory: ->
    {level, story} = @props
    {title, fOpen} = story
    if fOpen then spinner = <Icon icon="circle-o-notch" style={_style.spinner}/>
    <div className="story" style={_style.outer(level, story)}>
      <Line
        record={story}
        level={@props.level}
        fStoryTitle
        fDirectChild={false}
        timeType={@props.timeType}
        onToggleTimeType={@props.onToggleTimeType}
        onToggleExpanded={@toggleExpanded}
        onToggleHierarchical={@toggleHierarchical}
        seqFullRefresh={@props.seqFullRefresh}
      />
      {@renderRecords()}
    </div>

  renderRecords: ->
    return if not @props.story.fExpanded
    records = @prepareRecords @props.story.records
    out = []
    for record in records
      out.push @renderRecord record
      if record.objExpanded and record.obj?
        out = out.concat @renderAttachment record
    out

  renderRecord: (record) ->
    {id, fStory, storyId, records, obj, objExpanded} = record
    fDirectChild = storyId is @props.story.storyId
    if fStory and records
      return <Story key={storyId}
        story={record}
        level={@props.level + 1}
        seqFullRefresh={@props.seqFullRefresh}
      />
    else
      return <Line key={id}
        record={record}
        level={@props.level}
        fDirectChild={fDirectChild}
        timeType={@props.timeType}
        onToggleTimeType={@props.onToggleTimeType}
        onToggleAttachment={@toggleAttachment}
        seqFullRefresh={@props.seqFullRefresh}
      />
    out

  renderAttachment: (record) -> 
    props = _.pick @props, ['level', 'timeType', 'onToggleTimeType', 'seqFullRefresh']
    return record.obj.map (line, idx) ->
      <AttachmentLine key={"#{record.id}_#{idx}"}
        record={record}
        {...props}
        msg={line}
      />

  #-----------------------------------------------------
  toggleExpanded: -> @props.onToggleExpanded @props.story.pathStr
  toggleHierarchical: -> @props.onToggleHierarchical @props.story.pathStr
  toggleAttachment: (recordId) -> 
    @props.onToggleAttachment @props.story.pathStr, recordId

  #-----------------------------------------------------
  prepareRecords: (records) ->
    if @props.story.fHierarchical
      out = _.sortBy records, 't'
    else
      out = @flatten records
    out

  flatten: (records, level = 0) ->
    out = []
    for record in records
      if record.fStory and record.records
        out = out.concat @flatten(record.records, level + 1)
      else
        out.push record
    if level is 0
      out = _.sortBy out, 't'
    out

#-----------------------------------------------------
_style = 
  outer: (level, story) ->
    bgColor = 'aliceblue'
    if story.fServer then bgColor = tinycolor(bgColor).darken(5).toHexString()
    backgroundColor: bgColor # if story.fServer then '#f5f5f5' else '#e8e8e8'
    marginBottom: if level <= 1 then 10
    padding: if level <= 1 then 2
  rootStoryTitle:
    fontWeight: 900
    textAlign: 'center'
    letterSpacing: 3
    marginBottom: 5
    cursor: 'pointer'

#-----------------------------------------------------
connect = ReactRedux.connect mapStateToProps, mapDispatchToProps
Story = connect _Story


#-====================================================
# ## AttachmentLine
#-====================================================
AttachmentLine = React.createClass
  displayName: 'AttachmentLine'
  mixins: [PureRenderMixin]

  #-----------------------------------------------------
  propTypes:
    record:                 React.PropTypes.object.isRequired
    level:                  React.PropTypes.number.isRequired
    timeType:               React.PropTypes.string.isRequired
    onToggleTimeType:       React.PropTypes.func.isRequired
    seqFullRefresh:         React.PropTypes.number.isRequired
    msg:                    React.PropTypes.string.isRequired

  #-----------------------------------------------------
  render: ->
    {record} = @props
    style = _styleLine.log record
    <div 
      className="attachmentLine"
      style={style}
    >
      <Time
        fShowFull={false}
        timeType={@props.timeType}
        onToggleTimeType={@props.onToggleTimeType}
        seqFullRefresh={@props.seqFullRefresh}
      />
      <Severity level={String record.objLevel}/>
      <Src src={record.src}/>
      <Indent level={@props.level}/>
      <CaretOrSpace/>
      <ColoredText text={'  ' + @props.msg}/>
    </div>


#-====================================================
# ## Line
#-====================================================
Line = React.createClass
  displayName: 'Line'
  mixins: [PureRenderMixin]

  #-----------------------------------------------------
  propTypes:
    record:                 React.PropTypes.object.isRequired
    level:                  React.PropTypes.number.isRequired
    fStoryTitle:            React.PropTypes.bool
    fDirectChild:           React.PropTypes.bool.isRequired
    timeType:               React.PropTypes.string.isRequired
    onToggleTimeType:       React.PropTypes.func.isRequired
    onToggleExpanded:       React.PropTypes.func
    onToggleHierarchical:   React.PropTypes.func
    onToggleAttachment:     React.PropTypes.func
    seqFullRefresh:         React.PropTypes.number.isRequired
  getInitialState: ->
    fHovered:               false

  #-----------------------------------------------------
  render: ->
    {record, fStoryTitle, fDirectChild, level} = @props
    {id, msg, fStory, fOpen, title, action} = record
    return <div/> if fDirectChild and action in ['CREATED', 'CLOSED']
    if fStory 
      msg = if not fDirectChild then "#{title} " else ''
      if action and not fStoryTitle then msg += chalk.gray "[#{action}]"
    if fStoryTitle
      className = 'storyTitle'
      style = _styleLine.titleRow level
      indentLevel = level - 1
      if fOpen then spinner = <Icon icon="circle-o-notch" style={_styleLine.spinner}/>
    else
      className = 'log'
      style = _styleLine.log record
      indentLevel = level
    <div 
      className={"#{className} fadeIn"}
      onMouseEnter={@onMouseEnter}
      onMouseLeave={@onMouseLeave}
      style={style}
    >
      {@renderTime record}
      <Severity level={if fStory then null else record.level}/>
      <Src src={record.src}/>
      <Indent level={indentLevel}/>
      {@renderCaretOrSpace record}
      {@renderMsg fStoryTitle, msg}
      {if fStoryTitle then @renderToggleHierarchical record}
      {spinner}
      {@renderAttachmentIcon record}
    </div>

  renderMsg: (fStoryTitle, msg) ->
    if fStoryTitle
      <ColoredText 
        text={msg} 
        onClick={@props.onToggleExpanded}
        style={_styleLine.title}
      />
    else
      <ColoredText text={msg}/>

  renderTime: (record) ->
    {fStory, records, t} = record
    {level, timeType, onToggleTimeType, seqFullRefresh} = @props
    fShowFull = (fStory and records and level <= 2) or (level <= 1)
    <Time
      t={t}
      fShowFull={fShowFull}
      timeType={timeType}
      onToggleTimeType={onToggleTimeType}
      seqFullRefresh={seqFullRefresh}
    />

  renderCaretOrSpace: (record) ->
    if @props.onToggleExpanded and record.fStory and record.records
      fExpanded = record.fExpanded
    <CaretOrSpace fExpanded={fExpanded} onToggleExpanded={@props.onToggleExpanded}/>

  renderToggleHierarchical: (story) ->
    return if not @props.onToggleHierarchical
    return if not @state.fHovered
    {fHierarchical} = story
    text = if fHierarchical then 'flat' else 'tree'
    <span 
      onClick={@props.onToggleHierarchical}
      style={_styleLine.toggleHierarchical}
    >
      {text}
    </span>

  renderAttachmentIcon: (record) ->
    return if not record.obj?
    icon = if record.objExpanded then 'folder-open-o' else 'folder-o'
    <Icon 
      icon={icon} 
      onClick={@onClickAttachment}
      style={_styleLine.attachmentIcon}
    />

  #-----------------------------------------------------
  onMouseEnter: -> @setState {fHovered: true}
  onMouseLeave: -> @setState {fHovered: false}
  onClickAttachment: -> @props.onToggleAttachment @props.record.id

#-----------------------------------------------------
_styleLine =
  titleRow: (level) ->
    fontWeight: 900
    fontFamily: 'monospace'
    whiteSpace: 'pre'
  title:
    cursor: 'pointer'
  log: (record) ->
    bgColor = 'aliceblue'
    if record.fServer then bgColor = tinycolor(bgColor).darken(5).toHexString()
    backgroundColor: bgColor # if story.fServer then '#f5f5f5' else '#e8e8e8'
    fontFamily: 'monospace'
    whiteSpace: 'pre'
    fontWeight: if record.fStory and (record.action is 'CREATED') then 900
  toggleHierarchical:
    display: 'inline-block'
    marginLeft: 10
    color: 'darkgrey'
    textDecoration: 'underline'
    cursor: 'pointer'
  spinner:
    marginLeft: 8
  attachmentIcon:
    marginLeft: 8
    cursor: 'pointer'

#-====================================================
# ## Time
#-====================================================
Time = React.createClass
  displayName: 'Time'
  mixins: [PureRenderMixin]
  propTypes:
    t:                      React.PropTypes.number
    fShowFull:              React.PropTypes.bool
    timeType:               React.PropTypes.string.isRequired
    onToggleTimeType:       React.PropTypes.func.isRequired
    seqFullRefresh:         React.PropTypes.number.isRequired
  render: ->
    {t, fShowFull, timeType} = @props
    if not t? then return <span>{_.padEnd '', 24}</span>
    fRelativeTime = false
    m = moment t
    localTime = m.format('YYYY-MM-DD HH:mm:ss.SSS')
    if timeType is 'RELATIVE'
      shownTime = m.fromNow()
      fRelativeTime = true
    else
      if timeType is 'UTC' then m.utc()
      if fShowFull
        shownTime = m.format('YYYY-MM-DD HH:mm:ss.SSS')
      else
        shownTime = '           ' + m.format('HH:mm:ss.SSS')
      if timeType is 'UTC' then shownTime += 'Z'
    shownTime = _.padEnd shownTime, 24
    <span 
      onClick={@props.onToggleTimeType}
      style={_styleTime fRelativeTime}
      title={if timeType isnt 'LOCAL' then localTime}
    >
      {shownTime}
    </span>

_styleTime = (fRelativeTime) ->
  display: 'inline-block'
  cursor: 'pointer'
  fontStyle: if fRelativeTime then 'italic'

#-====================================================
# ## Severity
#-====================================================
Severity = React.createClass
  displayName: 'Severity'
  mixins: [PureRenderMixin]
  propTypes:
    level:                  React.PropTypes.string
  render: ->
    {level} = @props
    if level?
      levelStr = ' ' + ansiColors.LEVEL_NUM_TO_COLORED_STR[level]
      <ColoredText text={levelStr}/>
    else
      <span style={_styleStorySeverity}> -----</span>

_styleStorySeverity = 
  color: 'gray'

#-====================================================
# ## Src
#-====================================================
Src = React.createClass
  displayName: 'Src'
  mixins: [PureRenderMixin]
  propTypes:
    src:                    React.PropTypes.string
  render: ->
    {src} = @props
    srcStr = ' ' + ansiColors.getSrcChalkColor(src) _.padEnd(src, 15)
    <ColoredText text={srcStr}/>

#-====================================================
# ## CaretOrSpace
#-====================================================
Indent = ({level}) -> 
  style = 
    display: 'inline-block'
    width: 20 * (level - 1)
  <div style={style}/>

#-====================================================
# ## CaretOrSpace
#-====================================================
CaretOrSpace = React.createClass
  displayName: 'CaretOrSpace'
  mixins: [PureRenderMixin]
  propTypes:
    fExpanded:              React.PropTypes.bool
    onToggleExpanded:       React.PropTypes.func
  render: ->
    if @props.fExpanded?
      iconType = if @props.fExpanded then 'caret-down' else 'caret-right'
      icon = <Icon icon={iconType} onClick={@props.onToggleExpanded}/>
    <span style={_styleCaretOrSpace}>{icon}</span>

_styleCaretOrSpace =
  display: 'inline-block'
  width: 30
  paddingLeft: 10
  cursor: 'pointer'

#-----------------------------------------------------
module.exports = Story