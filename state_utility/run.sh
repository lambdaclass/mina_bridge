#!/bin/bash
# Receives a Mina public key and a Mina state hash.
# Checks that the Mina public key belongs to the Mina state related to the passed hash. 

IFS='
'
export PGPASSWORD=postgres
FOUND=0

RET_SQL=`psql -qtA -h localhost -p 5432 -U postgres -d minanode -c "
select state_hash 
from blocks
inner join balances on blocks.id = balances.block_id
inner join public_keys on balances.public_key_id = public_keys.id
where public_keys.value = '$1';
"`
for state_hash in $RET_SQL
do
    if [ "$state_hash" = "$2" ]
    then
        echo "Mina public key belongs to the Mina state!"
        FOUND=1
        break
    fi
done

if [ $FOUND -eq 0 ]; then
    echo "Error: Mina public key does not belong to the Mina state"
    exit 1
fi
