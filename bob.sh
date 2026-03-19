#Copyright 2026 awewsomegamer <awewsomegamer@gmail.com>
#
#Permission is hereby granted, free of charge,
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
EOF
	
)

if [[ $# < 1 ]]; then
    echo "$ERROR Need at leat one argument (all, rebuild, clean)"
    echo "$USAGE"
    exit 1
fi

INFO="INFO  :"
WARN="WARN  :"
ERROR="ERROR :"
TODO="TODO  :"
EXTRA="        "

export ARC_ROOT="$PWD"
export ARC_TARGETS="$ARC_ROOT/targets"

ARC_BUILDS="$ARC_ROOT/builds"
ARC_CLEAN_SRC="$ARC_ROOT/src.clean"

[ ! -d $ARC_TARGETS   ] && mkdir -p $ARC_TARGETS
[ ! -d $ARC_BUILDS    ] && mkdir -p $ARC_BUILDS
[ ! -d $ARC_CLEAN_SRC ] && mkdir -p $ARC_CLEAN_SRC

[[ $BOB_DEBUG == "yes" ]] && set -x

operation_suffix() {
    # $1 = operation
    # $2 = $?
    echo "$INFO Leaving target=$target"
    
    if [[ $2 != 0 ]]; then
	echo "$ERROR Failed to $1 target=$target"
	if [[ $mk != "" ]]; then
	    echo "$2"> "$mk/$1.fail"
	fi
    else
	echo "$INFO Successful $1 for target=$target"
	touch $mk/$1.complete
    fi

    return $2
}

checkget_target() {
    # $1 = function

    if [[ ! -e "$ARC_TARGETS/$target/Makefile" ]]; then
	echo "$ERROR Could not find Makefile for target=$target"
	return 1
    fi

    mk="$ARC_TARGETS/$target"
    
    if [[ $1 == "build" ]]; then
	status="$ARC_TARGETS/$target/build.complete"
	
	if [[ -e $status ]]; then
	    echo "$EXTRA target already built, skipping"
	    return 2
	fi

	status="$ARC_TARGETS/$target/build.fail"

	if [[ -e $status ]]; then
	    echo "$EXTRA target already failed to build, skipping"
	    return 3
	fi
    fi
    
    return 0
}

overwrite_source() {
    local srcdir_overwrite
    srcdir_overwrite=$(make -C $mk -s get-source-dir 2>/dev/null)

    if [[ $? == 0 ]]; then
	echo "$EXTRA overwrote source directory to $srcdir_overwrite"
	srcdir=$srcdir_overwrite
	return 0
    else
	echo "$EXTRA no source directory overwrite specified"
    fi

    srcdir_overwrite=$(make -C $mk -s use-source-dir-of 2>/dev/null)    

    if [[ $? == 0 ]]; then
	echo "$EXTRA attempting to use source directory of target=$srcdir_overwrite"
       
	local tmp_target
	tmp_target=$target

	target=$srcdir_overwrite
	checkget_target "get_source"
	[[ $? != 0 ]] && mk=$tmp_mk
    fi
}

download_source() {
    local urls
    urls=($(make -C $mk -s get-urls))
    
    if [[ $? != 0 ]]; then
	echo "$ERROR Failed to get-urls for target=$target"
	return 7
    fi
    
    for url in "${urls[@]}"; do
	echo "$EXTRA attempting to download $url"
	curl -o $tar_path -L $url
	if [[ $? == 0 ]]; then
	    echo "$EXTRA downloaded $url"
	    break
	fi
	echo "$EXTRA failed to download $url"
    done
}

patch_source() {
    echo "$EXTRA copying clean source src.clean/$basename.tar"
    if [ -e $patch_path ]; then
	cd $srcdir && patch -f -p1 < $patch_path
	
	if [[ $? != 0 ]]; then
	    echo "$ERROR Failed to patch $basename"
	    rm -rf $srcdir
	    return 1
	fi
    fi

    return 0
}

iget_source() {
    # $1 = operation
    overwrite_source 

    version=$(make -C $mk -s get-version)

    if [[ $? != 0 ]]; then
	echo "$ERROR Could not get version number"
	return 6
    fi
    
    basename="$target-$version"
    srcdir="$mk/$basename"
    tar_path="$srcdir.tar"
    patch_path="$srcdir.patch"
    
    echo "$EXTRA attempting to get source directory for $basename.tar"
    
    if [ -d $srcdir ]; then
	echo "$EXTRA found source directory: $srcdir"
	return 0
    fi
    
    if [[ $1 == "clean" ]]; then
	echo "$EXTRA will not download sources for clean operation"
	return 8
    fi
    
    if [ ! -e $tar_path ]; then
	download_source
	[[ $? != 0 ]] && return 7
    fi

    if [ -d "$ARC_CLEAN_SRC/$basename" ]; then
	cp -r $srcdir "$ARC_CLEAN_SRC/$basename"
	
	patch_source
	[[ $? != 0 ]] && return 9
    elif [ -e $tar_path ]; then
	mkdir $srcdir
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

	cp -r $srcdir "$ARC_CLEAN_SRC/$basename"
	
	echo "$EXTRA extracted $basename.tar"
	
	patch_source
	[[ $? != 0 ]] && return 4
    else
	echo "$ERROR Could not find source archive for target=$target"
	return 2
    fi

    if [ ! -d $ARC_SOURCE_DIR ]; then
	echo "$ERROR Failed to create source directory for target=$target"
	return 1
    fi
    
    return 0
}

get_source() {
    local tmp_mk
    tmp_mk=$mk
    iget_source $@
    mk=$tmp_mk
}

build_deps() {
    local deps
    deps=($(make -C $mk -s get-deps))
    
    echo "$EXTRA deps=${deps[@]}"

    for dep in "${deps[@]}"; do
	if [[ $parent == $dep ]]; then
	    echo "$WARN Circular dependency detected, building target=$target then parent=$parent"
	else
	    build $dep $target	    
	fi
    done

    return 0
}

build() {
    local target
    local parent
    
    target="$1"
    parent="$2"
    
    if [[ $target == "" ]]; then
	return 0
    fi
    
    echo "$INFO Entering target=$target (parent=$parent):"
    local mk
    checkget_target "build"

    case "$?" in
	0) ;;
	*) operation_suffix "build" $?
	   return $?
	   ;;
    esac
    
    build_deps

    echo "$INFO Getting source directory for target=$target"
    local srcdir
    get_source "build"
    
    if [[ $? != 0 ]]; then
	operation_suffix "build" 10
	return $?
    fi

    echo "srcdir=$srcdir"
    
    echo "$INFO Building target=$target"
    ARC_SOURCE_DIR=$srcdir make -C $mk build > $mk/Makefile.log

    operation_suffix "build" $?
    return $?
}

clean() {
    local target
    local type
    
    target="$1"
    type="$2"
    
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
    
    if [[ $type == "rebuild" ]]; then
	ARC_SOURCE_DIR=$srcdir make -C $mk prepare-rebuild > $mk/Makefile.log
    else
	ARC_SOURCE_DIR=$srcdir make -C $mk clean > $mk/Makefile.log
    fi

    operation_suffix "clean" $?
    return $?
}

# ERROR: This does not work because tar archives do not
#        include the .git folder. Maintain clean source
#        directory?
mkpatch() {
    local target
    target="$1"
    
    local mk
    checkget_target "mkpatch"

    if [[ $? != 0 ]]; then
	operation_suffix "mkpatch" 1
	return $?
    fi
    
    local srcdir
    get_source "mkpatch"

    if [[ $? != 0 ]]; then
	operation_suffix "mkpatch" 2
	return $?
    fi
    
    # TODO: Maybe use git format-patch?
    echo "$EXTRA creating patch"
    git --git-dir=$srcdir/.git diff $version HEAD -p > $patch_path 2> $mk/git.errors
    
    operation_suffix "mkpatch" $?
    return $?
}

cmdmux() {
    case $1 in
	"build")	
	    build $target
	    ;;
	"rebuild")
	    clean $target "rebuild"
	    build $target
	    ;;
	"clean")
	    clean $target "full"
	    ;;
	"mkpatch")
	    mkpatch $target
	    ;;
	*)
	    echo "Invalid command $1"
	    exit 1
	    ;;
    esac    
}

main() {
    local targets
    targets="${@:2}"

    if [[ $2 == "all" ]]; then
	targets=$(find $ARC_TARGETS -maxdepth 1 -type d -not -path $ARC_TARGETS -printf "%f\n")
    fi

    for target in $targets; do
	cmdmux $@
    done
}

main $@
