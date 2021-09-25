import argparse

import os
import tables
import strutils as strutils
import std/sha1 as sha1

type
  InvalidTaskFile* = object of IOError
  AmbiguousPrefix* = object of KeyError
    prefix: string
  UnknownPrefix* = object of KeyError
    prefix: string

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

proc addTask(td: var TaskDict, task: string): void =
  return

proc editTask(td: var TaskDict, prefix: string, task: string): void =
  return

proc finishTask(td: var TaskDict, prefix: string): void =
  return

proc removeTask(td: var TaskDict, prefix: string): void =
  return

proc write(td: var TaskDict, deleteEmpty: bool): void =
  return

proc printList(td: var TaskDict, kind: string, verbose: bool, quiet: bool, grep: string): void =
  return

proc taskHash(text: string): string =
  return ($sha1.secureHash(text)).toLower

proc taskFromTaskline(line: TaintedString): Task =
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

proc tasklinesFromTasks(tasks: seq[Task]): seq[string] =
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

proc initTaskDict(taskdir: string = ".", name: string = "tasks"): TaskDict =
  var filemap = {"tasks": name, "done": strutils.format(".%s.done", name)}.toTable
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

proc main(): void =
  var p = newParser:
    help("Simple todo list manager")

    option("-l", "--list", help="work on this list", default=some("tasks"))
    option("-t", "--dir", help="work on the lists in this directory", default=some("."))
    flag("-d", "--deleteEmpty", help="delete the task file if it becomes empty")

    option("-g", "--grep", help="print only tasks that contain word")
    flag("-v", "--verbose", help="print more detailed output (full task ids, etc)")
    flag("-q", "--quiet", help="print less detailed output (no task ids, etc)")
    flag("--done", help="list done tasks instead of unfinished ones")
    
    command("a"):
      help("Add a new task")
      arg("text", help="The text of new the task to add", nargs = -1)

    command("e"):
      help("Edit an existing task")
      arg("prefix", help="The ID or prefix of the task to edit", nargs = 1)
      arg("text", help="The text to replace the specified task with", nargs = -1)

    command("f"):
      help("Set an existing task to done/finished")
      arg("prefix", help="The ID or prefix of the task to set to done", nargs = 1)
    
    command("r"):
      help("Remove an existing task")
      arg("prefix", help="The ID or prefix of the task to remove", nargs = 1)

  try:
    var
      opts = p.parse()
      taskDict = initTaskDict(opts.dir, opts.list)

    case opts.argparse_command
      of "a":
        taskDict.addTask(opts.argparse_a_opts.get().text.join(" "))
      of "e":
        taskDict.editTask(opts.argparse_r_opts.get().prefix, opts.argparse_a_opts.get().text.join(" "))
      of "f":
        taskDict.finishTask(opts.argparse_r_opts.get().prefix)
      of "r":
        taskDict.removeTask(opts.argparse_r_opts.get().prefix)
      else:
        var kind = if opts.done: "done" else: "tasks"
        taskDict.printList(kind, opts.verbose, opts.quiet, opts.grep)
        return
    
    taskDict.write(opts.deleteEmpty)

  except AmbiguousPrefix as e:
    stderr.writeLine "the ID '%s' matches more than one task" % e.prefix
  except UnknownPrefix as e:
    stderr.writeLine "the ID '%s' does not match any task" % e.prefix
  except ShortCircuit as e:
    if e.flag == "argparse_help":
      echo p.help
      quit(1)
  except UsageError:
    stderr.writeLine getCurrentExceptionMsg()
    quit(1)

main()