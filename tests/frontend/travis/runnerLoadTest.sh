#!/bin/bash

# do not continue if there is an error
set -eu

# source: https://stackoverflow.com/questions/59895/get-the-source-directory-of-a-bash-script-from-within-the-script-itself#246128
MY_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"

# reliably move to the etherpad base folder before running it
cd "${MY_DIR}/../../../"

# Set "points": 10 to 1000 to not agressively rate limit commits
sed 's/\"points\": 10/\"points\": 1000/g' settings.json.template > settings.json.points
# And enable loadTest
sed 's/\"loadTest\": false,/\"loadTest\": true,/g' settings.json.points > settings.json

# start Etherpad, assuming all dependencies are already installed.
#
# This is possible because the "install" section of .travis.yml already contains
# a call to bin/installDeps.sh
echo "Running Etherpad directly, assuming bin/installDeps.sh has already been run"

node node_modules/ep_etherpad-lite/node/server.js "${@}" > /dev/null &

echo "Now I will try for 15 seconds to connect to Etherpad on http://localhost:9001"

# wait for at most 15 seconds until Etherpad starts accepting connections
#
# modified from:
# https://unix.stackexchange.com/questions/5277/how-do-i-tell-a-script-to-wait-for-a-process-to-start-accepting-requests-on-a-po#349138
#
(timeout 15 bash -c 'until echo > /dev/tcp/localhost/9001; do sleep 0.5; done') || \
    (echo "Could not connect to Etherpad on http://localhost:9001" ; exit 1)

echo "Successfully connected to Etherpad on http://localhost:9001"

# Build the minified files?
curl http://localhost:9001/p/minifyme -f -s > /dev/null

# just in case, let's wait for another 10 seconds before going on
sleep 10

# run the backend tests
echo "Now run the load tests for 25 seconds and if it stalls before 100 then error"
etherpad-loadtest -d 25
exit_code=$?

kill $!
sleep 5

exit $exit_code
