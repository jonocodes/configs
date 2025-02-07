#!/bin/bash
REMOTE='backup@dobro.alb'
KEY='/root/.ssh/backup_key'

syncoid --sshkey=${KEY} --no-sync-snap --create-bookmark --recursive ${REMOTE}:pool/thunderbird_data dobro/thunderbird_data


# for dataset in thunderbird_data files; do
    # syncoid --sshkey=${KEY} --no-sync-snap --create-bookmark --recursive ${REMOTE}:pool/${dataset} dobro/${dataset}

