---
description: "Clean up unused Docker containers, images, volumes, and networks. Usage: /docker-clean [--all | --containers | --images | --volumes | --networks | --dangling]"
---

# Docker Cleanup Automation

Clean up target: **$ARGUMENTS** (default: `--all`)

## Step 1: Docker Environment Survey

First, assess the current Docker state:

```bash
echo "=== Docker Disk Usage ==="
docker system df

echo ""
echo "=== Running Containers ==="
docker ps --format "table {{.ID}}\t{{.Image}}\t{{.Status}}\t{{.Names}}"

echo ""
echo "=== All Containers (including stopped) ==="
docker ps -a --format "table {{.ID}}\t{{.Image}}\t{{.Status}}\t{{.Names}}"

echo ""
echo "=== Images ==="
docker images --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}\t{{.CreatedSince}}"

echo ""
echo "=== Dangling Images ==="
docker images -f "dangling=true" --format "table {{.ID}}\t{{.Size}}\t{{.CreatedSince}}"

echo ""
echo "=== Volumes ==="
docker volume ls

echo ""
echo "=== Networks (custom only) ==="
docker network ls --filter type=custom
```

## Step 2: Generate Cleanup Report

Before cleaning, show what WILL be removed:

```
╔═══════════════════════════════════════════════╗
║          DOCKER CLEANUP PREVIEW               ║
╠═══════════════════════════════════════════════╣
║ Stopped Containers:   [count] ([size])        ║
║ Dangling Images:      [count] ([size])        ║
║ Unused Images:        [count] ([size])        ║
║ Unused Volumes:       [count] ([size])        ║
║ Unused Networks:      [count]                 ║
╠═══════════════════════════════════════════════╣
║ Total Reclaimable:    [total size]            ║
╚═══════════════════════════════════════════════╝
```

**ASK FOR CONFIRMATION** before proceeding with cleanup.

## Step 3: Execute Cleanup

Based on the `$ARGUMENTS` flag:

### `--all` (default) — Full cleanup
```bash
echo "=== Removing stopped containers ==="
docker container prune -f

echo ""
echo "=== Removing dangling images ==="
docker image prune -f

echo ""
echo "=== Removing unused images (not referenced by any container) ==="
docker image prune -a -f

echo ""
echo "=== Removing unused volumes ==="
docker volume prune -f

echo ""
echo "=== Removing unused networks ==="
docker network prune -f

echo ""
echo "=== Final disk usage ==="
docker system df
```

### `--containers` — Only stopped containers
```bash
echo "=== Removing stopped containers ==="
docker container prune -f
echo ""
echo "Removed containers. Remaining:"
docker ps -a --format "table {{.ID}}\t{{.Image}}\t{{.Status}}\t{{.Names}}"
```

### `--images` — Only unused images
```bash
echo "=== Removing dangling images ==="
docker image prune -f

echo ""
echo "=== Removing all unused images ==="
docker image prune -a -f

echo ""
echo "Remaining images:"
docker images --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}"
```

### `--volumes` — Only unused volumes
```bash
echo "=== Removing unused volumes ==="
docker volume prune -f

echo ""
echo "Remaining volumes:"
docker volume ls
```

### `--networks` — Only unused networks
```bash
echo "=== Removing unused networks ==="
docker network prune -f

echo ""
echo "Remaining networks:"
docker network ls
```

### `--dangling` — Only dangling images (safest)
```bash
echo "=== Removing dangling images only ==="
docker image prune -f

echo ""
echo "Remaining images:"
docker images --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}"
```

## Step 4: Post-Cleanup Summary

```
╔═══════════════════════════════════════════════╗
║          DOCKER CLEANUP COMPLETE              ║
╠═══════════════════════════════════════════════╣
║ Space Before:    [before size]                ║
║ Space After:     [after size]                 ║
║ Space Freed:     [freed size]                 ║
╠═══════════════════════════════════════════════╣
║ Containers Removed:  [count]                  ║
║ Images Removed:      [count]                  ║
║ Volumes Removed:     [count]                  ║
║ Networks Removed:    [count]                  ║
╚═══════════════════════════════════════════════╝
```

## Step 5: Recommendations

After cleanup, check:
- Are there containers that keep restarting? (restart loop consuming resources)
- Are there very old images that should be removed from the registry too?
- Should you set up automated cleanup via `docker system prune` in a cron job?

Suggest a cron job for automated cleanup if not already configured:
```bash
# Add to crontab: clean dangling images weekly
# 0 2 * * 0 docker image prune -f >> /var/log/docker-cleanup.log 2>&1
```
