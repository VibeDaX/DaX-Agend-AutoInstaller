adapter_install(){
  docker build -t dax/hermes:baseline -f "$DOCKER_DIR/hermes/Dockerfile" "$DOCKER_DIR"
}

adapter_start(){
  local vol
  vol="$(volume_mount_docker hermes_data)"
  local secret_env
  secret_env="$(secret_inject_docker agent hermes)" || secret_env=""
  local env_arg=""
  [[ -n "$secret_env" ]] && env_arg="--env-file $secret_env"
  docker run -d \
    --name dax-hermes \
    --restart unless-stopped \
    --security-opt no-new-privileges:true \
    --cap-drop ALL \
    --pids-limit 512 \
    --memory 4g \
    --cpus 2 \
    $env_arg \
    $vol \
    dax/hermes:baseline
}

adapter_stop(){ docker rm -f dax-hermes || true; }
adapter_status(){ docker ps -a --filter name=dax-hermes; }
adapter_logs(){ docker logs --tail 100 -f dax-hermes; }
adapter_health(){ docker inspect --format '{{.State.Health.Status}}' dax-hermes 2>/dev/null || echo "unknown"; }
adapter_uninstall(){ docker rm -f dax-hermes || true; docker rmi dax/hermes:baseline || true; }
