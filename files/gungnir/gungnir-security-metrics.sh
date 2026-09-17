#!/bin/sh
# Emit normalized security-layer metrics for node_exporter's textfile collector.
# Read-only: it inspects each layer's state and never changes it. Detects
# CrowdSec, fail2ban, CSF/LFD, ModSecurity and Imunify, emitting one presence
# gauge per layer plus a ban count (crowdsec/csf/fail2ban) or an event count
# (modsecurity) where the layer exposes one.
#
# The metric names are gungnir_security_* — the gungnir monitoring product's
# names, not tied to any single instance: whichever store this box ships to,
# that gungnir reads them. Nothing here is deployment-specific.
set -u
OUT="/var/lib/alloy/textfile/gungnir_security.prom"
TMP="${OUT}.$$"
: > "${TMP}"
emit() { printf '%s\n' "$*" >> "${TMP}"; }
have() { command -v "$1" >/dev/null 2>&1; }
active() { systemctl is-active --quiet "$1" 2>/dev/null; }
num() { printf '%s' "${1:-0}" | tr -dc '0-9'; }

emit '# HELP gungnir_security_present A security layer is installed and active (1).'
emit '# TYPE gungnir_security_present gauge'
emit '# HELP gungnir_security_active_bans Source IPs currently banned or denied.'
emit '# TYPE gungnir_security_active_bans gauge'
emit '# HELP gungnir_security_events Security events counted from local state/logs.'
emit '# TYPE gungnir_security_events gauge'

# ── CrowdSec ────────────────────────────────────────────────────────────
if have cscli && active crowdsec; then
	emit 'gungnir_security_present{layer="crowdsec"} 1'
	# From CrowdSec's Prometheus endpoint: the full enforced decision count (local
	# plus the community blocklists it pulls) and the alert counter (attacks it
	# detected). Falls back to the local decision list if the endpoint is down.
	# cs_active_decisions is the full enforced ban list; cs_bucket_overflowed_total
	# is a monotonic counter of detections (each overflow is a scenario firing) --
	# the right "threats" signal. cs_alerts is a pruning gauge, so it is not used.
	m=""
	have curl && m=$(curl -s --max-time 5 http://127.0.0.1:6060/metrics 2>/dev/null)
	bans=$(printf '%s' "${m}" | awk '/^cs_active_decisions{/ {s+=$2} END {printf "%d", s}')
	overflows=$(printf '%s' "${m}" | awk '/^cs_bucket_overflowed_total/ {s+=$2} END {printf "%d", s}')
	[ -n "${bans}" ] && [ "${bans}" != 0 ] || bans=$(cscli decisions list -o raw 2>/dev/null | tail -n +2 | grep -c . 2>/dev/null)
	emit "gungnir_security_active_bans{layer=\"crowdsec\"} $(num "${bans}")"
	# Always emit the events counter, even at 0: CrowdSec can report detections, so
	# a quiet box means "0 detected", not "no data". Omitting it here is what made
	# the board read "No sample" for a calm CrowdSec box instead of 0.
	emit "gungnir_security_events{layer=\"crowdsec\"} $(num "${overflows}")"
fi

# ── fail2ban ────────────────────────────────────────────────────────────
if have fail2ban-client && active fail2ban; then
	emit 'gungnir_security_present{layer="fail2ban"} 1'
	total=0
	jails=$(fail2ban-client status 2>/dev/null | sed -n 's/^.*Jail list:[[:space:]]*//p' | tr ',' ' ')
	for j in ${jails}; do
		[ -n "${j}" ] || continue
		b=$(fail2ban-client status "${j}" 2>/dev/null | sed -n 's/^.*Currently banned:[[:space:]]*//p')
		total=$((total + $(num "${b}")))
	done
	emit "gungnir_security_active_bans{layer=\"fail2ban\"} ${total}"
fi

# ── CSF / LFD ───────────────────────────────────────────────────────────
if have csf; then
	emit 'gungnir_security_present{layer="csf"} 1'
	perm=$(grep -cvE '^[[:space:]]*(#|$)' /etc/csf/csf.deny 2>/dev/null)
	temp=$(csf -t 2>/dev/null | grep -cE '([0-9]{1,3}\.){3}[0-9]{1,3}' 2>/dev/null)
	emit "gungnir_security_active_bans{layer=\"csf\"} $(( $(num "${perm}") + $(num "${temp}") ))"
fi

# ── ModSecurity (Apache module) ─────────────────────────────────────────
# Count denials from the LIVE Apache error log. The serial modsec_audit.log is
# stale on a Concurrent-logging box (cPanel), but ModSecurity's "Access denied"
# lines always land in the error log, which is the file that keeps growing.
if { httpd -M 2>/dev/null || apache2ctl -M 2>/dev/null || apachectl -M 2>/dev/null; } \
	| grep -qi security2; then
	emit 'gungnir_security_present{layer="modsecurity"} 1'
	log=""
	for f in /usr/local/apache/logs/error_log /var/log/apache2/error.log \
		/var/log/httpd/error_log /var/log/apache2/error_log; do
		[ -f "${f}" ] && grep -qm1 ModSecurity "${f}" 2>/dev/null && { log="${f}"; break; }
	done
	if [ -n "${log}" ]; then
		ev=$(grep -c 'ModSecurity: Access denied' "${log}" 2>/dev/null)
		emit "gungnir_security_events{layer=\"modsecurity\"} $(num "${ev}")"
	fi
fi

# ── Imunify (presence only; the CLI is too heavy to poll each minute) ────
if have imunify360-agent; then
	emit 'gungnir_security_present{layer="imunify360"} 1'
elif have imunify-antivirus; then
	emit 'gungnir_security_present{layer="imunifyav"} 1'
fi

mv "${TMP}" "${OUT}"
chmod 0644 "${OUT}"
