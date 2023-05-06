#!/bin/bash

# Set the backup directory
backup_dir="/mnt/truenas/backups"
options_file="$backup_dir/script-options.txt"
# Set the portainer directory. Default = /var/lib/docker/volumes/portainer_portainer_data/_data
portainer_data="/var/lib/docker/volumes/portainer_portainer_data/_data"
# Set directories to be excluded from a backup. Example = Network shares
exclude_dirs=(
  "/mnt/truenas"
  "/mnt/openmediavault"
  "/mnt/unraid"
)

#Days to keep a backup
days_to_keep=30

# User to have access to backups
user="jdemmers"
group="jdemmers"

# Ensure the script is run by root. Not running it as root wil cause problems reading portainer data or other protected data
if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root"
    exit 1
fi

# Check if a options file exist | If it doesnt exist, run first-time setup
if [ -f "$options_file" ]; then
  options=$(cat $options_file)
  echo "Using containers from $options_file"
else
  # Fetch the current containers
  container_list=( $(docker ps --format "{{.Names}}") )

  echo "****First-time startup****"

  echo "Select containers(corresponding number) to backup (use space to seperate numbers):"
  # List al containers with their names with a number
  for i in ${!container_list[@]}; do
    echo "[$i] ${container_list[$i]}"
  done

  # Read the selected containers
  read -p "Enter container numbers: " selected_containers
  echo "Following containers were selected:"

  # Insert the selected containers into the options file
  for i in $selected_containers; do
    options+="${container_list[$i]} "

    echo "${container_list[$i]}"
  done
  echo $options > $options_file
fi

# Loop through the containers and backup each one
for container in $options; do
  # Use the docker command to get the container ID and then the stack id.
  container_id=$(docker ps -qf "name=${container}")
  config_files_label=$(docker inspect $container_id | jq -r '.[0].Config.Labels."com.docker.compose.project.config_files"')
  stack_id=$(echo "${config_files_label}" | cut -d '/' -f 4)

  echo ""
  echo "----${container}----"

  # Check if the container id was found, if not skip that container
  if [ -z "$container_id" ]; then
    echo "$container not found. Skipping..."
    continue
  else
   echo "Container id: ${container_id}"
  fi

  # If it was able to find the stack id (If it consists of numbers), echo it. (Containers made within portainer have a stack ID)
  if [[ "$stack_id" =~ ^[0-9]+$ ]]; then
    echo "Stack id: ${stack_id}"
  fi

  # Stopping the container
  docker stop "${container_id}"> /dev/null
  echo "Stopped ${container}"

  # Get the current date and time formatted as YYYY-MM-DD_HH-MM-SS
  date=$(date +%F_%H-%M-%S)

  # Create the directory
  new_backup_dir="${backup_dir}/${container}/${date}"
  mkdir -p "$new_backup_dir"

  # Backup the volumes
  for volume_path in $(docker inspect "${container_id}" | jq -r '.[].Mounts[] | select(.Type == "bind") | .Source'); do
    # Check if volume is excluded
    for dir in "${exclude_dirs[@]}"; do
      if [[ "$volume_path" == *"$dir"* ]]; then
        echo "Skipping excluded volume: $volume_path"
        continue 2
      fi
    done

    # Check if volume is a directory
    if ! test -d $volume_path; then
        echo "Skipping $volume_path as it is not a directory..."
        continue
    fi

    # Get the volume name
    volume_name=$(echo "$volume_path" | sed 's/\//_/g')

    # Backup the volume in a tar file
    volume_backup_path="${new_backup_dir}/${volume_name}.tar"
    echo "Backing up volume: $volume_path"
    tar -cf "${volume_backup_path}" -C "${volume_path}" .
  done

  # Backup the container
  container_backup_path="${new_backup_dir}/${container}.tar"
  echo "Exporting container"
  docker export "${container_id}" > "${container_backup_path}"

  #Start container back up
  docker start "${container_id}"> /dev/null
  echo "Started ${container}"

  compose_backup_path="${new_backup_dir}/docker-compose.yml"

  if [[ "$stack_id" =~ ^[0-9]+$ ]]; then
    if [[ -z $portainer_data ]] || [[ -z "$portainer_data" ]]; then
      echo "Container found with stack ID: $stack_id but portainer_data is not defined. Skipping compose file..."
    else
      echo "Grabbed compose file"
      # Get the compose file using the stackID | Used when stack_id is a number and thus a portainer stack
      compose_file_path="${portainer_data}/compose/${stack_id}/docker-compose.yml"
      compose_data=$(cat "${compose_file_path}")
    fi
  else 
    echo "Grabbed compose file"
    # Get the compose file using the config_files_label | Used when the container is made outside of Portainer
    compose_data=$(cat "${config_files_label}")
  fi

  echo "${compose_data}" > "${compose_backup_path}"

  # Changing permission of the backup dir to chosen user.
  if [ "$group" != "" ]; then
    if [ "$user" != "" ]; then
      chown -R $user:$group $new_backup_dir
    fi
  else
    if [ "$user" != "" ]; then
      chown -R $user $new_backup_dir
    fi
  fi

  backup_dir_container="${backup_dir}/${container}"
  for dir in "$backup_dir_container"/*; do
    # Get the creation date of the directory
    dir_date=$(date -d "$(basename "$dir" | cut -d '_' -f1)" +%s)
    if [[ $dir_date =~ ^[0-9]+$ ]]; then
      # Get the current date
      current_date=$(date +%s)

      # Calculates the difference between the creation date and the current date
      days_diff=$(( (current_date - dir_date) / (60*60*24) ))

      # Check if the directory is older than the specified number of days
      if [[ "$days_diff" -gt "$days_to_keep" ]]; then
        # Directory is older than specified number of days, so it gets deleted
        echo "Deleting old backup: $dir"
        rm -rf "$dir"
      fi
    fi
  done
done
