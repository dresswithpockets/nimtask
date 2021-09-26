import os
import tables
import strutils as strutils
import std/sha1 as sha1
import sequtils as sequtils
import re as re

import print

type
  InvalidTaskFile* = object of IOError
  AmbiguousPrefix* = object of KeyError
    prefix*: string
  UnknownPrefix* = object of KeyError
    prefix*: string

type
  TaskDict* = ref object
    taskdir: string
    name: string
    tasks: Table[string, Task]
    done: Table[string, Task]
  
  Task* = ref object
    id: string
    text: string
    metadata: Table[string, string]

proc taskHash*(text: string): string =
  return ($sha1.secureHash(text)).toLower

proc mapIdsToPrefixes*(tasks: Table[string, Task]): Table[string, string] =
  var ps = initTable[string, string]()
  for id,_ in tasks:
    var idlen = id.len
    var prefix: string
    var last: int
    for i in 1..idlen+1:
      last = i
      prefix = id.substr(0, i)
      if (not ps.hasKey(prefix)) or (ps.hasKey(prefix) and prefix != ps[prefix]):
        break
    if ps.hasKey(prefix):
      # if there is a collision
      var otherid = ps[prefix]
      var broken = false
      for j in last..idlen+1:
        var
          otherSub = otherid.substr(0, j)
          idSub = id.substr(0, j)
        if otherSub == idSub:
          ps[idSub] = ""
        else:
          ps[otherSub] = otherid
          ps[idSub] = id
          broken = true
          break
      if broken:
        ps[otherid.substr(0, idlen+1)] = otherid
        ps[id] = id
    else:
      # no collision, can safely add
      ps[prefix] = id
  var
    vals: seq[string]
    keys: seq[string]
  for key in ps.keys:
    keys.add(key)
  for val in ps.values:
    vals.add(val)
  ps = zip(vals, keys).toTable
  if ps.hasKey(""):
    ps.del("")
  return ps

proc `[]`*(td: var TaskDict, prefix: string): Task {.raises: [UnknownPrefix, KeyError, ValueError].} =
  var matched: seq[string]
  for tid in td.tasks.keys:
    if tid.startsWith(prefix):
      matched.add(tid)
  
  if matched.len == 1:
    return td.tasks[matched[0]]
  if matched.len == 0:
    var e = newException(UnknownPrefix, "Prefix '%s' not found" % prefix)
    e.prefix = prefix
    raise e
  if matched.contains(prefix):
    return td.tasks[prefix]
  var e = newException(AmbiguousPrefix, "Prefix '%s' is ambiguous with multiple prefixes" % prefix)
  e.prefix = prefix
  raise e

proc addTask*(td: var TaskDict, task: string, verbose: bool, quiet: bool): void =
  ## Add a new, unfinished task with the given summary text.
  var taskid = taskHash(task)
  td.tasks[taskid] = Task(id: taskid, text: task, metadata: initTable[string, string]())
  
  if not quiet:
    if verbose:
      echo taskid
    else:
      var prefixes = mapIdsToPrefixes(td.tasks)
      print(prefixes[taskid])

proc editTask*(td: var TaskDict, prefix: string, text: string): void =
  var task = td[prefix]
  var newText = text
  if newText.startsWith("s/") or newText.startsWith("/"):
    newText = re.replace(newText, re("^s/"), "")
    var
      split = newText.split("/")
      find = split[0]
      repl = split[1]
    newText = re.replace(task.text, re(find), repl)

  task.text = newText
  task.id = taskHash(newText)

proc finishTask*(td: var TaskDict, prefix: string): void =
  return

proc removeTask*(td: var TaskDict, prefix: string): void =
  return

proc write*(td: var TaskDict, deleteEmpty: bool): void =
  return

proc printList*(td: var TaskDict, kind: string, verbose: bool, quiet: bool, grep: string): void =
  return

proc taskFromTaskline*(line: TaintedString): Task =
  var barloc = line.find('|')
  if barloc != -1:
    var
      text = line.substr(0, barloc).strip
      metastr = line.substr(barloc + 1).strip
    result = Task(id: "", text: text, metadata: initTable[string, string]())
    for piece in metastr.split(','):
      var
        psplit = piece.split(':')
        label = psplit[0].strip
        data = psplit[1].strip
      if label == "id":
        result.id = data
      result.metadata[label] = data
  else:
    var text = line.strip
    result = Task(id: taskHash(text), text: text, metadata: initTable[string, string]())

proc tasklinesFromTasks*(tasks: seq[Task]): seq[string] =
  result = @[]

  var metaiter =
    iterator(task: Task): string =
      for key, value in task.metadata:
        yield "%s:%s" % [key, value]

  for task in tasks:
    var
      meta = metaiter(task).toSeq
      metaStr = meta.join(", ")
    result.add("%s | %s\n" % [task.text, metaStr])

proc initTaskDict*(taskdir: string = ".", name: string = "tasks"): TaskDict =
  var filemap = {"tasks": name, "done": ".%s.done" % name}.toTable
  result = TaskDict(taskdir: taskdir, name: name, tasks: initTable[string, Task](), done: initTable[string, Task]())
  for kind, filename in filemap:
    var path = joinPath(expandTilde(taskdir), filename)
    
    if dirExists(path):
      raise newException(InvalidTaskFile, "Task file provided is a folder, not a file")
    
    if not fileExists(path):
      return

    let f = open(path)
    defer: f.close()

    var line: TaintedString
    while f.readLine(line):
      line = line.strip()
      
      if line.startsWith("#"):
        continue

      var task = taskFromTaskline(line)
      case kind
        of "tasks":
          result.tasks[task.id] = task
        of "done":
          result.done[task.id] = task
