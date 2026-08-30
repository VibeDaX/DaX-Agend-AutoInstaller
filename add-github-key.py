import os
key = 'github.com ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl'
known = os.path.expanduser('~/.ssh/known_hosts')
os.makedirs(os.path.dirname(known), exist_ok=True)
with open(known, 'a') as f:
    f.write(key + '\n')
print('OK')
