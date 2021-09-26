# Package

version       = "0.1.0"
author        = "dresswithpockets"
description   = "A cli todo list manager for people that want to get things done"
license       = "Apache-2.0"
srcDir        = "src"
binDir        = "bin"
installExt    = @["nim"]
bin           = @["nimtask"]


# Dependencies

requires "nim >= 1.4.8"
requires "argparse >= 2.0.0"
requires "print >= 1.0.0"