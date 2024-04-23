#!/bin/bash

FICHIER_SOURCE="./users.txt"

#verif lexistence dun utilisateur sur son prénom et nom
user_exists() {
    local prenom="$1"
    local nom="$2"
    local full_name="${prenom} ${nom}"
    while IFS=: read -r _ _ _ _ gecos _; 
        do
        if [[ "$gecos" == "$full_name"* ]]; 
            then
            echo "Utilisateur trouvé : $gecos"
            return 0
        fi
    done < /etc/passwd
    echo "Aucun utilisateur trouvé avec le nom : $full_name"
    return 1
}

#veification du format du fichier source modifie
#creer des conflits
#if ! egrep -q ^[^:]+:[^:]+:[^:]*:[^:]+:[^:]+:[^:]+' $FICHIER_SOURCE"; then
#    echo "Le fichier source ne respecte pas le format attendu.
#    exit 1
#fi

while IFS=: read -r prenom nom groupes sudo motdepasse; 
    do

    base_login=$(echo "${prenom:0:1}$nom" | tr '[:upper:]' '[:lower:]')
    login=$base_login
    suffixe=1

    #verif si le user existe déjà
    if user_exists "$prenom" "$nom"; 
        then
        echo "L'utilisateur $prenom $nom existe déjà. Aucune action n'est requise."
        echo
	continue
    fi

    #login unique
    while id "$login" &>/dev/null; 
        do
        login="${base_login}${suffixe}"
        ((suffixe++))
    done

    if [ -z "$groupes" ]; 
        then
        #si aucun groupe nest specifie, le groupe primaire a le meme nom que le login
        groupe_primaire="$login"
        #creer groupe primaire, ignorer si le groupe existe deja
        groupadd "$groupe_primaire" 2>/dev/null
    else
        IFS=',' read -r groupe_primaire groupes_secondaires <<< "$groupes"
        groupadd "$groupe_primaire" 2>/dev/null
    fi

    # Créer l'utilisateur avec le login unique
    useradd -m -c "$prenom $nom" -p "$(openssl passwd -1 "$motdepasse")" -g "$groupe_primaire" "$login"
    if [ "$?" -ne 0 ]; 
        then
        echo "Erreur lors de la création de l'utilisateur $login."
        continue
    fi

    #forcer le changement de mot de passe a la premiere connexion
    chage -d 0 "$login"

    if [ -n "$groupes_secondaires" ]; 
        then
        IFS=',' read -ra groupes_arr <<< "$groupes_secondaires"
        for groupe in "${groupes_arr[@]}"; 
            do
            if ! getent group "$groupe" &>/dev/null; 
                then
                groupadd "$groupe"
            fi
            usermod -aG "$groupe" "$login"
        done
    fi

    #gerer les droits sudo si nécessaire
    if [ "$sudo" = "oui" ]; 
        then
        echo "$login ALL=(ALL) NOPASSWD:ALL" > "/etc/sudoers.d/$login"
        chmod 0440 "/etc/sudoers.d/$login"
    fi
    
    #creer les fichiers dans le repertoire personnel
    for i in $(seq 1 $((RANDOM % 6 + 5))); 
        do
        taille=$((RANDOM % 46 + 5))M
        dd if=/dev/urandom of="/home/$login/file_$i" bs=$taille count=1 &>/dev/null
    done

    echo "L'utilisateur $login a été créé avec succès et les fichiers ont été ajoutés."

    echo

done < "$FICHIER_SOURCE"

echo "Script terminé."