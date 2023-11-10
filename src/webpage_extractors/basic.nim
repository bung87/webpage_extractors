import std/[xmltree, strformat, algorithm, sequtils, streams, parsexml, unicode, math, stats, re]
import std/strutils
import pkg/htmlparser

type ParsedNode {.acyclic.} = ref object
  node: XmlNode
  textLen: int
  childLen: int
  nonLinkLen: int
  depth: int
  punctuations: int
  pLen: int
  index: int
  parent: ParsedNode

proc `$`*(n: ParsedNode): string =
  fmt"""tag: {n.node.tag()}, id: {n.node.attr("id")}, class: {n.node.attr("class")}, nonLinkLen: {n.nonLinkLen}, textLen: {n.textLen}, pLen: {n.pLen}, depth: {n.depth}, index: {n.index}"""

proc traverse(parsedNodes: var seq[ParsedNode], node: XmlNode, parent: ParsedNode = nil) =
  # const AvoidTags = ["head", "meta", "title", "link", "script", "select", "style"]
  # const AvoidItemTags = ["a", "option", "li", "button"]
  case node.kind
  of xnElement:
    var pnode: ParsedNode
    # allow unknown tag
    pnode = new ParsedNode
    pnode.node = node
    pnode.parent = parent
    pnode.childLen = node.len()
    parsedNodes.add pnode
    for n in node:
      traverse(parsedNodes, n, pnode)
    if parent != nil:
      parent.pLen.inc pnode.pLen
      parent.nonLinkLen.inc pnode.nonLinkLen
      parent.textLen.inc pnode.textLen
      parent.punctuations.inc pnode.punctuations
  of xnText:
    var add = true
    var p {.cursor.} = parent
    while p != nil:
      if htmlTag(p.node.tag()) in {tagA, tagTime}:
        add = false
        break
      if p.parent != nil:
        p = p.parent
      else:
        break
    if add:
      let text = node.text()
      var count: int
      var startIdx: int
      for i in 0 ..< text.len:
        if text[i] in Whitespace:
          startIdx = i
          count.inc
        else:
          break
      for i in countdown(text.len - 1, startIdx + 1):
        if text[i] in Whitespace:
          count.inc
        else:
          break
      parent.textLen.inc text.len - count
      parent.punctuations = count(text, {',','.','!'})
      if text.len - count > 1:
        parent.pLen.inc
        parent.nonLinkLen.inc 1
    # else:
    #   parent.nonLinkLen.inc 1
    #   parent.pLen.inc 1

  of xnComment, xnVerbatimText, xnCData, xnEntity:
    discard

proc traverseText(s: var string, node: XmlNode, parent: XmlNode = nil) =
  case node.kind
  of xnElement:
    let oldTextLen = s.len
    for n in node:
      traverseText(s, n, node)
    s = unicode.strip(s)
    let textLen = s.len
    if textLen > 0 and htmlTag(node.tag()) in {tagP, tagDiv}:
      s.add "\n\n"
    elif htmlTag(node.tag()) in BlockTags:
      s.add "\n"
    elif htmlTag(node.tag()) == tagBr:
      s.add "\n"

  of xnText:
    # if parent != nil:
    let t = node.text()
    # s.add strutils.strip(t.replace(re"\n", ""), chars = Whitespace + Newlines)
    let sp = count(t, Whitespace + Newlines)

    if t.len != sp:
      s.add strutils.strip(t.replace(re"[\r\n]", ""), chars = Whitespace)
    else:
      let t2 = t.replace(re"\s+", "")
      s.add t2 #strutils.strip(t, chars = Newlines)
      # echo repr t2
  of xnEntity:
    case $node
    of "&nbsp":
      s.add " "
    else:
      discard
  of xnComment, xnCData, xnVerbatimText:
    discard

proc extractText(node: XmlNode): string =
  traverseText(result, node, nil)

# proc findBody(s: string): string = 
#   var x: XmlParser
#   open(x, newStringStream(s.strip()), "xml")
#   var start: int
#   var ends: int
#   while true:
#     echo x.kind
#     x.next()
#     case x.kind
#     of xmlElementStart:
#       if cmpIgnoreCase(x.elementName, "body") == 0:
#         start = x.bufpos
#       x.next()
#     of xmlElementEnd:
#       if cmpIgnoreCase(x.elementName, "body") == 0:
#         ends = x.bufpos
#       x.next()
#     of xmlEof: break # end of file reached
#     else: x.next() # ignore other events
#   x.close()
  
#   if ends > start:
#     echo "ends: " , ends
#     echo "start: " , start
#     result = x.buf[start ..< ends ]
#     # echo result

proc findTag(s: sink string, tag: string): string =
  var start = s.find("<" & tag )
  var ends = s.rfind("</" & tag & ">") + ("</" & tag  & ">").len - 1
  
  if start > 0 and ends > start:
    result = s[start .. ends]
  else:
    return s

proc findBody(s: sink string): string =
  result = s
  for tag in ["body"]:
    result = findTag(result, tag)
  
  result = result.multiReplace([
    (re"<head[\s\S]*?>[\s\S]*?<\/head>", ""),
    (re"<script[\s\S]*?>[\s\S]*?<\/script>", "<script></script>"),
    (re"<link[\s\S]*?>", ""),
    (re"<noscript[\s\S]*?>[\s\S]*?<\/noscript>", "<noscript></noscript>"),
    (re"<style[\s\S]*?>[\s\S]*?<\/style>", ""),
    (re"<svg[\s\S]*?>[\s\S]*?<\/svg>", "<svg></svg>"),
    (re"<form[\s\S]*?>[\s\S]*?<\/form>", "<form></form>"),
    (re"<nav[\s\S]*?>[\s\S]*?<\/nav>", "<nav></nav>"),
    (re"<aside[\s\S]*?>[\s\S]*?<\/aside>", "<aside></aside>"),
    (re"<select[\s\S]*?>[\s\S]*?<\/select>", "<select></select>"),
    (re"<iframe[\s\S]*?>[\s\S]*?<\/iframe>", "<iframe></iframe>"),
  ])
  # echo result

proc computeScore(it: ParsedNode): float =
  let textDensity = it.textLen.float / it.nonLinkLen.float
  let textTagsScore = ln(float(it.pLen + 2))
  # let depthScore = ln(float(it.depth + 2))
  # let punctuationsDensity = float(ln(max(count(it.node.innerText(), PunctuationChars),2).float))
  let punctuationsDensity = float(ln(max( it.textLen / (it.punctuations + 1), 2).float))
  result = textDensity * textTagsScore * punctuationsDensity #* depthScore

proc extractContentBasic*(s: string, textOnly = false): string =
  var errors = newSeq[string]()
  let tree = parseHtml(newStringStream(s.findBody()), "dum", errors)
  # echo errors
  var parsedNodes = newSeq[ParsedNode]()
  var a: ParsedNode
  traverse(parsedNodes, tree, a)
  if parsedNodes.len == 0:
    return
  for i, n in parsedNodes:
    n.index = i

  var filtered = parsedNodes.filterIt( htmlTag(it.node.tag()) notin {tagHtml, tagBody} and it.textLen > 0 and it.nonLinkLen > 0 and htmlTag(it.node.tag()) in (BlockTags + {tagUnknown}))
  if filtered.len == 0:
    return
  var tmp: ParsedNode
  var means = newSeq[float]()
  for i, n in filtered:
    if htmlTag(n.node.tag()) notin BlockTags:
      continue
    means.add n.textLen.float
    tmp = n.parent
    while tmp != nil:
      n.depth.inc
      tmp = tmp.parent
  let m = mean(means)
  
  filtered = filtered.filterIt( htmlTag(it.node.tag()) notin {tagP, tagUl} and it.textLen.float >= m )
  
  # var aa = newSeq[float]()
  # for it in filtered:
  #   aa.add it.textLen / (it.nonLinkLen)
  # aa.sort()
  # let mi2 = round((aa.len - 1) / 2).int
  # let m2 = aa[mi2]
  # filtered = filtered.filterIt(  it.textLen.float >= m2 )
  
  # filtered = filtered.sortedByIt( it.textLen / (it.nonLinkLen) )
  # echo filtered
  # let m3 = filtered[int(ceil(filtered.len.float - 1.0) / 6)].index.float
  # / ln( abs(it.index.float - m3)  + 2)
  var sorted = filtered.sortByIt(computeScore(it))
  # echo sorted
  let finalLen = sorted.len
  if finalLen > 0:
    if textOnly:
      result = strutils.strip(extractText(sorted[finalLen - 1].node))
    else:
      result = $sorted[finalLen - 1].node
