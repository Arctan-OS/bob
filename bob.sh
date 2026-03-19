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

# Usage
# MAKEFILE_PARAM=... ./bob.sh build   [targets]
# MAKEFILE_PARAM=... ./bob.sh rebuild [targets]
# MAKEFILE_PARAM=... ./bob.sh clean   [targets]
# MAKEFILE_PARAM=... ./bob.sh mkpatch [targets]
#
# If the first target specified in targets is "all", then it is
# expanded out to be everything in the ./targets folder
#
# The build command will build all specified targets for the first time.
# It will attempt to resolve the dependencies of targets before the targets/
# themselves.
# Circular dependencies are resolved by building the first dependency. For instance:
# toolA -> toolB -> toolA, where "->" means dependes on, then toolB would be built
# first.
#
# The clean command will delete the build.complete file and invoke `make clean`
# on all specified targets.
#
# NOTE: The build and clean commands redirect their output to the same `Makefile.log`
#       file
#
# Rebuild is an alias for running a clean command then a build command on each
# specified target.
# NOTE: This is not the same as `./bob.sh clean [targets] && ./bob.sh build [targets]`
# NOTE: Instead of running `make clean`, rebuild runs `make prepare-rebuild`
# 
# The mkpatch command will use git to generate a patch between the current state of
# the target and the version (commit) specified by the Makefile. Errors are redirected
# to the git.errors file.
#
# See targets/toolA or toolB to see the base implementation of a valid Makefile.

export ARC_ROOT="$PWD"
export ARC_TARGETS="$PWD/targets"

if [[ $# < 1 ]]; then
    echo "Need at leat one argument (all, rebuild, clean)"
    exit 1
fi

INFO="INFO  :"
WARN="WARN  :"
ERROR="ERROR :"
TODO="TODO  :"
EXTRA="        "

operation_suffix() {
    # $1 = operation
    # $2 = $?
    echo "$INFO Leaving target=$target"
    
    if [[ $2 != 0 ]]; then
	echo "$ERROR Failed to $1 target=$target"
	if [[ $mk_dir != "" ]]; then
	    echo "$2"> "$mk_dir/$1.fail"
	fi
    else
	echo "$INFO Successful $1 for target=$target"
	touch $mk_dir/$1.complete
    fi

    return $2
}

checkget_target() {
    # $1 = function
    mk=$(find $ARC_TARGETS -type f -wholename "$ARC_TARGETS/$target/Makefile")

    if [[ $mk == "" ]]; then
	echo "$ERROR Could not find Makefile for target=$target"
	return 1
    fi

    if [[ $1 == "build" ]]; then
	status=$(find $ARC_TARGETS -type f -wholename "$ARC_TARGETS/$target/build.complete")
	
	if [[ $status != "" ]]; then
	    echo "$EXTRA target already built, skipping"
	    return 2
	fi

	status=$(find $ARC_TARGETS -type f -wholename "$ARC_TARGETS/$target/build.fail")

	if [[ $status != "" ]]; then
	    echo "$EXTRA target already failed to build, skipping"
	    return 3
	fi
    fi
    
    mk_dir=$(dirname $mk)
    
    return 0
}

get_source() {
    # $1 = operation
    local srcdir_overwrite
    srcdir_overwrite=$(make -C $mk_dir -s get-source-dir 2>/dev/null)

    if [[ $? == 0 ]]; then
	echo "$EXTRA overwrote source directory to $srcdir_overwrite"
	srcdir=$srcdir_overwrite
	return 0
    else
	echo "$EXTRA no source directory overwrite specified"
    fi

    srcdir_overwrite=$(make -C $mk_dir -s use-source-dir-of 2>/dev/null)    

    if [[ $? == 0 ]]; then
	echo "$EXTRA attempting to use source directory of target=$srcdir_overwrite"
	
	local tmp_mk
	local tmp_mk_dir
	local tmp_target
	
	tmp_mk=$mk
	tmp_mk_dir=$mk_dir
	tmp_target=$target

	target=$srcdir_overwrite
	checkget_target "get_source"
	if [[ $? != 0 ]]; then
	    mk=$tmp_mk
	    mk_dir=$tmp_mk_dir
	fi
    fi

    local version
    version=$(make -C $mk_dir -s get-version)

    if [[ $? != 0 ]]; then
	echo "$ERROR Could not get version number"
	return 6
    fi
    
    local tar_basename
    local tar_path
    local tar_patch_path
    
    basename="$target-$version"
    srcdir="$mk_dir/$basename"
    tar_path="$srcdir.tar"
    patch_path="$srcdir.patch"
    
    echo "$EXTRA attempting to get source directory for $basename.tar"
    
    if [ -d $srcdir ]; then
	if [[ $tmp_mk != "" ]]; then
	    mk=$tmp_mk
	    mk_dir=$tmp_mk_dir
	fi
	
	echo "$EXTRA found source directory: $srcdir"
	return 0
    fi
    
    if [[ $1 == "clean" ]]; then
	echo "$EXTRA will not download sources for clean operation"
	return 8
    fi
    
    if [ ! -e $tar_path ]; then
	local urls
	urls=($(make -C $mk_dir -s get-urls))
	
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
    fi
    
    if [ -e $tar_path ]; then
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
	
	echo "$EXTRA extracted $basename.tar"
	if [ -e $tar_patch_path ]; then
	    cd $srcdir && patch -f -p1 < $patch_path
	    if [[ $? != 0 ]]; then
		echo "$ERROR Failed to patch $basename"
		rm -rf $srcdir
		return 4
	    fi
	fi
    else
	echo "$ERROR Could not find source archive for target=$target"
	return 2
    fi

    if [ ! -d $ARC_SOURCE_DIR ]; then
	echo "$ERROR Failed to create source directory for target=$target"
	return 1
    fi

    if [[ $tmp_mk != "" ]]; then
	mk=$tmp_mk
	mk_dir=$tmp_mk_dir
    fi
    
    return 0
}

build_deps() {
    local deps
    deps=($(make -C $mk_dir -s get-deps))
    
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
    local mk_dir
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
    ARC_SOURCE_DIR=$srcdir make -C $mk_dir build > $mk_dir/Makefile.log

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
    
    local mk_dir
    checkget_target "clean"

    if [[ $? != 0 ]]; then
	operation_suffix "clean" 1
	return $?
    fi

    rm -f $mk_dir/*.complete $mk_dir/*.fail
    
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
	ARC_SOURCE_DIR=$srcdir make -C $mk_dir prepare-rebuild > $mk_dir/Makefile.log
    else
	ARC_SOURCE_DIR=$srcdir make -C $mk_dir clean > $mk_dir/Makefile.log
    fi

    operation_suffix "clean" $?
    return $?
}

mkpatch() {
    local target
    target="$1"
    
    local mk_dir
    checkget_target "mkpatch"

    if [[ $? != 0 ]]; then
	operation_suffix "mkpatch" 1
	return $?
    fi
    
    local ARC_SOURCE_DIR
    get_source "mkpatch"

    if [[ $? != 0 ]]; then
	operation_suffix "mkpatch" 2
	return $?
    fi
    
    # TODO: Maybe use git format-patch?
    echo "$EXTRA creating patch"
    cd $ARC_SOURCE_DIR && \
	git diff $version HEAD -p > ../$target-$version.patch 2> ../git.errors
    
    operation_suffix "mkpatch" $?
    return $?
}

mux() {
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
	mux $@
    done
}

main $@
