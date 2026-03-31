# bob
A simple build system.

# Usage		
         ```shell
         $ PARAM0=... ./bob.sh [function] [targets] 
         ```
         or:
         ```sh
         # File: ./my_bob.sh
         export PARAM0="..."
         export PARAM1="..."
         export PARAM2="..."
         export PARAM3="..."
         # ...
         source ./bob.sh
         ```
         ```shell
         $ ./my_bob.sh [function] [targets]
         ```

         If the first target specified in targets is "all", then it is
		 expanded to be all subdirectories in $BOB_ROOT/targets which
		 contain a Makefile named $BOB_MAKEFILE_NAME.

         Where function is one of:

# build
         The build command will iterate through all targets specified. If a target is
		 found, its dependencies are built first then the target itself. In case of a
		 circular dependency, the dependency is built before the parent target.

# clean
         The clean command will delete the build.complete file and invoke `make clean`
         on all specified targets.
         
         NOTE: The build and clean commands redirect their output to the same `Makefile.log`
               file

# rebuild
         Rebuild is an alias for running a clean operation then a build operation on each
         specified target.
         
         NOTE: This is not the same as `./bob.sh clean [targets] && ./bob.sh build [targets]`
         NOTE: Instead of running `make clean`, rebuild runs `make prepare-rebuild`

# mkpatch
         The mkpatch command will use git to generate a patch between the current state of
         the target and the clean version of the source code.

# Bob Makefiles
         See targets/toolA or toolB to see the base implementation of a valid Makefile.

## Targets in Makefiles
         bob.sh will call into Makefiles to attain more information about a given target.
		 It is important to distinguish target Makefiles, located in folders within the
		 "targets" subdirectory ("bob target(s)"), and the targets of those Makefiles, actions
 		 or files the Makefile can build.

	 bob.sh calls the following targets within a target's Makefile:
### Mandatory
#### build
         A phony target that actually builds the source code provided in the SOURCE_CODE
	 variable.
#### clean
         A phony target that preforms additional cleaning work.
#### prepare-rebuild
         A phony which prepares the source code for a future build.
#### get-version
         Echoes the version number of the bob target.

### Optional
#### get-deps (default: "")
         Echoes none, one, or a series of space separated bob targets
	 which must be built prior to the current bob target.
#### get-urls (default: "")
         Echoes none, one, or a series of space separated URLs
		 of which one may be chosen to download a .tar* source
		 code archive from.
#### get-staging (default: "yes")
         Echoes either nothing or "disabled" to disable the creation and
		 copying of the source directory to $srcbuild and $srcclean.
#### get-basename (default: "$target-$version")
         Echoes the desired basename of the bob target to override the
		 default $target-$version.
#### get-source-dir (default: "")
         Echoes the absolute path to the source directory which should
		 be used for the bob target.
#### use-source-dir-of (default: "")
         Echoes the name of the bob target whose source directory should
		 be used.

## Environment
         bob.sh makes available the following environment variables when
		 calling Makefile targets:
### BOB_ROOT
         The root directory in which the bob.sh, targets, and .autogen
		 directories can be found. This value may be overwritten by the
		 user.
### SOURCE_DIR
         A value passed when bob.sh calls a Makefile's build, clean, or
		 prepare-rebuild targets. Its value is of the format:
		 "$BOB_BUILD/$basename/src".
### BOB_TARGETS
         The same as "$BOB_ROOT/targets".
### BOB_VERSION
         A two component version string "$major.$minor".

# Enabling additional Debugging
         To enable debugging information (set -x) set `BOB_DEBUG` to "yes".

# Disabling Status Files
         Status files such as build.complete/fail, rebuild.complete/fail may
		 be disabled by setting `BOB_DISABLE_STATUS_FILES` to "yes".

# .autogen
         The .autogen directory is created by bob.sh to maintain various internal directories that
         must not be modified by the user in normal operation.

## .autogen/clean
         Contains copies of each bob targets' clean source code - prior to patching; exactly as
	 extracted from the source code archive.

## .autogen/build
         Contains subdirectories for each target. Within each subdirectory is anohter subdirectory
	 named "src" which contains a copy of the patched source code - this is the directory specified
	 in the SOURCE_DIR variable passed to the build, clean, and prepare-rebuild Makefile targets.
	 The parent of the "src" directory may be used by the Makefile targets to store out of source
	 tree files.
   
