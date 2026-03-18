# bob
A simple build system.

## Usage
MAKEFILE_PARAM=... ./bob.sh build   [targets]
MAKEFILE_PARAM=... ./bob.sh rebuild [targets]
MAKEFILE_PARAM=... ./bob.sh clean   [targets]
MAKEFILE_PARAM=... ./bob.sh mkpatch [targets]

If the first target specified in targets is "all", then it is
expanded out to be everything in the ./targets folder

### Build
The build command will build all specified targets for the first time.
It will attempt to resolve the dependencies of targets before the targets/
themselves.
Circular dependencies are resolved by building the first dependency. For instance:
toolA -> toolB -> toolA, where "->" means dependes on, then toolB would be built
first.

NOTE: The build and clean commands redirect their output to the same `Makefile.log`
      file

### Clean
The clean command will delete the build.complete file and invoke `make clean`
on all specified targets.

NOTE: The build and clean commands redirect their output to the same `Makefile.log`
      file

### Rebuild
Rebuild is an alias for running a clean command then a build command on each
specified target.
NOTE: This is not the same as `./bob.sh clean [targets] && ./bob.sh build [targets]`
NOTE: Instead of running `make clean`, rebuild runs `make prepare-rebuild`

### Mkpatch
The mkpatch command will use git to generate a patch between the current state of
the target and the version (commit) specified by the Makefile. Errors are redirected
to the git.errors file.

## Valid Makefiles
See `targets/toolA` or `targets/toolB` to see the base implementation of a valid Makefile.
