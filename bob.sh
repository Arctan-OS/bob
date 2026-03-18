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

build() {
    local target
    local parent
    
    target="$1"
    parent="$2"
    
    if [[ $target == "" ]]; then
	return 0
    fi
    
    local mk
    mk=$(find ./targets/ -type f -wholename "./targets/$target/Makefile")

    if [[ $mk == "" ]]; then
	echo "$ERROR Could not find Makefile for target=$target"
	return -1
    fi
    
    echo "$INFO Entering $target (parent=$parent):"

    local complete
    complete=$(find ./targets/ -type f -wholename "./targets/$target/build.complete")
    
    if [[ $complete != "" ]]; then
	echo "$EXTRA target already built, skipping"
	return 0
    fi
    
    local mk_dir
    mk_dir=$(dirname $mk)

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

    echo "$INFO Building $target"
    make -C $mk_dir build > $mk_dir/Makefile.log
    
    local retcode
    retcode=$?
    echo "$EXTRA retcode=$retcode"

    if [[ $retcode == 0 ]]; then
	touch $mk_dir/build.complete
    fi
    
    return $retcode
}

clean() {
    local target
    local parent
    
    target="$1"
    parent="$2"
    
    if [[ $target == "" ]]; then
	return 0
    fi
    
    local mk
    mk=$(find ./targets/ -type f -wholename "./targets/$target/Makefile")

    if [[ $mk == "" ]]; then
	echo "$ERROR Could not find Makefile for target=$target"
	return -1
    fi
    
    local mk_dir
    mk_dir=$(dirname $mk)

    rm -f $mk_dir/build.complete

    if [[ $2 == "rebuild" ]]; then
	make -C $mk_dir prepare-rebuild > $mk_dir/Makefile.log
    else
	make -C $mk_dir clean > $mk_dir/Makefile.log
    fi

    return $?
}

mkpatch() {
    local target
    local parent
    
    target="$1"
    parent="$2"
    
    if [[ $target == "" ]]; then
	return 0
    fi
    
    local mk
    mk=$(find ./targets/ -type f -wholename "./targets/$target/Makefile")

    if [[ $mk == "" ]]; then
	echo "$ERROR Could not find Makefile for target=$target"
	return -1
    fi
    
    echo "$INFO Entering $target (parent=$parent):"
    
    local mk_dir
    mk_dir=$(dirname $mk)

    local version
    version=$(make -C $mk_dir -s get-version)
    echo "$EXTRA version=$version"

    # TODO: Maybe use git format-patch?
    echo "$EXTRA creating patch"
    git diff $version HEAD -p > $mk_dir/$target-$version.patch 2> $mk_dir/git.errors
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
    
    if [[ $? != 0 ]]; then
	echo "$ERROR Failed to $1 target=$target"
    fi
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
