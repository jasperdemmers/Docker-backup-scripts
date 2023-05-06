
# Docker-backup-scripts
A script that creates backups for your docker containers. Simply make a cron task running the script daily, weekly, monthly or even yearly. The script backs up al volumes mounted to a container (even bind mounts), exports the container itself and backs up the docker-compose file if one exists. Made using ChatGPT and my knowledge.

## Features
- Backs up compose files, even when using portainer stacks
- Backs up container volumes, including binding volumes
- Exclude directories from backing up. Like media, pictures, etc
- Backs up the container itself
- Delete backups after set amount of days
- Give a user and/or group access to the backup using chown

## Usage
There are a few variables that can be changes to your likings:

| Variable  | Example  | Description                |
| :-------- | :------- | :------------------------- |
| `backup_dir` | `"/mnt/truenas/backups"` | **Required**. Directory where the backups are stored. |
| `options_file` | `"/mnt/truenas/backups/script-options.txt"` | **Required**. Location of the options file.| 
| `portainer_data` | `"/var/lib/docker/volumes/portainer_portainer_data/_data"` | Portainer volume directory. Used to grab the compose file if the container is made within Portainer stacks.| 
| `exclude_dirs` | `("/mnt/truenas" "/mnt/openmediavault" "/mnt/unraid")` | Directories to be excluded from the backup. Example: /mnt/truenas/movies volume in plex as you don't want to backup the movies. | 
| `days_to_keep` | `30` | Amount of days to keep backups. | 
| `user` | `jdemmers` | User to have access to the backups. |
| `group` | `jdemmers` | Group to have access to the backups. User is required |

By default al variables are defined. If you want to disable it, like portainer_data, tag out the line.
