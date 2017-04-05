
# Run some CI tests on the latest vg docker image

# https://quay.io/repository/vgteam/vg?tag=latest&tab=tags

# using toil-vg

# https://github.com/BD2KGenomics/toil-vg

# This script is hooked into 

# http://jenkins.cgcloud.info

# and is run after each push to this repository (vg_docker), after a time delay which
# allows Travis to do its thing and build the docker image first.  A cleaner alternative
# would be to have Travis trigger Jenkins at the end of ./build.sh but it seems easier
# now to be able to piggy back on the GitHub hooks where credentials are already set up.

# Most of the setup here is cribbed from other cgcloud jenkins projects such as toil-vg
# itself

#!/bin/bash

usage() { printf "Usage: $0 [Options] \nOptions:\n\t-b <B>\t Build vg branch B locally and do not use Docker\n" 1>&2; exit 1; }

while getopts "b:" o; do
    case "${o}" in
        b)
            BRANCH=$OPTARG
            ;;
        *)
            usage
            ;;
    esac
done

shift $((OPTIND-1))

# Maximum number of minutes that can have passed since new vg docker image built
MAX_MINUTES_ELAPSED=6000000
NUM_CORES=`cat /proc/cpuinfo | grep "^processor" | wc -l`
# Create Toil venv
rm -rf .env
virtualenv  .env
. .env/bin/activate

# Prepare directory for temp files (assuming cgcloud file structure)
if [ -d "/mnt/ephemeral" ]
then
	 TMPDIR=/mnt/ephemeral/tmp
	 rm -rf $TMPDIR
	 mkdir $TMPDIR
	 export TMPDIR
fi

# Create s3am venv
rm -rf s3am
virtualenv --never-download s3am && s3am/bin/pip install s3am==2.0
mkdir -p bin
# Expose binaries to the PATH
ln -snf ${PWD}/s3am/bin/s3am bin/
export PATH=$PATH:${PWD}/bin

# Create awscli venv
rm -rf awscli
virtualenv --never-download awscli && awscli/bin/pip install awscli
# Expose binaries to the PATH
ln -snf ${PWD}/awscli/bin/aws bin/
export PATH=$PATH:${PWD}/bin

# Dependencies for running tests.  Need numpy, scipy and sklearn
# for running toil-vg mapeval, and dateutils and reqests for ./mins_since_last_build.py
pip install numpy scipy sklearn dateutils requests timeout_decorator pytest boto

# Install toil-vg itself
pip install toil[aws,mesos] toil-vg

# we pass some parameters through pytest by way of our config file
# in particular, we set the vg version and cores, and specify
# that we want to keep all the results in vgci-work/
printf "cores ${NUM_CORES}\n" > vgci_cfg.tsv
printf "teardown False\n" >> vgci_cfg.tsv
printf "workdir ./vgci-work\n" >> vgci_cfg.tsv
#printf "verify False\n" >> vgci_cfg.tsv
#printf "baseline ./vgci-baseline\n" >> vgci_cfg.tsv


# if no branch specified, we look for a new docker image
if [ -z ${BRANCH+x} ]
then
	# We only proceed if we have a new docker image to use
	QUAY_TAG=`python ./quay_tag_info.py vgteam/vg --max-age $MAX_MINUTES_ELAPSED`
	if [ "$?" -eq 0 ] && [ "${#QUAY_TAG}" -ge 10 ]
	then
		 VG_VERSION=`docker run ${QUAY_TAG} vg version`
		 printf "vg-docker-version ${QUAY_TAG}\n" >> vgci_cfg.tsv
	else
		 echo "Could not find vg docker image younger than ${MAX_MINUTES_ELAPSED} minutes"
		 exit 1
	fi
# otherwise, we build a local vg for the given branch
else
	 git clone https://github.com/vgteam/vg.git --branch $BRANCH --recursive ./vg.local
	 pushd ./vg.local
	 . source_me.sh	 
	 make -j ${NUM_CORES} ; make
	 VG_VERSION=`vg version`
	 # disable docker (which is on bydefault)
	 printf "vg-docker-version None\n" >> vgci_cfg.tsv
	 popd	 
fi

# run the tests, output the junit report for Jenkins
pytest -vv ./vgci.py --junitxml=test-report.xml

# we publish the results to the archive
tar czf "${VG_VERSION}_output.tar.gz" ./vgci-work ./test-report.xml ./vgci.py ./jenkins.sh ./vgci_cfg.tsv
aws s3 cp "${VG_VERSION}_output.tar.gz" s3://glennhickey-vgci-output/


# if success, we publish results to the baseline
# todo : sync to s3

# clean working copy to satisfy corresponding check in Makefile
rm -rf bin awscli s3am

rm -rf .env
if [ -d "/mnt/ephemeral" ]
then
	 rm -rf $TMPDIR
fi
