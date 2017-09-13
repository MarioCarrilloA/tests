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
#  Measures cpu % consumption using an inter (docker<->docker)
#  network bandwidth using iperf2
#  this metrics test will measures the  cpu % consumption while
#  running bandwidth measurements

set -e

# General env
SCRIPT_PATH=$(dirname "$(readlink -f "$0")")
source "${SCRIPT_PATH}/lib/network-common.bash"
source "${SCRIPT_PATH}/../lib/common.bash"
TEST_NAME="network cpu consumption"

# Containers env
IMAGE="gabyct/network"
ITERATIONS="$1"

# Set QEMU_PATH unless it's already set
QEMU_PATH=${QEMU_PATH:-$(get_qemu_path)}

# Workload configuration
PORT="5001:5001"
TRANSMIT_TIME=16
STABILIZING_TIME=8
SERVER_CMD="iperf -p $PORT -s"
CLIENT_NAME="iperf-client"
CLIENT_EXTRA_ARGS="--name=${CLIENT_NAME} -d"

# 1 iteration by default
if [ -z "$ITERATIONS" ]; then
	ITERATIONS=1
fi

# Check the runtime in order to determine which process will
# be measured about cpu %
if [ "$RUNTIME" == "runc" ]; then
	PROCESS="iperf"

elif [ "$RUNTIME" == "cor" ] || [ "$RUNTIME" == "cc-runtime" ]; then
	PROCESS="$QEMU_PATH"
else
	die "Unknown runtime: $RUNTIME"
fi

# Initialize/clean environment
init_env

# Launch server and get its IP address
echo "Start server"
SERVER_ADDR="$(start_server "$IMAGE" "$SERVER_CMD")"
CLIENT_CMD="iperf -c $SERVER_ADDR -t $TRANSMIT_TIME"

if [ -z "$SERVER_ADDR" ]; then
	die "server: ip address no found"
fi

echo "Executing test: $TEST_NAME"
for i in $(seq 1 "$ITERATIONS"); do
	# Launch container client
	start_client "$IMAGE" "$CLIENT_CMD" "$CLIENT_EXTRA_ARGS"

	# Measurement after client and server are more stable
	echo "WARNING: sleeping for $STABILIZING_TIME seconds in"
	echo "order to have server and client stable"
	sleep $STABILIZING_TIME

	PID=$(pidof $PROCESS)
	CPU_CONSUMPTION=$(ps --no-headers -o %cpu -p $PID | \
			awk '{ total+= $1 } END { print total/NR }')

	echo "CPU % consumption: $CPU_CONSUMPTION"

	# Save results
	save_results "$TEST_NAME" "" "$CPU_CONSUMPTION" "%"

	# Clean the client container for N iterations
	if [ "$ITERATIONS" -ne "1" ]; then
		$DOCKER_EXE rm -f "$CLIENT_NAME"
	fi
done

clean_env
echo "Finish"
