#!/bin/bash

set -ex

cd $(dirname $0)

function build_packages() {
	git_tag=$1
	git_commit=$2

	project=$(basename $(git rev-parse --show-toplevel))
	docker stop "${project}-build" || true
	docker rm "${project}-build" || true

	mkdir -p ../releases/ && rm -f ../releases/*.deb

	docker build --build-arg="GIT_TAG=${git_tag}" --build-arg="GIT_COMMIT=${git_commit}" \
		 --no-cache -t "harbor.shopeemobile.com/ecp/${project}-build" -f build.dockerfile ../..
	docker run --name "${project}-build" "harbor.shopeemobile.com/ecp/${project}-build"
	docker cp "${project}-build":/workspace/releases/. ../releases/
	docker rm "${project}-build"

	ls -l ../releases/
}

function release_packages() {
	git_tag=$1
	git_commit=$2
	environment=$3

	package_version=$(echo ${git_tag} | sed -E 's/^v//')
	for debfile in ../releases/*_${package_version}_amd64.deb; do
		dpm upload -f ${debfile} -d focal,xenial,noble -v ${package_version} -c ${git_commit:0:8} -e ${environment} -u ${BUILD_USER_EMAIL:-xiangyu.lu@shopee.com} -p null
		sleep ${SHOPEE_BUILD_BASH_DPM_UPLOAD_SLEEP:-1}
	done
}

function main() {
	echo $(whoami)@$(ip addr show $(ip route get 10.0.0.1 | grep -oP 'dev \K\S+') | grep -oP ' inet \K[^/]+'):$(pwd)

	git_tag=$(git describe --tags)
	git_commit=$(git rev-parse HEAD)

	if [ "$BUILD_PACKAGES" == true ]; then
		build_packages ${git_tag} ${git_commit}
	fi

	if [ "$RELEASE_PACKAGES" == "dev" ]; then
		release_packages ${git_tag} ${git_commit} dev
	elif [ "$RELEASE_PACKAGES" == "test" ]; then
		release_packages ${git_tag} ${git_commit} test
	elif [ "$RELEASE_PACKAGES" == "live" ]; then
		release_packages ${git_tag} ${git_commit} live
	fi
}

main
