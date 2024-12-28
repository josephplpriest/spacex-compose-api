#!/bin/sh

# Check if required environment variables are set
if [ -z "$MONGO_INITDB_ROOT_USERNAME" ] || [ -z "$MONGO_INITDB_ROOT_PASSWORD" ] || [ -z "$MONGO_INITDB_DATABASE" ]; then
  echo "Error: Missing required environment variables."
  echo "Ensure MONGO_INITDB_ROOT_USERNAME, MONGO_INITDB_ROOT_PASSWORD, and MONGO_INITDB_DATABASE are set."
  exit 1
fi

# Wait for MongoDB to start
until mongosh --username "$MONGO_INITDB_ROOT_USERNAME" --password "$MONGO_INITDB_ROOT_PASSWORD" --authenticationDatabase "admin" --eval "print(\"waited for connection\")" >/dev/null 2>&1; do
  echo "Waiting for MongoDB to start..."
  sleep 2
done

# Check if the .agz file exists
AGZ_FILE="/dump/spacex.2024-7-5.agz"
if [ -f "$AGZ_FILE" ]; then
  echo "Found $AGZ_FILE. Restoring data..."
  mongorestore --gzip --archive="$AGZ_FILE" --host localhost --port=27017 --nsInclude="*" \
    --username="$MONGO_INITDB_ROOT_USERNAME" --password="$MONGO_INITDB_ROOT_PASSWORD" --authenticationDatabase=admin
  if [ $? -eq 0 ]; then
    echo "Data restoration from $AGZ_FILE completed successfully."
  else
    echo "Error: Data restoration failed."
    exit 1
  fi
else
  echo "No .agz file found at $AGZ_FILE. Skipping data restoration."
fi

# Perform dump with specific output location and host
echo "Starting database dump..."
mongodump --host localhost --port 27017 \
  --username "$MONGO_INITDB_ROOT_USERNAME" \
  --password "$MONGO_INITDB_ROOT_PASSWORD" \
  --db spacex-api \
  --authenticationDatabase admin

# Perform restore with specific input location and host
echo "Starting database restore..."
mongorestore --host localhost --port 27017 \
  --username "$MONGO_INITDB_ROOT_USERNAME" \
  --password "$MONGO_INITDB_ROOT_PASSWORD" \
  --db spacex \
  --authenticationDatabase admin \
  dump/spacex-api/

# Create a new user
echo "Creating application user..."
mongosh --host localhost --port 27017 \
  --username "$MONGO_INITDB_ROOT_USERNAME" \
  --password "$MONGO_INITDB_ROOT_PASSWORD" \
  --authenticationDatabase "admin" <<EOF
use $MONGO_INITDB_DATABASE
db.createUser({
  user: "$MONGO_INITDB_ROOT_USERNAME",
  pwd: "$MONGO_INITDB_ROOT_PASSWORD",
  roles: [
    { role: "readWrite", db: "$MONGO_INITDB_DATABASE" }
  ]
})
print("Application user created successfully")
EOF

