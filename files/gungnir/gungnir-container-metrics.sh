#!/bin/sh
# Emit each container's Docker lifecycle state for node_exporter's textfile
# collector. Read-only: it inspects the Docker engine and never changes a
# container. cAdvisor (already scraped by Alloy) can only tell a running
# container from a gone one; this asks `docker ps -a` for the real state, so
# gungnir can show paused / restarting / exited.
#
# One `gungnir_container_state{name,state} 1` line per container, where `name`
# matches the roster name gungnir keeps: a compose container is reported as
# "<project>-<service>" (dropping the replica number, the normalization gungnir
# applies to the cAdvisor name), a standalone container under Docker's name. The
# gungnir_* name is the product's, not instance-specific; whichever store this
# box ships to reads it. Writes into the same textfile dir the gungnir_security
# exporter in config.alloy scrapes, so no extra Alloy wiring is needed.
set -u
OUT="/var/lib/alloy/textfile/gungnir_container_state.prom"
TMP="${OUT}.$$"
: > "${TMP}"
emit() { printf '%s\n' "$*" >> "${TMP}"; }

emit '# HELP gungnir_container_state A container the Docker engine currently knows, labelled with its lifecycle state.'
emit '# TYPE gungnir_container_state gauge'

# No Docker, or the daemon is down: leave an (almost) empty sample so the series
# goes stale and gungnir falls back to its cAdvisor view rather than a torn file.
if ! command -v docker >/dev/null 2>&1 || ! docker info >/dev/null 2>&1; then
	mv "${TMP}" "${OUT}"
	chmod 0644 "${OUT}"
	exit 0
fi

# Tab-separated (docker's --format processes \t): a container name and the
# compose labels never contain a tab, so the fields stay intact.
docker ps -a --no-trunc \
	--format '{{.Names}}\t{{.State}}\t{{.Label "com.docker.compose.project"}}\t{{.Label "com.docker.compose.service"}}' \
	2>/dev/null | while IFS="$(printf '\t')" read -r name state project service; do
	[ -n "${name}" ] || continue

	# Normalize a compose replica to "<project>-<service>", matching gungnir.
	if [ -n "${project}" ] && [ -n "${service}" ]; then
		name="${project}-${service}"
	fi

	# Collapse Docker's states onto the ones gungnir stores. created / dead /
	# removing all mean "not running and not a live pause/restart", so exited.
	case "${state}" in
		running)    s="running" ;;
		paused)     s="paused" ;;
		restarting) s="restarting" ;;
		*)          s="exited" ;;
	esac

	# Escape a double quote or backslash in the (rare) awkward container name.
	esc=$(printf '%s' "${name}" | sed 's/\\/\\\\/g; s/"/\\"/g')
	emit "gungnir_container_state{name=\"${esc}\",state=\"${s}\"} 1"
done

mv "${TMP}" "${OUT}"
chmod 0644 "${OUT}"
