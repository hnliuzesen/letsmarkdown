#!/usr/bin/env bash
set -euo pipefail

image=${1:?Usage: deploy.sh IMAGE CONTAINER HOST_PORT}
container=${2:?Missing container name}
port=${3:?Missing host port}
backup="${container}-previous"

[[ "$container" =~ ^[a-zA-Z0-9][a-zA-Z0-9_.-]*$ ]]
[[ "$port" =~ ^[0-9]{1,5}$ ]]
(( 10#$port > 0 && 10#$port <= 65535 ))
command -v curl >/dev/null
docker info >/dev/null

# Leave the running container untouched if pulling fails.
docker pull "$image"
if docker container inspect "$backup" >/dev/null 2>&1; then
  echo "Container $backup already exists; resolve the previous deployment first." >&2
  exit 1
fi

old_saved=false
replacement_attempted=false
old_running=false
rollback() {
  status=$?
  trap - EXIT
  if (( status != 0 )); then
    echo "Deployment failed; restoring the previous container if present." >&2
    if $replacement_attempted; then
      docker logs --tail 50 "$container" >&2 || true
      docker rm -f "$container" || true
    fi
    if $old_saved; then
      docker rename "$backup" "$container"
      if $old_running; then
        docker start "$container"
      fi
    fi
  fi
  exit "$status"
}
trap rollback EXIT

if docker container inspect "$container" >/dev/null 2>&1; then
  old_running=$(docker inspect --format '{{.State.Running}}' "$container")
  docker rename "$container" "$backup"
  old_saved=true
  docker stop --time 30 "$backup"
fi

replacement_attempted=true
docker run -d --name "$container" \
  --restart unless-stopped \
  --publish "127.0.0.1:$port:3030" \
  --env PORT=3030 \
  "$image"

# Probe from the host because the production image contains no shell or curl.
healthy=false
for ((attempt = 1; attempt <= 30; attempt++)); do
  if [[ "$(docker inspect --format '{{.State.Running}}' "$container")" != true ]]; then
    break
  fi
  if curl --fail --silent --noproxy '*' --max-time 3 \
    "http://127.0.0.1:$port/api/stats" >/dev/null; then
    healthy=true
    break
  fi
  sleep 2
done
if ! $healthy; then
  echo "New container failed its startup check." >&2
  exit 1
fi

# A healthy replacement is committed; cleanup must not trigger a rollback.
trap - EXIT
if $old_saved; then
  docker rm "$backup"
fi
echo "Deployed $image as $container at 127.0.0.1:$port."
