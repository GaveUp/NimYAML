#            NimYAML - YAML implementation in Nim
#        (c) Copyright 2015 Felix Krause
#
#    See the file "copying.txt", included in this
#    distribution, for details about the copyright.

import jester, asyncdispatch, json, streams, strutils
import packages.docutils.rstgen, packages.docutils.highlite
import yaml

routes:
  get "/":
    headers["Content-Type"] = "text/plain"
    resp "I am a friendly NimYAML parser webservice."
  post "/":
    var
      style: PresentationStyle
      resultNode = newJObject()
      tokens = false
    headers["Access-Control-Allow-Origin"] = "*"
    headers["Pragma"] = "no-cache"
    headers["Cache-Control"] = "no-cache"
    headers["Expires"] = "0"
    try:
      case @"style"
      of "minimal": style = psMinimal
      of "canonical": style = psCanonical
      of "default": style = psDefault
      of "json": style = psJson
      of "block": style = psBlockOnly
      of "tokens":
        var
          output = ""
          parser = newYamlParser()
          events = parser.parse(newStringStream(@"input"))
        for event in events: output.add($event & "\n")
        resultNode["code"] = %0
        resultNode["output"] = %output
        resp resultNode.pretty, "application/json"
        tokens = true
      if not tokens:
        var
          output = newStringStream()
          highlighted = ""
        transform(newStringStream(@"input"), output, defineOptions(style))
        
        # syntax highlighting (stolen and modified from stlib's rstgen)
        var g: GeneralTokenizer
        g.initGeneralTokenizer(output.data)
        while true:
          g.getNextToken(langYaml)
          case g.kind
          of gtEof: break
          of gtNone, gtWhitespace:
            highlighted.add(substr(output.data, g.start, g.length + g.start - 1))
          else:
            highlighted.addf("<span class=\"$2\">$1</span>", "\\span$2{$1}", [
              esc(outHtml, substr(output.data, g.start, g.length+g.start-1)),
              tokenClassToStr[g.kind]])

        resultNode["code"] = %0
        resultNode["output"] = %highlighted
        resp resultNode.pretty, "application/json"
    except YamlParserError:
      let e = (ref YamlParserError)(getCurrentException())
      resultNode["code"] = %1
      resultNode["line"] = %e.line
      resultNode["column"] = %e.column
      resultNode["message"] = %e.msg
      resultNode["detail"] = %e.lineContent
      resp resultNode.pretty, "application/json"
    except YamlPresenterJsonError:
      let e = getCurrentException()
      resultNode["code"] = %2
      resultNode["message"] = %e.msg
      headers["Content-Type"] = "application/json"
      resp resultNode.pretty, "application/json"
    except:
      let e = getCurrentException()
      let msg = "Name: " & $e.name & "\nMessage: " & e.msg &
                "\nTrace:\n" & e.getStackTrace
      resp Http500, msg, "text/plain;charset=utf-8"

runForever()
