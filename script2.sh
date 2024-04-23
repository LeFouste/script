#!/bin/bash

#set -x

group_primary=""
group_secondary=""
sudo_val=""
user_name=""

while getopts "G:g:s:u:" opt; do
  case $opt in
    G) group_primary=$OPTARG ;;
    g) group_secondary=$OPTARG ;;
    s) sudo_val=$OPTARG ;;
    u) user_name=$OPTARG ;;
    *) echo "Usage: cmd [-G primary_group] [-g secondary_group] [-s sudo_value] [-u user_name]" ;;
  esac
done

is_sudoer() {
    local user=$1
    if sudo -l -U "$user" 2>&1 | grep -q '(ALL) ALL'; then
        echo "OUI"
    else
        echo "NON"
    fi
}

format_size() {
    local total_size=$1
    local mo ko octets
    mo=$((total_size/1024/1024))
    ko=$(((total_size/1024)%1024))
    octets=$((total_size%1024))
    echo "${mo}Mo ${ko}ko ${octets}octets"
}

#UID >= 1000 pour extraire les users au dessus de fousta
getent passwd | awk -F':' -v gp="$group_primary" -v uid_min=1000 '$3 >= uid_min {print $1 ":" $3 ":" $4 ":" $5}' | \
while IFS=: read -r login uid gid gecos; do
  IFS=', ' read -r prenom nom rest <<< "$gecos"

  groupe_primaire=$(getent group | awk -F':' -v gid="$gid" '$3 == gid {print $1}')

  #continuer si le groupe primaire ne correspond pas au filtre -G
  if [[ -n "$group_primary" && "$group_primary" != "$groupe_primaire" ]]; 
    then
    continue
  fi

  groupes_secondaires=$(id -nG "$login" | tr ' ' '\n' | grep -v "^$groupe_primaire$" | paste -sd ',' -)

  #continuer si aucun des groupes secondaires ne correspond au filtre
  if [[ -n "$group_secondary" && ! ",$groupes_secondaires," == *",$group_secondary,"* ]]; 
    then
    continue
  fi

  if [[ -d "/home/$login" ]]; 
    then
    taille_rep=$(du -sb "/home/$login" | cut -f1)
  else
    taille_rep=0
  fi

  formatted_size=$(format_size "$taille_rep")

  sudoer=$(is_sudoer "$login")

  if [[ -n "$user_name" && "$login" != "$user_name" ]]; 
    then
    continue
  fi

  if [[ -n "$sudo_val" ]]; 
    then
    if [[ "$sudo_val" == "1" && "$sudoer" == "NON" ]] || [[ "$sudo_val" == "0" && "$sudoer" == "OUI" ]]; 
        then
        continue
    fi
  fi

  echo "Utilisateur : $login"
  echo "Prénom : $prenom"
  echo "Nom : $nom"
  echo "Groupe primaire : $groupe_primaire"
  echo "Groupes secondaires : $groupes_secondaires"
  echo "Répertoire personnel : $formatted_size"
  echo "Sudoer : $sudoer"
  echo
done