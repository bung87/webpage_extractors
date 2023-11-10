import std/[os, json, math]
import zippy
import webpage_extractors/basic

const DataDir = currentSourcePath.parentDir / "html"
let groundTruth = parseJson(readFile( currentSourcePath.parentDir / "ground-truth.json" ))

when defined(ExtractAll):
  var count: int
  var simCount: int
  var exactCount: int
  var missCount: int
  var missDocs = newSeq[string]()
  var wrongDocs = newSeq[string]()
  for key, value in groundTruth:
    let p = DataDir / key & ".html.gz"
    let c = value["articleBody"].getStr
    let content = readFile(p)
    let uncompresssed = uncompress(content)
    let output = extractContent(uncompresssed, textOnly = true)
    if output == c:
      inc exactCount
    elif output.len == 0:
      inc missCount
      missDocs.add key
    elif round(output.len / c.len) == 1.0:
      inc simCount
    else:
      # echo "===================output==================="
      # echo output
      # echo "===================expected==================="
      # echo c

      # echo c.len
      # echo round(output.len / c.len, 1) 
      wrongDocs.add key
    inc count

  echo "sim: " & $(simCount / (count - missCount))
  echo "exactCount: " & $exactCount
  echo "missDocs: " & $missDocs
  echo "wrongDocs: " & $wrongDocs

else:
  let testKey = "f105de6e63ca91ea482f60193f6252092557f969f2fd128ff68c0d4d6b90dd7d"
  let c = groundTruth[testKey]["articleBody"].getStr
  let p = currentSourcePath.parentDir / "html" / testKey & ".html"
  let content = readFile(p)
  # let uncompresssed = uncompress(content)
  echo "==========================     =========================="
  let o = extractContentBasic(content, textOnly = true)
  echo o
  echo round(o.len.float / c.len.float)
