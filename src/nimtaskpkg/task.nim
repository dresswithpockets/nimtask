import os
import tables
import strutils as strutils
import std/sha1 as sha1
import sequtils as sequtils

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

proc addTask*(td: var TaskDict, task: string): void =
  return

proc editTask*(td: var TaskDict, prefix: string, task: string): void =
  return

proc finishTask*(td: var TaskDict, prefix: string): void =
  return

proc removeTask*(td: var TaskDict, prefix: string): void =
  return

proc write*(td: var TaskDict, deleteEmpty: bool): void =
  return

proc printList*(td: var TaskDict, kind: string, verbose: bool, quiet: bool, grep: string): void =
  return

proc taskHash*(text: string): string =
  return ($sha1.secureHash(text)).toLower

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
