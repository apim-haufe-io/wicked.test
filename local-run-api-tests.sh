#!/bin/bash

export DOCKER_PREFIX=local_
export DOCKER_TAG=dev

set -e

rm -f docker-api.log
thisPath=`pwd`

echo Docker logs go into docker-api.log.

pushd ../wicked.portal-env
echo Building Environment docker image...
docker build -t ${DOCKER_PREFIX}portal-env:${DOCKER_TAG}-onbuild . >> $thisPath/docker-api.log 
popd

pushd ../wicked.portal-api
echo Building API docker image...
perl -pe 's;(\\*)(\$([a-zA-Z_][a-zA-Z_0-9]*)|\$\{([a-zA-Z_][a-zA-Z_0-9]*)\})?;substr($1,0,int(length($1)/2)).($2&&length($1)%2?$2:$ENV{$3||$4});eg' Dockerfile.template > Dockerfile
docker build -t ${DOCKER_PREFIX}portal-api:${DOCKER_TAG} . >> $thisPath/docker-api.log
popd


perl -pe 's;(\\*)(\$([a-zA-Z_][a-zA-Z_0-9]*)|\$\{([a-zA-Z_][a-zA-Z_0-9]*)\})?;substr($1,0,int(length($1)/2)).($2&&length($1)%2?$2:$ENV{$3||$4});eg' base/Dockerfile.template > base/Dockerfile
perl -pe 's;(\\*)(\$([a-zA-Z_][a-zA-Z_0-9]*)|\$\{([a-zA-Z_][a-zA-Z_0-9]*)\})?;substr($1,0,int(length($1)/2)).($2&&length($1)%2?$2:$ENV{$3||$4});eg' local-compose-api.yml.template > local-compose-api.yml

echo Building Test base container...
pushd base
docker build -t wickedportaltest_test-base . >> $thisPath/docker-api.log
popd

echo Building Test container...
docker-compose -f local-compose-api.yml build >> $thisPath/docker-api.log
echo Running API test containers...
docker-compose -f local-compose-api.yml up --abort-on-container-exit > api-test.log
echo Copying test results...
docker cp wickedportaltest_api-test-data_1:/usr/src/app/test_results .
echo Taking down Test containers...
docker-compose -f local-compose-api.yml down >> $thisPath/docker-api.log

cat test_results/api-test.log

echo Detailed logs are in api-test.log.

echo Done.