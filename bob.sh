# Copyright 2026 awewsomegamer <awewsomegamer@gmail.com>
#
# Permission is hereby granted, free of charge,
# to any person obtaining a copy of this software
# and associated documentation files (the “Software”),
# to deal in the Software without restriction,
# including without limitation the rights to use,
# copy, modify, merge, publish, distribute,
# sublicense, and/or sell copies of the Software,
# and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice
# shall be included in all copies or substantial portions
# of the Software.
#
# THE SOFTWARE IS PROVIDED “AS IS”, WITHOUT WARRANTY OF
# ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED
# TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A
# PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
# THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM,
# DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
# TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
# WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

# TODO: Improve this explanation
autogen_usage() {
    AUTOGEN_USAGE=$(cat <<"EOF"
# .autogen
         The .autogen directory is created by bob.sh to maintain various internal directories that
         must not be modified by the user.

# .autogen/clean
         Copies of each target's clean source code - prior to patching and any modification, as
         extracted from the downloaded archive.

# .autogen/build
         Symbolic links to each target's source code files prior to building. Symbolic links are
         copied out into the same relative posistion they are in originally. The source of the
         linking is located in targets/$target/$target-$version/.
   
EOF
		 )
    echo "$AUTOGEN_USAGE"
}

print_usage() {
    USAGE=$(cat <<"EOF"
# Usage		
         ```shell
         $ MAKEFILE_PARAM0=... ./bob.sh [function] [targets] 
         ```
         or:
         ```sh
         # File: ./my_bob.sh
         export MAKEFILE_PARAM0="..."
         export MAKEFILE_PARAM1="..."
         export MAKEFILE_PARAM2="..."
         export MAKEFILE_PARAM3="..."
         # ...
         source ./bob.sh
         ```
         ```shell
         $ ./my_bob.sh [function] [targets]
         ```

         If the first target specified in targets is "all", then it is
         expanded out to be everything in the ./targets folder

         Where function is one of:

# build
         The build command will build all specified targets for the first time.
         It will attempt to resolve the dependencies of targets before the targets/
         themselves.
         
         Circular dependencies are resolved by building the first dependency. For instance:
         toolA -> toolB -> toolA, where "->" means dependes on, then toolB would be built
         first.

# clean
         The clean command will delete the build.complete file and invoke `make clean`
         on all specified targets.
         
         NOTE: The build and clean commands redirect their output to the same `Makefile.log`
               file

# rebuild
         Rebuild is an alias for running a clean command then a build command on each
         specified target.
         
         NOTE: This is not the same as `./bob.sh clean [targets] && ./bob.sh build [targets]`
         NOTE: Instead of running `make clean`, rebuild runs `make prepare-rebuild`

# mkpatch
         The mkpatch command will use git to generate a patch between the current state of
         the target and the version (commit) specified by the Makefile. Errors are redirected
         to the git.errors file.


# Target Makefiles
         See targets/toolA or toolB to see the base implementation of a valid Makefile.

## Target's in Makefiles
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

# Enabling additional Debugging
         ```shell
         $ BOB_DEBUG=yes ./bob.sh [args]
         ```
EOF
	
)
    echo "$USAGE"
    autogen_usage
    exit 1
}

INFO="INFO  :"
WARN="WARN  :"
ERROR="ERROR :"
TODO="TODO  :"
EXTRA="        "

[[ $BOB_ROOT                 == "" ]] && export BOB_ROOT="$PWD"
[[ $BOB_TARGETS              == "" ]] && export BOB_TARGETS="$BOB_ROOT/targets"
[[ $BOB_MAKEFILE_NAME        == "" ]] && BOB_MAKEFILE_NAME="bob.mk"
[[ $BOB_DISABLE_STATUS_FILES == "" ]] && BOB_DISABLE_STATUS_FILES="no"

BOB_DOT_AUTOGEN="$BOB_ROOT/.autogen"
BOB_BUILD="$BOB_DOT_AUTOGEN/build"
BOB_CLEAN="$BOB_DOT_AUTOGEN/clean"
BOB_AUTOGEN_USAGE="$BOB_DOT_AUTOGEN/README.md"

[ ! -d $BOB_TARGETS       ] && mkdir -p $BOB_TARGETS
[ ! -d $BOB_BUILD         ] && mkdir -p $BOB_BUILD
[ ! -d $BOB_CLEAN         ] && mkdir -p $BOB_CLEAN
[ ! -e $BOB_AUTOGEN_USAGE ] && autogen_usage > $BOB_AUTOGEN_USAGE

[[ $BOB_DEBUG == "yes" ]] && set -x

export BOB_VERSION="0.1"

if [[ $# < 1 ]]; then
    echo "$ERROR Need at leat one argument (all, rebuild, clean)"
    print_usage
fi

operation_suffix() {
    # $1 = operation
    # $2 = $?
    echo "$INFO Leaving target=$target"
    
    if [[ $2 == 0 ]]; then
	echo "$INFO Successful $1 for target=$target"
	[[ $BOB_DISABLE_STATUS_FILES != "yes" ]] && touch $mk/$1.complete
	return 0
    fi

    echo "$ERROR Failed to $1 target=$target"
    if [[ $mk != "" ]] && [[ $BOB_DISABLE_STATUS_FILES != "yes" ]]; then
	echo "$2" > "$mk/$1.fail"
    fi
    
    return $2
}

checkget_target() {
    # $1 = function

    if [[ ! -e "$BOB_TARGETS/$target/$BOB_MAKEFILE_NAME" ]]; then
	echo "$ERROR Could not find Makefile for target=$target"
	return 1
    fi

    mk="$BOB_TARGETS/$target"
    
    if [[ $1 == "build" ]]; then
	status="$BOB_TARGETS/$target/build.complete"
	
	if [[ -e $status ]]; then
	    echo "$EXTRA target already built, skipping"
	    return 2
	fi

	status="$BOB_TARGETS/$target/build.fail"

	if [[ -e $status ]]; then
	    echo "$EXTRA target already failed to build, skipping"
	    return 3
	fi
    fi
    
    return 0
}

# Defined Behavior:
#  * A Makefile which describes no override (download source and use basename)
#  * A Makefile which describes an overwrite (use this directory, do not delete it on clean)
#  * A Makefile which uses another target's source directory (and that target falls under the first case)
#  * A Makefile which uses another target's source directory (and that target falls under the second case)
#  TODO: This will forever recurse in the event that targetA uses the source dir of targetB who uses the
#        source dir of targetA. Detect this
overwrite_source() {
    local srcdir_overwrite
    srcdir_overwrite=$(make -f $mk/$BOB_MAKEFILE_NAME -s get-source-dir 2>/dev/null)
    
    if [[ $? == 0 ]]; then
	echo "$EXTRA overwrote source directory to $srcdir_overwrite"
	srcdir_owner=""
	srcdir=$srcdir_overwrite
	[[ ! -d $srcdir ]] && return 1
	return 0
    else
	echo "$EXTRA no source directory overwrite specified"
    fi

    srcdir_overwrite=$(make -f $mk/$BOB_MAKEFILE_NAME -s use-source-dir-of 2>/dev/null)    

    if [[ $? == 0 ]]; then
	echo "$EXTRA attempting to use source directory of target=$srcdir_overwrite"

	target=$srcdir_overwrite
	checkget_target "get_source"
	if [[ $? != 0 ]]; then
	    mk=$tmp_mk
	    target=$tmp_target
	    return 2
	fi

	overwrite_source
	# NOTE1: The reason a non-zero return code is given is so that iget_source
	#        determines the source directory itself as no specific directory was
	#        provided; only the target was found.
	return 3
    else
	echo "$EXTRA not using the source directory of another target"
    fi

    # NOTE1
    return 4
}

download_source() {
    local urls
    urls=($(make -f $mk/$BOB_MAKEFILE_NAME -s get-urls 2>/dev/null))
    
    if [[ $? != 0 ]]; then
	echo "$EXTRA no URLs specified"
	return 1
    fi
    
    for url in "${urls[@]}"; do
	echo "$EXTRA attempting to download $url"
	curl -o $tar_path -L $url

	if [[ $? == 0 ]]; then
	    echo "$EXTRA downloaded $url"
	    return 0
	fi
	
	echo "$EXTRA failed to download $url"
    done

    return 2
}

patch_source() {
    if [ ! -e $patch_path ]; then
	echo "$EXTRA no patches to be applied"
	return 0
    fi

    echo "$EXTRA patching $srcdir with $patch_path"
    cd $srcdir && patch -f -p1 < $patch_path
    
    if [[ $? != 0 ]]; then
	echo "$ERROR Failed to patch $basename"
	rm -rf $srcdir
	return 1
    fi
    
    return 0
}

create_srcbuild() {
    # TODO: This is a nice approach in theory, but it is extremely slow.
    #       can it be temporally improved in anyway?
    # echo "$EXTRA linking files in targets/$targets/$basename to .autogen/build/$basename"
    # cd $srcdir && find -type f -print0 | xargs -0 -I {} bash -c 'mkdir -p $3/$(dirname "$1") && ln -s "$2"/"{}" "$3"/"{}"' -- {} "$srcdir" "$srcbuild"
    # echo "$EXTRA copying symlinks in targets/$targets/$basename to .autogen/build/$basename"
    # cd $srcdir && find -type l -print0 | xargs -0 -I {} bash -c 'mkdir -p $3/$(dirname "$1") && cp -P "$2"/"{}" "$3"/"{}"' -- {} "$srcdir" "$srcbuild"       
    [[ -d $srcbuild ]] && return 0
    
    mkdir -p $srcbuild
    echo "$EXTRA copying $srcdir to $srcbuild"
    cp -Pprf $srcdir/. $srcbuild
}

create_srcclean() {    
    [[ -d $srcclean ]] && return 0
    
    mkdir -p $srcclean
    echo "$EXTRA copying $srcdir to $srcclean"
    cp -Pprf $srcdir/. $srcclean
}

iget_source() {
    # $1 = operation

    srcdir_owner="bob.sh"
    
    overwrite_source

    version=$(make -f $mk/$BOB_MAKEFILE_NAME -s get-version 2>/dev/null)

    if [[ $? != 0 ]]; then
	echo "$ERROR Could not get version number"
	return 6
    fi
    
    basename=$(make -f $mk/$BOB_MAKEFILE_NAME -s get-basename 2>/dev/null)
    
    if [[ $? != 0 ]]; then
	basename="$target-$version"
	echo "$EXTRA no basename provided, using default"
    fi
    
    flat_basename="${basename##*/}"
    
    echo "$EXTRA basename=$basename (flat: $flat_basename)"
    
    if [[ $srcdir == "" ]]; then
	srcdir="$mk/$flat_basename"

	echo "$EXTRA attempting to get source directory for $basename"
    fi
    
    tar_path="$srcdir.tar"
    patch_path="$srcdir.patch"	
    srcclean="$BOB_CLEAN/$basename"
    srcbuild="$BOB_BUILD/$basename/src"
   
    local staging
    staging=$(make -f $mk/$BOB_MAKEFILE_NAME -s get-staging 2>/dev/null)
    [[ $? != 0 ]] && staging=""

    if [[ $staging == "disabled" ]]; then
	echo "$EXTRA staging=$staging, srcbuild=srcclean=srcdir"
	srcclean=$srcdir
	srcbuild=$srcdir
    fi
    
    if [ -d $srcdir ]; then
	echo "$EXTRA found srcdir=$srcdir"
        create_srcbuild

	return 0
    fi
    
    if [[ $1 == "clean" ]]; then
	echo "$EXTRA will not create source for clean operation"
	return 8
    fi
    
    mkdir -p $srcdir
    
    if [ ! -e $tar_path ]; then
	download_source
    fi
    
    if [ -d $srcclean ]; then
	echo "$EXTRA $srcclean exists, copying it to $srcdir"
	cp -Pprf $srcclean/. $srcdir
    elif [ -e $tar_path ]; then
	# TODO: Most likely whatever service generated the tar
	#       will have included the parent directory so this
	#       is fine, but what if it didn't? How can this case 
	#       be detected and corrected for?
	tar -xf $tar_path -C $srcdir --strip-components=1
	
	if [[ $? != 0 ]]; then
	    echo "$ERROR Failed to extract $basename.tar"
	    rm -rf $srcdir
	    return 3
	fi

	echo "$EXTRA extracted $basename.tar"

	create_srcclean
    else
	echo "$ERROR Could not find source archive for target=$target"
	return 2
    fi
    
    if [ ! -d $srcdir ]; then
	echo "$ERROR Failed to create source directory for target=$target"
	return 1
    fi

    patch_source
    [[ $? != 0 ]] && return 9
    
    create_srcbuild
    
    if [ ! -d $srcbuild ] || [ ! -d $srcclean ]; then
	echo "$ERROR Failed to create source directories for target=$target"
	return 10
    fi

    return 0
}

get_source() {
    # $1 = operation
    local tmp_mk=$mk
    local tmp_target=$target
    local rc
    iget_source $@
    rc=$?
    target=$tmp_target
    mk=$tmp_mk
    return $rc
}

build_deps() {
    local deps=($(make -f $mk/$BOB_MAKEFILE_NAME -s get-deps))
    
    echo "$EXTRA deps=${deps[@]}"

    for dep in "${deps[@]}"; do
	if [[ $parent == $dep ]]; then
	    echo "$WARN Circular dependency detected, building target=$target then parent=$parent"
	else
	    build $dep $target
	    [[ $? != 0 ]] && return 1
	fi
    done

    return 0
}

build() {
    local target="$1"
    local parent="$2"
    
    [[ $target == "" ]] && return 0
    
    echo "$INFO Entering target=$target (parent=$parent):"
    local mk
    checkget_target "build"

    case $? in
	0) ;;
	2) operation_suffix "build" 0
	   return $?
	   ;;
	*) operation_suffix "build" $?
	   return $?
	   ;;
    esac
    
    build_deps

    if [[ $? != 0 ]]; then
	echo "$ERROR: Failed to build dependencies"
	operation_suffix "build" 15
	return $?	
    fi
    
    echo "$INFO Getting source directory for target=$target"
    local srcbuild
    get_source "build"
    
    if [[ $? != 0 ]]; then
	operation_suffix "build" 10
	return $?
    fi
    
    echo "$INFO Building target=$target"
    
    cd $mk
    SOURCE_DIR=$srcbuild make -f $BOB_MAKEFILE_NAME build
    
    operation_suffix "build" $?
    return $?
}

clean() {
    local target="$1"
    local type="$2"
    
    if [[ $target == "" ]]; then
	return 0
    fi

    echo "$INFO Entering target=$target (type=$type):"
    
    local mk
    checkget_target "clean"

    if [[ $? != 0 ]]; then
	operation_suffix "clean" 1
	return $?
    fi

    rm -f $mk/*.complete $mk/*.fail
    
    local srcdir
    local srcdir_owner
    local srcclean
    local srcbuild
    get_source "clean"
    
    case $? in
	0) ;;
	8) operation_suffix "clean" 0
	   return $?
	   ;;
	*) operation_suffix "clean" 2
	   return $?
	   ;;
    esac

    cd $mk
    if [[ $type == "rebuild" ]]; then
	SOURCE_DIR=$srcbuild make -f $BOB_MAKEFILE_NAME prepare-rebuild
    else
	SOURCE_DIR=$srcbuild make -f $BOB_MAKEFILE_NAME clean
	if [[ $srcdir_owner == "bob.sh" ]]; then
	   rm -rf $srcdir
	   rm -f "$srcdir.tar"
	else
	    echo "$EXTRA srcdir owner=$srcdir_owner, not deleting"
	fi
	
	[[ $srcdir != $srclean ]] && rm -rf $srcclean
	[[ $srcdir != $srcbuild ]] && rm -rf $srcbuild
	
	BOB_DISABLE_STATUS_FILES="yes"
    fi

    operation_suffix "clean" $?
    return $?
}

mkpatch() {
    local target="$1"

    if [[ $target == "" ]]; then
	return 0
    fi
    
    local mk
    checkget_target "mkpatch"

    if [[ $? != 0 ]]; then
	operation_suffix "mkpatch" 1
	return $?
    fi
    
    local srcdir
    local srcclean
    get_source "mkpatch"

    if [[ $? != 0 ]]; then
	operation_suffix "mkpatch" 2
	return $?
    fi

    echo "$EXTRA creating patch"
    local clean_rel_path="$(realpath --relative-to=$srcdir $srcclean)"
    cd $srcdir && git diff --no-index $clean_rel_path . -p > $patch_path
    
    case $? in
	1) operation_suffix "mkpatch" 0  ;;
	*) operation_suffix "mkpatch" $? ;;
    esac
}

cmdmux() {
    local tmp_PWD=$PWD
    local tmp_BOB_DISABLE_STATUS_FILES=$BOB_DISABLE_STATUS_FILES
    
    case $1 in
	"build")	
	    build "$target"
	    ;;
	"clean")
	    clean "$target" "full"
	    ;;
	"rebuild")
	    clean "$target" "rebuild"
	    build "$target"
	    ;;
	"mkpatch")
	    mkpatch "$target"
	    ;;
	"version")
	    echo "version=bob.sh-$BOB_VERSION"
	    exit 0
	    ;;
	*)
	    echo "Invalid command $1"
	    print_usage
	    ;;
    esac

    BOB_DISABLE_STATUS_FILES=$tmp_BOB_DISABLE_STATUS_FILES
    PWD=$tmp_PWD
}

# TODO: What would be cool is a secondary script that could be run in series, but before,
#       this script to containerize everything to a specific environment. This way builds
#       would be a little bit more portable

main() {
    # $1    = command
    # $2..n = target(s)
    
    local targets
    targets="${@:2}"

    if [[ $2 == "all" ]]; then
	target_paths=$(find $BOB_TARGETS -type f -name $BOB_MAKEFILE_NAME -exec dirname {} \;)
	# TODO: This introduces some weirdness by adding an empty element at the beginning
	#       of the list, this was fixed by wrapping all instances of $target in cmdmux
	#       in double quotes; however, is it certain that the first element will always
	#       be empty and if so, how can it be trimmed?
	# TODO: This string substitution also makes it impossible for a target to be called
	#       $PWD/*
	targets=("${target_paths//"$BOB_TARGETS/"/}")
    fi
    
    [[ $# == 2 ]] && cmdmux $@
    
    for target in $targets; do
	cmdmux $@
    done
}

main $@
