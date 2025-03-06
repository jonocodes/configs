#!/usr/bin/env bash


FLATPAK_CATALOG="${FLATPAK_CATALOG:-$HOME/sync/configs/flatpak/hosts/$HOSTNAME/flatpak-catalog.txt}"


get_installed() {
    flatpak list --columns=application --app | sort
}

write_catalog() {

    local catalog="$1"

    # Ask for confirmation with default to "Y"
    read -p "Do you want to write the updated catalog to $FLATPAK_CATALOG? (Y/n) " confirm

    # If user presses Enter or types "Y/y", write the file
    if [[ -z "$confirm" || "$confirm" =~ ^[Yy]$ ]]; then
        echo "$catalog" > $FLATPAK_CATALOG
        # echo "Catalog written to $FLATPAK_CATALOG"
        echo Done. $(echo "$catalog" | wc -l) total packages
    else
        echo "Catalog not written. You may want to hand edit it."
    fi
}

# # Take initial catalog snapshot
# before=$(get_installed)


# If FLATPAK_CATALOG exists, use its state instead of the system
if [[ -f "$FLATPAK_CATALOG" ]]; then
    before=$(cat "$FLATPAK_CATALOG")
else
    before=$(get_installed)
fi

# echo BEFORE
# echo "$before"

if [[ $# -eq 0 ]]; then
    echo "No arguments provided."

    echo "use like $0 update-catalog-from-system ..."

elif [[ "$1" == "update-catalog-from-system" ]]; then

    write_catalog "$before"
    
elif [[ "$1" == "update-system-from-catalog" ]]; then

    # remove missing packages

    # add new packages

    echo Not yet implemented

else

    # Run flatpak command with filtered arguments
    flatpak "${ARGS[@]}"

    # Take final catalog snapshot
    after=$(get_installed)

    # echo "Catalog will be updated accordingly..."

    added=$(comm -13 <(echo "$before" | sort) <(echo "$after" | sort) )

    removed=$(comm -23 <(echo "$before" | sort) <(echo "$after" | sort) )

    if [[ -n "$before" || -n "$after" ]]; then

        echo "Packages added:"
        echo "($added)"

        echo "Packages removed:"
        echo "($removed)"

        write_catalog "$after"

    fi

    # if [[ "$added" -eq ]]

    # echo "Packages added:"
    # echo "Packages removed:"

    # write_catalog "$after"
fi




# ARGS=()
# for arg in "$@"; do
#     if [[ "$arg" != "update-catalog-from-system" ]]; then
#         # ARGS+=("$arg")
#         echo "Writing system state to $FLATPAK_CATALOG"
#         echo "$after" > $FLATPAK_CATALOG
#         echo $(wc -l $FLATPAK_CATALOG) packages
#     fi
# # done

# # Run flatpak command with filtered arguments
# flatpak "${ARGS[@]}"

# # Take final catalog snapshot
# after=$(get_installed)

# # Compare the two lists and print the difference

# # echo BEFORE
# # echo "$before"

# # echo "$before" > before.txt

# # echo AFTER
# # echo "$after"

# # echo "$after" > after.txt

# # echo DIFF
# # diff <(echo "$before") <(echo "$after")


# # echo "Changes detected:"
# # diff <(echo "$before") <(echo "$after") | grep -E "^\<|^\>" | sed 's/^> /Installed: /; s/^< /Removed: /'

# echo "Catalog will be updated accordingly..."

# echo "Packages added:"
# comm -13 <(echo "$before" | sort) <(echo "$after" | sort) 

# echo "Packages removed:"
# comm -23 <(echo "$before" | sort) <(echo "$after" | sort) 


# write_catalog "$after"


# # Ask for confirmation with default to "Y"
# read -p "Do you want to write the updated catalog to $FLATPAK_CATALOG? (Y/n) " confirm

# # If user presses Enter or types "Y/y", write the file
# if [[ -z "$confirm" || "$confirm" =~ ^[Yy]$ ]]; then
#     echo "$after" > $FLATPAK_CATALOG
#     echo "Catalog written to $FLATPAK_CATALOG"
# else
#     echo "Catalog not written. You may want to hand edit it."
# fi
