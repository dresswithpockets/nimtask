import nimtaskpkg/task
import argparse
import strutils

when isMainModule:
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
        taskDict.editTask(opts.argparse_e_opts.get().prefix, opts.argparse_a_opts.get().text.join(" "))
      of "f":
        taskDict.finishTask(opts.argparse_f_opts.get().prefix)
      of "r":
        taskDict.removeTask(opts.argparse_r_opts.get().prefix)
      else:
        var kind = if opts.done: "done" else: "tasks"
        taskDict.printList(kind, opts.verbose, opts.quiet, opts.grep)
        quit(0)
    
    taskDict.write(opts.deleteEmpty)

  except AmbiguousPrefix as e:
    stderr.writeLine("the ID '%s' matches more than one task" % e.prefix)
  except UnknownPrefix as e:
    stderr.writeLine("the ID '%s' does not match any task" % e.prefix)
  except ShortCircuit as e:
    if e.flag == "argparse_help":
      echo p.help
      quit(1)
  except UsageError:
    stderr.writeLine getCurrentExceptionMsg()
    quit(1)
