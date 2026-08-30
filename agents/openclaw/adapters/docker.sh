adapter_install(){
  docker build -t dax/openclaw:baseline -f "$DOCKER_DIR/openclaw/Dockerfile" "$DOCKER_DIR"
}

adapter_start(){
  local vol
  vol="$(volume_mount_docker openclaw_data)"
  local secret_env
  secret_env="$(secret_inject_docker agent openclaw)" || secret_env=""
  local env_arg=""
  [[ -n "$secret_env" ]] && env_arg="--env-file $secret_env"
  docker run -d \
    --name dax-openclaw \
    --restart unless-stopped \
    --security-opt no-new-privileges:true \
    --cap-drop ALL \
    --pids-limit 512 \
    --memory 2g \
    --cpus 2 \
    $env_arg \
    $vol \
    dax/openclaw:baseline
}

adapter_stop(){ docker rm -f dax-openclaw || true; }
adapter_status(){ docker ps -a --filter name=dax-openclaw; }
adapter_logs(){ docker logs --tail 100 -f dax-openclaw; }
adapter_health(){ docker inspect --format '{{.State.Health.Status}}' dax-openclaw 2>/dev/null || echo "unknown"; }
adapter_uninstall(){ docker rm -f dax-openclaw || true; docker rmi dax/openclaw:baseline || true; }
