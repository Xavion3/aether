# Based on https://github.com/substack/node-falafel
# A similar approach could be seen in https://github.com/ariya/esmorph
_ = window?._ ? self?._ ? global?._ ? require 'lodash'  # rely on lodash existing, since it busts CodeCombat to browserify it--TODO

esprima = require 'esprima'  # getting our Esprima Harmony
acorn_loose = require 'acorn/acorn_loose'  # for if Esprima dies. Note it can't do ES6.
csredux = require 'coffee-script-redux'

fixLocations = require './fixLocations'

module.exports = morph = (source, transforms, parser="esprima") ->
  chunks = source.split ''
  locToRange = null
  if parser is 'esprima'
    ast = esprima.parse source, {range: true, loc: true}
  else if parser is 'csredux'
    csAST = csredux.parse source, {optimise: false, raw: true}
    ast = csredux.compile csAST, {bare: true}
    fixLocations ast
  else if parser is 'acorn_loose'
    ast = acorn_loose.parse_dammit source, {locations: true}
    # Esprima uses "range", but acorn_loose only has "locations"
    lines = source.replace(/\n/g, '\n空').split '空'  # split while preserving newlines
    posToOffset = (pos) ->
      _.reduce(lines.slice(0, pos.line - 1), ((sum, line) -> sum + line.length), 0) + pos.column
      # lines are 1-indexed, and I think columns are 0-indexed, but should verify
    locToRange = (loc) ->
      [posToOffset(loc.start), posToOffset(loc.end)]

  walk = (node, parent) ->
    insertHelpers node, parent, chunks, locToRange
    for key, child of node
      continue if key is 'parent' or key is 'leadingComments'
      if _.isArray child
        for grandchild in child
          walk grandchild, node if _.isString grandchild?.type
      else if _.isString child?.type
        walk child, node
    transform node for transform in transforms
  walk ast, undefined
  chunks.join ''

insertHelpers = (node, parent, chunks, locToRange) ->
  node.range = locToRange(node.loc) if node.loc and locToRange
  return unless node.range
  node.parent = parent
  node.source = -> chunks.slice(node.range[0], node.range[1]).join ''
  update = (s) ->
    chunks[node.range[0]] = s
    for i in [node.range[0] + 1 ... node.range[1]]
      chunks[i] = ''
  if _.isObject node.update
    _.extend update, node.update
  node.update = update
