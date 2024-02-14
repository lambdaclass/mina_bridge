PGPASSWORD=postgres psql -qtA -h localhost -p 5432 -U postgres -d minanode -c "
select balance
from balances as b
inner join public_keys as pk on b.public_key_id = pk.id
where pk.value = '$1'
order by block_height desc limit 1;
"
