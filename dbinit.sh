#!/bin/bash
##
## A helper script used to setup and takedown a Mongo DB for unit tests.
##
CMD=$1
MONGODB_VERSION=$2

#
# Output usage
#
function usage () {
    cat <<EOT
Usage:
    `basename $0` command db_version

    Known commands:
        init
        clean

    Mongo DB Binary Versions:
        2.6.x
        3.0.x
        3.2.x
EOT
}

# Check usage
if [ $# -lt 1 ];  then
    usage
    exit 1
fi

# Choose default if db_version is not given
if [ -z "${MONGODB_VERSION}" ]; then
    echo "Using default MongoDB version [2.6.x]"
    MONGODB_VERSION="2.6.x"
fi

#
# Initializes the DB with auth users.
# All connections will use authentication.
#
function initdb () {
    if [ `nc -z localhost 27017` ]; then
        echo "mongodb still running"
        exit 1
    fi

    if [ -e "/tmp/test-data" ]; then
        rm -rf /tmp/test-data
    fi

    # Switch to correct version of Mongo DB
    # Requires dependency mongodb-version-manager
    # Be sure to `npm install` beforehand.
    m use ${MONGODB_VERSION}

    mkdir -p /tmp/test-data
    mongod --dbpath /tmp/test-data --bind_ip 127.0.0.1 > /dev/null 2>&1 &

    until nc -z localhost 27017; do
        echo "Starting mongod..."
        sleep 1
    done

    echo "Creating admin user..."
    mongo admin --eval \
        'db.createUser({user:"myadmin", pwd:"pass1234", roles:["root"]})' \
        > /dev/null 2>&1
    echo "Creating user for humblejs_test database..."
    mongo humblejs_test --eval \
        'db.createUser({user:"myadmin", pwd:"pass1234", roles:["readWrite"]})' \
        > /dev/null 2>&1
    echo "Stopping mongod..."
    mongo admin --eval 'db.shutdownServer()' > /dev/null 2>&1

    sleep 2

    mongod --dbpath /tmp/test-data --bind_ip 127.0.0.1 --auth > /dev/null 2>&1 &
    until nc -z localhost 27017; do
        echo "Starting mongod with auth enabled..."
        sleep 1
    done 

    echo "Done"
}

#
# Stops DB and cleans up entire database directory.
#
function cleandb () {
    # Switch to correct version of Mongo DB
    # Requires dependency mongodb-version-manager
    # Be sure to `npm install` beforehand.
    m use ${MONGODB_VERSION}

    stopit=`nc -z localhost 27017`
    if [ $? ]; then
        echo "Stopping mongod..."
        mongo admin -u myadmin -p pass1234 --authenticationDatabase admin \
            --eval "db.shutdownServer()" > /dev/null 2>&1
        sleep 2
    fi

    echo "Cleaning up dbpath..."
    if [ -e "/tmp/test-data" ]; then
        rm -rf /tmp/test-data
    fi

    echo "Done"
}

# Handle commands
echo "Performing [${CMD}] for version MongoDB [${MONGODB_VERSION}]"
case ${CMD} in
    init)
        initdb
        ;;
    clean)
        cleandb
        ;;
    *)
        echo "Unrecognized command: ${CMD}"
        usage
        ;;
esac

