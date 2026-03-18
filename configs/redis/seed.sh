#!/bin/sh

# Fetch the value of the key, suppressing extra output from redis-cli
COMMAND=$(redis-cli -h $REDIS_HOST --user $REDIS_USERNAME HGET "enforcer:config:globals" "migrated" | grep true)
if $COMMAND 2>&1 | grep -q "$SEARCH_STRING"; then
    echo "Pattern found. Exiting with status 1."
    exit 1
fi

redis-cli -h $REDIS_HOST --user $REDIS_USERNAME <<EOF
HSET enforcer:config:globals migrated "true"
HSET enforcer:config:globals debug "false"
HSET enforcer:config:globals session_cookie "enforcer_session"
EOF

redis-cli -h $REDIS_HOST --user $REDIS_USERNAME <<EOF
HSET enforcer:config:vault user     "${__REDIS_USER__}"
HSET enforcer:config:vault host     "enforcer-redis-srvc"
HSET enforcer:config:vault port     "6379"
HSET enforcer:config:vault password "${__REDIS_PASS__}"
EOF

redis-cli -h $REDIS_HOST --user $REDIS_USERNAME <<EOF
HSET enforcer:config:database user     "${__POSTGRES_USER__}"
HSET enforcer:config:database host     "enforcer-postgres-srvc"
HSET enforcer:config:database port     "5432"
HSET enforcer:config:database name     "${__POSTGRES_DB__}"
HSET enforcer:config:database password "${__POSTGRES_PASS__}"
EOF

redis-cli -h $REDIS_HOST --user $REDIS_USERNAME <<EOF
HSET enforcer:config:api_server allow_credentials "false"
HSET enforcer:config:api_server allow_origins     '["*"]'
HSET enforcer:config:api_server allow_methods     '["*"]'
HSET enforcer:config:api_server allow_headers     '["*"]'
HSET enforcer:config:api_server host              "0.0.0.0"
HSET enforcer:config:api_server port              "8000"
EOF