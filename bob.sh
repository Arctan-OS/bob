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

get_source() {
    local version
    version=$(make -C $mk_dir -s get-version)

    tar_basename=$target-$version
    ARC_SOURCE_DIR="$mk_dir/$target-$version"
    tar_path="$ARC_SOURCE_DIR.tar"
    tar_patch_path="$ARC_SOURCE_DIR.tar"
    
    echo "$EXTRA attempting to get source directory for  $tar_basename.tar"
    
    if [ -d $ARC_SOURCE_DIR ]; then
	echo "$EXTRA found source directory: $ARC_SOURCE_DIR"
	return 0
    fi
    
    if [ ! -e $tar_path ]; then
	local urls
	urls=($(make -C $mk_dir -s get-urls))
	
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
	tar -xf $tar_path
	if [[ $? != 0 ]]; then
	    echo "$EXTRA failed to extract $ARC_SOURCE_DIR.tar"
	    return 3
	fi
	
	echo "$EXTRA extracted $ARC_SOURCE_DIR.tar"
	if [ -e $tar_patch_path ]; then
	    cd $ARC_SOURCE_DIR && patch -p1 < $tar_patch_path
	    if [[ $? != 0 ]]; then
		echo "$EXTRA failed to patch $ARC_SOURCE_DIR"
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
    
    return 0
}

build_deps() {
    local deps
    deps=($(make -C $mk_dir -s get-deps))
    
    echo "$EXTRA deps=${deps[@]}"

    for dep in "${deps[@]}"; do
	if [[ $parent == $dep ]]; then
	    #revisit_queue+=$dep
	    echo "$WARN Circular dependency detected, building target=$target then parent=$parent"
	else
	    build $dep $target	    
	fi
    done

    return 0
}

checkget_target() {
    # $1 = function
    mk=$(find ./targets/ -type f -wholename "./targets/$target/Makefile")

    if [[ $mk == "" ]]; then
	echo "$ERROR Could not find Makefile for target=$target"
	return 1
    fi

    if [[ $1 == "build" ]]; then
	status=$(find ./targets/ -type f -wholename "./targets/$target/build.complete")
	
	if [[ $status != "" ]]; then
	    echo "$EXTRA target already built, skipping"
	    return 2
	fi

	status=$(find ./targets/ -type f -wholename "./targets/$target/build.fail")

	if [[ $status != "" ]]; then
	    echo "$EXTRA target already failed to build, skipping"
	    return 3
	fi
    fi
    
    mk_dir=$(dirname $mk)
    
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
    local ARC_SOURCE_DIR
    get_source

    if [[ $? != 0 ]]; then
	operation_suffix "build" 10
	return $?
    fi
    
    echo "$INFO Building target=$target"
    make -C $mk_dir build > $mk_dir/Makefile.log

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
    
    local mk_dir
    checkget_target "clean"

    if [[ $? != 0 ]]; then
	return -1
    fi
    
    rm -f $mk_dir/*.complete $mk_dir/*.fail

    if [[ $type == "rebuild" ]]; then
	make -C $mk_dir prepare-rebuild > $mk_dir/Makefile.log
    else
	make -C $mk_dir clean > $mk_dir/Makefile.log
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
    get_source

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
	targets=$(find ./targets/ -maxdepth 1 -type d -not -path "./targets/" -printf "%f\n")
    fi

    for target in $targets; do
	mux $@
    done
}

main $@
