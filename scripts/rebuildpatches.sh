#!/bin/bash
# get base dir regardless of execution location
SOURCE="${BASH_SOURCE[0]}"
while [ -h "$SOURCE" ]; do # resolve $SOURCE until the file is no longer a symlink
	DIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"
	SOURCE="$(readlink "$SOURCE")"
	[[ ${SOURCE} != /* ]] && SOURCE="$DIR/$SOURCE" # if $SOURCE was a relative symlink, we need to resolve it relative to the path where the symlink file was located
done
. $(dirname ${SOURCE})/init.sh

PS1="$"
echo "Rebuilding patch files from current fork state..."
function savePatches {
	what=$1
	cd ${basedir}/${what}/

	mkdir -p ${basedir}/patches/$2
	if [ -d ".git/rebase-apply" ]; then
		# in middle of a rebase, be smarter
		echo "REBASE DETECTED - PARTIAL SAVE"
		last=$(cat ".git/rebase-apply/last")
		next=$(cat ".git/rebase-apply/next")
		declare -a files=("$basedir/patches/$2/"*.patch)
		for i in $(seq -f "%04g" 1 1 ${last})
		do
			if [ ${i} -lt ${next} ]; then
				rm "${files[`expr ${i} - 1`]}"
			fi
		done
	else
		rm ${basedir}/patches/$2/*.patch
	fi

	git format-patch --quiet -N -o ${basedir}/patches/$2 upstream/upstream
	cd ${basedir}
	git add -A ${basedir}/patches/$2
	cleanupPatches ${basedir}/patches/$2/
	echo "  Patches saved for $what to patches/$2"
}

savePatches ${FORK_NAME}-API api
if [ -f "$basedir/${FORK_NAME}-API/.git/patch-apply-failed" ]; then
	echo "$(bashColor 1 31)[[[ WARNING ]]] $(bashColor 1 33)- Not saving Tuinity-Server as it appears ${FORK_NAME}-API did not apply clean.$(bashColorReset)"
	echo "$(bashColor 1 33)If this is a mistake, delete $(bashColor 1 34)${FORK_NAME}-API/.git/patch-apply-failed$(bashColor 1 33) and run rebuild again.$(bashColorReset)"
	echo "$(bashColor 1 33)Otherwise, rerun ./tuinity patch to have a clean Tuinity-API apply so the latest Tuinity-Server can build.$(bashColorReset)"
else
	savePatches ${FORK_NAME}-Server server
	${basedir}/scripts/push.sh
fi

