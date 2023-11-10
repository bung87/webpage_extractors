# Package

version       = "0.1.0"
author        = "bung87"
description   = "webpage information extractor"
license       = "MIT"
srcDir        = "src"


# Dependencies

requires "nim >= 2.1.1"

task evaluation, "This is a hello task":
  echo("Hello World!")

taskRequires "evaluation", "zippy"
