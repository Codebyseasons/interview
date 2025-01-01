#!/bin/bash

# Configuration
SECRET_NAME="postgresql-db-credentials"  # Name of the secret in AWS Secrets Manager
DB_HOST="postgresql-cluster.cluster-cvkyaqkiorxx.us-east-1.rds.amazonaws.com" # RDS endpoint for your PostgreSQL database
DB_PORT=5432
DB_NAME="api_data"

# Fetch credentials from AWS Secrets Manager
echo "Fetching credentials for secret: $SECRET_NAME"
SECRET_JSON=$(aws secretsmanager get-secret-value --secret-id "$SECRET_NAME" --query 'SecretString' --region us-east-1 --output text)

# Check if the AWS CLI command succeeded
if [ $? -ne 0 ]; then
    echo "Error: Failed to retrieve secret value."
    exit 1
fi

# Extract the values for username and password using jq
DB_USERNAME=$(echo $SECRET_JSON | jq -r '.username')
DB_PASSWORD=$(echo $SECRET_JSON | jq -r '.password')

# API configurations
APIS=(
    '{"name": "bird_basel", "endpoint": "https://mds.bird.co/gbfs/v2/public/basel/gbfs.json"}'
    '{"name": "ridedott_brussels", "endpoint": "https://gbfs.api.ridedott.com/public/v2/brussels/gbfs.json"}'
    '{"name": "neuron_ycc", "endpoint": "https://mds.neuron-mobility.com/yyc/gbfs/2/"}'
)

# Helper function to fetch JSON data from the URL
fetch_json() {
  local url=$1
  curl -s "$url" || { echo "Error fetching $url"; return 1; }
}

# Helper function to initialize the PostgreSQL database
initialize_database() {
  echo "Initializing database on PostgreSQL..."
  PGPASSWORD=$DB_PASSWORD psql -h "$DB_HOST" -U "$DB_USERNAME" -d "$DB_NAME" <<EOF
CREATE TABLE IF NOT EXISTS api_data (
  api_name VARCHAR(255) NOT NULL PRIMARY KEY,
  last_updated TIMESTAMPTZ NOT NULL,
  data JSONB NOT NULL
);

CREATE TABLE IF NOT EXISTS historical_data (
  api_name VARCHAR(255) NOT NULL,
  timestamp TIMESTAMPTZ NOT NULL,
  data JSONB NOT NULL,
  PRIMARY KEY (api_name, timestamp)
);
EOF
  echo "Database initialized successfully."
}

# Function to get the last updated timestamp for an API from the database
get_last_updated_from_db() {
  local api_name=$1
  PGPASSWORD=$DB_PASSWORD psql -h "$DB_HOST" -U "$DB_USERNAME" -d "$DB_NAME" -t -c \
    "SELECT last_updated FROM api_data WHERE api_name = '$api_name';"
}

# Function to update the last_updated field in the api_data table
update_last_updated_in_db() {
  local api_name=$1
  local last_updated=$2
  local json_data=$3
  PGPASSWORD=$DB_PASSWORD psql -h "$DB_HOST" -U "$DB_USERNAME" -d "$DB_NAME" <<EOF
INSERT INTO api_data (api_name, last_updated, data)
VALUES ('$api_name', '$last_updated', '$json_data')
ON CONFLICT (api_name) DO UPDATE
  SET last_updated = EXCLUDED.last_updated,
      data = EXCLUDED.data;
EOF
  echo "Updated last_updated for $api_name successfully."
}

# Function to store historical data in the historical_data table
store_historical_data() {
  local api_name=$1
  local last_updated=$2
  local json_data=$3
  PGPASSWORD=$DB_PASSWORD psql -h "$DB_HOST" -U "$DB_USERNAME" -d "$DB_NAME" <<EOF
INSERT INTO historical_data (api_name, timestamp, data)
VALUES ('$api_name', '$last_updated', '$json_data');
EOF
  echo "Stored historical data for $api_name successfully."
}

# Function to process each API
process_api() {
  local api_config=$1
  local api_name
  local api_endpoint

  # Extract API name and endpoint from JSON
  api_name=$(echo "$api_config" | jq -r '.name')
  api_endpoint=$(echo "$api_config" | jq -r '.endpoint')

  echo "Processing API: $api_name"

  # Fetch main API data
  local api_data
  api_data=$(fetch_json "$api_endpoint")
  if [[ $? -ne 0 ]]; then
    echo "Failed to fetch data from $api_endpoint"
    return
  fi

  # Parse response for last updated and free bike status URL
  local last_updated_unix
  local free_bike_status_url
  last_updated_unix=$(echo "$api_data" | jq -r '.last_updated')
  free_bike_status_url=$(echo "$api_data" | jq -r '.data.en.feeds[] | select(.name == "free_bike_status") | .url')

  if [[ -z "$last_updated_unix" || -z "$free_bike_status_url" ]]; then
    echo "Invalid response from API: $api_name"
    return
  fi

  # Convert Unix timestamp to ISO 8601
  local last_updated
  last_updated=$(date -u -d @"$last_updated_unix" +"%Y-%m-%dT%H:%M:%S")

  # Get the last updated timestamp from the database
  local db_last_updated
  db_last_updated=$(get_last_updated_from_db "$api_name")

  if [[ -z "$db_last_updated" ]]; then
    echo "No last_updated data for $api_name. Starting fresh."
  elif [[ "$db_last_updated" == "$last_updated" ]]; then
    echo "No changes detected for $api_name."
    return
  else
    echo "Detected change in last_updated for $api_name: $last_updated"
  fi

  # Fetch detailed data
  local detailed_data
  detailed_data=$(fetch_json "$free_bike_status_url")
  if [[ $? -ne 0 ]]; then
    echo "Failed to fetch detailed data from $free_bike_status_url"
    return
  fi

  # Update database and store historical data
  update_last_updated_in_db "$api_name" "$last_updated" "$detailed_data"
  store_historical_data "$api_name" "$last_updated" "$detailed_data"
}

# Main function to initialize database and process all APIs
main() {
  echo "Starting script execution..."
  initialize_database
  for api_config in "${APIS[@]}"; do
    process_api "$api_config"
  done
  echo "Script execution completed."
}

main
