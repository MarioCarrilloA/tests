#!/bin/bash

#  Copyright (C) 2017 Intel Corporation
#
#  This program is free software; you can redistribute it and/or
#  modify it under the terms of the GNU General Public License
#  as published by the Free Software Foundation; either version 2
#  of the License, or (at your option) any later version.
#
#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
#
#  You should have received a copy of the GNU General Public License
#  along with this program; if not, write to the Free Software
#  Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
#
# Description:
#  This will measure latency when we do a ping from one container to another:
#  (docker <-> docker).
#
#  This script will perform all the measurements using a local setup.

set -e

# General env
SCRIPT_PATH=$(dirname "$(readlink -f "$0")")
source "${SCRIPT_PATH}/lib/network-common.bash"
source "${SCRIPT_PATH}/../lib/common.bash"
TEST_NAME="network ping latency"

# Containers env
IMAGE="busybox"
ITERATIONS="$1"

# Workload configuration
NUM_PACKETS=10
SERVER_EXTRA_ARGS="-i"
CLIENT_EXTRA_ARGS="-ti --rm"
SERVER_CMD="sh"

# 1 iteration by default
if [ -z "$ITERATIONS" ]; then
	ITERATIONS=1
fi

# Initialize/clean environment
init_env

# Launch server and get its IP address
SERVER_ADDR="$(start_server "$IMAGE" "$SERVER_CMD" "$SERVER_EXTRA_ARGS")"
CLIENT_CMD="ping -c $NUM_PACKETS $SERVER_ADDR"

if [ -z "$SERVER_ADDR" ]; then
	die "server: ip address no found"
fi

echo "Executing test: $TEST_NAME"
for i in $(seq 1 "$ITERATIONS"); do
	# Launch container client, it will ping to the server address
	RESULT=$(start_client "$IMAGE" "$CLIENT_CMD" "$CLIENT_EXTRA_ARGS")
	if [ -z "$RESULT" ]; then
		die "client: results no found"
	fi

	# Get latency average
	LATENCY_AVG="$(echo "$RESULT" | grep "avg" | awk -F"/" '{print $4}')"
	echo "Ping latency average: $LATENCY_AVG"

	#Save results
	save_results "$TEST_NAME" "" "$LATENCY_AVG" "ms"
done

clean_env
echo "Finish"
