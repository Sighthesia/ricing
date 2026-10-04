#!/usr/bin/env bash
# Shell boot check — start (or attach to) Afloat and report what went wrong.
#
# Why this exists instead of the test suite:
#
#   This is a desktop shell. Most of what breaks is not a pure function you can
#   assert on — it is a binding that dereferences null, an asset that will not
#   open, a service that fails to write a file — and each of those exists only
#   once the real singletons, the real compositor and the real assets are wired
#   together. The suite never saw them: reading the live shell's log found a
#   NiriService that could not write its kdl file, an Image that could not open a
#   lock asset, and two TypeErrors in the same window-hint file — none of which
#   any test asserted.
#
#   So the default verification is: run the shell, read its log, judge the
#   warnings and errors. The suite stays available for logic with no runtime
#   (scripts/run-tests.sh), but it is no longer the gate for every change.
#
# What it deliberately does NOT do: start a second shell over a live one. Two
# instances paint two bars and two wallpapers, and the session lock belongs to one
# of them. Restart your own shell, then run this.
#
# Usage:
#   scripts/check-shell.sh                 # what has gone wrong since last time
#   scripts/check-shell.sh --all           # the whole log, ignoring the checkpoint
#   scripts/check-shell.sh --watch         # follow the live shell, print as it happens
#   scripts/check-shell.sh --launch 20     # no shell running? start one for 20s
#   scripts/check-shell.sh --top 30        # lines per bucket (default 15)
#   scripts/check-shell.sh --env           # also list the environment noise

set -uo pipefail

REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT" || exit 1

TOP=15
WATCH=0
ALL=0
LAUNCH=0
SHOW_ENV=0
LAUNCH_SECONDS=20

while [ $# -gt 0 ]; do
    case "$1" in
        --all)    ALL=1 ;;
        --env)    SHOW_ENV=1 ;;
        --watch)  WATCH=1 ;;
        --top)    shift; TOP=${1:-15} ;;
        --launch) LAUNCH=1
                  case "${2:-}" in ''|--*) ;; *) shift; LAUNCH_SECONDS=${1:-20} ;; esac
                  ;;
        -h|--help) sed -n '/^# Usage:/,/^$/p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
                   exit 0 ;;
        *) echo "unknown option: $1" >&2; exit 2 ;;
    esac
    shift
done

# The checkpoint lives in the git dir: never tracked, never a stray file in the
# worktree, and --git-common-dir keeps it correct inside a linked worktree.
GIT_COMMON="$(git rev-parse --git-common-dir 2>/dev/null || echo .git)"
OFFSET_FILE="$GIT_COMMON/afloat-shell-check.offset"

# ---------------------------------------------------------------- locating
# The live shell's log is found through its own open file descriptors: the by-id
# directory name is random and other projects' shells log there too, so picking
# by mtime would report someone else's warnings as ours.
find_live_shell() {
    local pid
    for pid in $(pgrep -f "qs .*-p .*$(basename "$REPO_ROOT")" 2>/dev/null); do
        [ "$pid" = "$$" ] && continue
        ls -l "/proc/$pid/fd" 2>/dev/null | grep -oE "/run/user/[^ ]*qslog" | head -1
    done | head -1
}

# ---------------------------------------------------------------- classifying
# The .qslog is Qt's binary message format, so its level names are meta-type tags
# rather than literal WARN/ERROR text and cannot be grepped for. The message bodies
# are plain, so those are what get classified — into three buckets, because one
# flat list buries the two lines that matter under forty Bluetooth timeouts.
#
#   [qml]     QML/JS diagnostics that name a file in this repo
#   [service] one of our own services reporting a failure
#   [env]     the machine: bluetooth, pipewire, fonts, tooling notices
classify() {
    local log=$1 start=${2:-1} limit=${3:-}
    if [ -n "$limit" ]; then
        tail -c "+$start" "$log" 2>/dev/null | head -c "$limit"
    else
        tail -c "+$start" "$log" 2>/dev/null
    fi | strings -n 8 | sed 's/^[[:space:]]*//' | grep -av '^$' | awk '
    {
        line = $0
        low = tolower(line)

        # mawk will not let a regex literal span lines, so these are assigned
        # rather than inlined into one long condition.
        has_repo    = (low ~ /@modules\/|@services\/|@tests\/|file:\/\/[^ ]*afloat\/|\.qml\[[0-9]+[:\-][0-9]*\]/)
        has_problem = (low ~ /error|warning|warn:|failed|cannot|unable|typeerror|referenceerror|is not a|binding loop|invalid|null|undefined|assert|exposed/)

        # Noise is matched first so it can never claim a line about our files.
        if (low ~ /bluetooth|bluez|br-connection|pipewire|wireplumber|pwlink|pwnode|pwobj|networkmanager|nmcli|udev|bluez/) {
            bucket = "env"; reason = "hardware / service chatter"
        }
        else if (low ~ /passing through intercept|membfd|logger initialized|not enabling qml tooling|qmlls\.ini|saving logs|shell id|launching config|configuration loaded|scanning |no rules/) {
            bucket = "env"; reason = "tooling notice"
        }
        # A repo path alone proves nothing: the engine logs every QUrl it
        # redirects, so requiring only that buried two real TypeErrors under 200
        # "Passing through intercept" lines. Needs a repo reference AND a problem.
        else if (has_repo && has_problem) {
            bucket = "qml"; reason = "QML/JS diagnostic naming a repo file"
        }
        # Deliberately no bare "failed to load" here: the PipeWire "Failed to load
        # configuration" line is not a QML error, and counting it as one buried 14
        # phantom problems into every report. (No apostrophes in this comment:
        # the whole awk program lives inside one pair of shell single quotes.)
        else if (low ~ /typeerror|referenceerror|cannot read property|cannot open|binding loop|unable to assign|is not a type|is not a function|exception occurred/) {
            bucket = "qml"; reason = "QML / JS error"
        }
        # No leading anchor: the binary log prefixes fragments onto the text, so
        # "4NiriService: failed to ..." would never match a ^Service pattern.
        else if (line ~ /[A-Za-z0-9]+(Service|Controller): .*(failed|error|cannot|unable|refused)/) {
            bucket = "service"; reason = "our service reporting a failure"
        }
        else if (has_problem) {
            bucket = "env"; reason = "unclassified, mentions a problem word"
        }
        else next

        # The binary log interleaves fragments; keep only lines that look whole.
        if (length(line) < 12) next
        count[bucket "\t" line]++
        why[bucket "\t" line] = reason
        if (!(bucket in seen)) { order[bucket] = ++nb; seen[bucket] = 1 }
    }
    END {
        # for (x in arr) walks the INDICES, not the values, so the bucket names
        # have to be read out by index — iterating the split directly reported
        # buckets named "1", "2", "3" and matched nothing, which reads as a
        # clean log. Walk them by index in a fixed order instead.
        nbuckets = split("qml service env", buckets, " ")
        for (bi = 1; bi <= nbuckets; bi++) {
            b = buckets[bi]
            n = 0
            for (k in count) { split(k, p, "\t"); if (p[1] == b) n++ }
            printf("@@BUCKET\t%s\t%d\n", b, n)
            for (k in count) {
                split(k, p, "\t")
                if (p[1] != b) continue
                printf("@@LINE\t%s\t%d\t%s\t%s\n", b, count[k], p[2], why[k])
            }
        }
    }'
}

report() {
    local log=$1 start=$2 limit=$3 label=$4
    local out total_qml total_service total_env rc=0 bucket n
    out=$(classify "$log" "$start" "$limit")

    # A classifier that dies (a bad regex, a missing binary) produces no output,
    # and "no output" is indistinguishable from "nothing wrong" unless it is
    # checked. Worse, a classifier that runs but mislabels produces output whose
    # *shape* is right and whose content is empty — also indistinguishable from
    # clean. So check the semantics, not the structure: the three known bucket
    # names must all be present. This script exists to catch silent breakage; it
    # must not be the one doing it silently.
    # Herestring, not a pipeline: `grep -q` exits at the first match, printf takes
    # SIGPIPE, and under `pipefail` that turns a successful match into a failed
    # pipeline — which `!` would then report as "output unusable".
    if ! grep -qE '^@@BUCKET[[:space:]]+(qml|service|env)[[:space:]]' <<<"$out"; then
        printf '\n\033[1m%s\033[0m\n' "$label"
        if [ ! -s "$log" ]; then
            printf '  \033[33mlog is empty — the shell may not have flushed yet\033[0m\n'
            return 2
        fi
        printf '  \033[31mclassifier output is not usable\033[0m — treating as a failure, not as "clean"\n'
        printf '  raw: %s\n' "$(printf '%s\n' "$out" | head -3 | tr '\t' ' ' | tr '\n' '|')"
        return 2
    fi

    total_qml=$(printf '%s\n' "$out" | awk -F'\t' '$1=="@@BUCKET" && $2=="qml" {print $3}' | tail -1)
    total_service=$(printf '%s\n' "$out" | awk -F'\t' '$1=="@@BUCKET" && $2=="service" {print $3}' | tail -1)
    total_env=$(printf '%s\n' "$out" | awk -F'\t' '$1=="@@BUCKET" && $2=="env" {print $3}' | tail -1)
    : "${total_qml:=0}" "${total_service:=0}" "${total_env:=0}"

    printf '\n\033[1m%s\033[0m\n' "$label"
    printf '  %s\n' "$log"

    if [ "$total_qml" -eq 0 ] && [ "$total_service" -eq 0 ]; then
        printf '  \033[32mno QML errors, no service failures\033[0m'
        [ "$total_env" -gt 0 ] && printf '  (%s environment line(s) ignored)' "$total_env"
        printf '\n'
    else
        rc=1
        [ "$total_qml" -gt 0 ] && printf '  \033[31m%s QML problem(s)\033[0m\n' "$total_qml"
        [ "$total_service" -gt 0 ] && printf '  \033[31m%s service failure(s)\033[0m\n' "$total_service"
    fi

    for bucket in qml service env; do
        n=$(printf '%s\n' "$out" | awk -F'\t' -v b="$bucket" '$1=="@@BUCKET" && $2==b {print $3}' | tail -1)
        [ "${n:-0}" -eq 0 ] && continue
        if [ "$bucket" = env ] && [ "$SHOW_ENV" -eq 0 ]; then
            # Thousands of lines by construction: it exists to be counted, not read.
            printf '\n  \033[33m[env] %s line(s) ignored\033[0m (--env to list them)\n' "$n"
            continue
        fi
        if [ "$bucket" = env ]; then
            printf '\n  \033[33m[%s] %s unique line(s)\033[0m\n' "$bucket" "$n"
        else
            printf '\n  \033[31m[%s] %s unique line(s)\033[0m\n' "$bucket" "$n"
        fi
        printf '%s\n' "$out" | awk -F'\t' -v b="$bucket" '$1=="@@LINE" && $2==b {print}' \
            | sort -t"$(printf '\t')" -k3,3nr | head -"$TOP" \
            | awk -F'\t' '{printf "    %sx  %s\n         %s\n", $3, $4, $5}'
        [ "$n" -gt "$TOP" ] && printf '    ... and %s more\n' "$(( n - TOP ))"
    done
    return $rc
}

# ---------------------------------------------------------------- modes
if [ "$WATCH" -eq 1 ]; then
    log=$(find_live_shell)
    [ -z "$log" ] && { echo "check-shell: no running Afloat shell — start it, then retry" >&2; exit 2; }
    watch_state="$GIT_COMMON/afloat-shell-check.watch"
    [ -f "$watch_state" ] || printf '%s\n' "$(wc -c < "$log")" > "$watch_state"
    printf 'watching %s from byte %s (ctrl-c to stop)\n' "$log" "$(cat "$watch_state")"
    tail -f -c "+$(cat "$watch_state")" "$log" | strings -n 8 \
        | grep --line-buffered -aiE "typeerror|referenceerror|cannot read property|cannot open|is not a function|binding loop|failed to|cannot |unable " \
        | grep --line-buffered -aviE "bluetooth|bluez|br-connection|pipewire|wireplumber|pwlink|pwnode"
    exit 0
fi

if [ "$LAUNCH" -eq 1 ]; then
    if [ -n "$(find_live_shell)" ]; then
        cat >&2 <<'EOF'
check-shell: an Afloat shell is already running, so this refuses to start a
             second one — two instances paint two bars and two wallpapers, and
             the session lock belongs to one of them. Restart your own shell, then
             run scripts/check-shell.sh --watch from another terminal.
EOF
        exit 2
    fi
    out=$(mktemp)
    printf 'launching the shell for %ss — its surfaces will appear, that is the point\n' "$LAUNCH_SECONDS"
    timeout --kill-after=5 "$LAUNCH_SECONDS" qs -p "$REPO_ROOT" --no-color --log-times >"$out" 2>&1
    report "$out" 1 "" "fresh start, ${LAUNCH_SECONDS}s of shell output"
    rc=$?
    rm -f "$out"
    exit $rc
fi

log=$(find_live_shell)
[ -z "$log" ] && {
    cat >&2 <<'EOF'
check-shell: no running Afloat shell found.
             Start your own (qs -p .), then run scripts/check-shell.sh
             or scripts/check-shell.sh --watch from another terminal.
EOF
    exit 2
}

# Three read modes: the whole log, the delta since the checkpoint, or — on a
# first run with no checkpoint to resume from — the tail, because replaying 8 MB
# of accumulated history buries whatever just broke.
if [ "$ALL" -eq 1 ]; then
    report "$log" 1 "" "whole log"
elif [ -f "$OFFSET_FILE" ]; then
    report "$log" "$(cat "$OFFSET_FILE")" "" "since the last check"
else
    printf '  (first run — reading the last 256 KB; --all reads everything)\n' >&2
    report "$log" 1 262144 "log tail (no checkpoint yet)"
fi
rc=$?

# Record the position afterwards, so a failure while reporting replays the same
# window next time instead of skipping it.
printf '%s\n' "$(wc -c < "$log")" > "$OFFSET_FILE"
exit $rc