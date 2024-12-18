#!/bin/bash

# Define the test cases
declare -A endpoints=(
    [5432]="127.0.0.1:5432"
    [5672]="127.0.0.1:5672"
    [6379]="127.0.0.1:6379"
    [11211]="127.0.0.1:11211"
)

# Loop through each endpoint and test it
for port in "${!endpoints[@]}"; do
    echo "Testing route for port $port..."
    curl -s -o /dev/null -w "Response: %{http_code}\n" "http://${endpoints[$port]}"
done
