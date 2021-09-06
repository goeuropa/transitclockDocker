export PGPASSWORD=transitclock

docker stop transitclock-db-pks
docker stop transitclock-server-instance-pks

docker rm transitclock-db-pks
docker rm transitclock-server-instance-pks

docker rmi transitclock-server-pks

docker build --no-cache -t transitclock-server-pks \
--build-arg TRANSITCLOCK_PROPERTIES="config/transitclock.properties" \
--build-arg AGENCYID="INSERT_AGENCY_ID_HERE" \
--build-arg AGENCYNAME="INSERT_AGENCY_NAME_HERE" \
--build-arg GTFS_URL="INSERT_GTFS_URL_HERE" .

docker run --name transitclock-db-pks -p 5437:5432 -e POSTGRES_PASSWORD=$PGPASSWORD -d postgres:9.6.3

#docker start transitclock-db-pks

docker run --name transitclock-server-instance-pks --rm --link transitclock-db-pks:postgres -e PGPASSWORD=$PGPASSWORD -v ~/logs/pks:/usr/local/transitclock/logs/ transitclock-server-pks check_db_up.sh

docker run --name transitclock-server-instance-pks --rm --link transitclock-db-pks:postgres -e PGPASSWORD=$PGPASSWORD -v ~/logs/pks:/usr/local/transitclock/logs/ transitclock-server-pks create_tables.sh

docker run --name transitclock-server-instance-pks --rm --link transitclock-db-pks:postgres -e PGPASSWORD=$PGPASSWORD -v ~/logs/pks:/usr/local/transitclock/logs/ transitclock-server-pks import_gtfs.sh

docker run --name transitclock-server-instance-pks --rm --link transitclock-db-pks:postgres -e PGPASSWORD=$PGPASSWORD -v ~/logs/pks:/usr/local/transitclock/logs/ transitclock-server-pks create_api_key.sh

docker run --name transitclock-server-instance-pks --rm --link transitclock-db-pks:postgres -e PGPASSWORD=$PGPASSWORD -v ~/logs/pks:/usr/local/transitclock/logs/ transitclock-server-pks create_webagency.sh

docker run --name transitclock-server-instance-pks --rm --link transitclock-db-pks:postgres -e PGPASSWORD=$PGPASSWORD  -v ~/logs/pks/:/usr/local/transitclock/logs/ -v ~/ehcache/pks:/usr/local/transitclock/cache/ -p 8093:8080 transitclock-server-pks  start_transitclock.sh