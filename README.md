Overview

This project implements an automated system to fetch, store, process, and visualise data from multiple APIs. It includes database setup, data ingestion, historical tracking, and a Grafana dashboard for data visualisation.

The key components of the system are:

API Data Fetching: Periodically retrieves data from multiple APIs.

Data Storage: Saves the data in a PostgreSQL database for current and historical records.

Visualisation: Displays insights using a Grafana dashboard connected to the database.




Workflow

Environment Setup

Provider Configuration (provider.tf): Sets up the required cloud resources (e.g., AWS) for managing the infrastructure.

Database Initialisation (rds.tf): Configures an RDS PostgreSQL instance to host the database.

Data Ingestion Script (sql.sh)

This script performs the following tasks:

Credential Fetching: Retrieves database credentials from AWS Secrets Manager.

Database Initialisation:

Creates tables for storing current (api_data) and historical data (historical_data).

Ensures schema consistency on startup.





API Processing:

Iterates over API configurations (name and endpoint).

Fetches JSON data from each API and parses it.

Checks if the data has been updated since the last fetch.

Saves the data into the database and logs changes in the historical_data table.

Database Schema

The script creates and manages two PostgreSQL tables:

api_data:

Stores the latest data fetched from each API.

Fields: api_name, last_updated, and data.

historical_data:

Tracks all changes over time for historical analysis.

Fields: api_name, timestamp, and data.

Grafana Dashboard (dashboard.json)

The dashboard.json defines a Grafana dashboard to visualise data:

Panels:

Displays real-time and historical bike availability.

Tracks bikes' battery levels and operational states.

Queries:

Fetches data from the PostgreSQL database.

Uses advanced SQL queries to extract insights (e.g., availability, battery status).

Features:

Time series analysis.

Bar charts for bike states (available, reserved, or disabled).

A list of active API providers.



Execution

Run Script: Execute sql.sh to fetch data and populate the database.bash
Copy code
bash sql.sh


Visualise Data: Access the Grafana dashboard using the provided dashboard.json.

Key Features

Automated Fetching: Automates data retrieval using curl and JSON parsing.

Historical Tracking: Maintains historical records for trends and analytics.

Custom Visualisations: Provides customisable panels in Grafana for real-time insights.



Prerequisites

AWS CLI configured with appropriate permissions.

PostgreSQL installed or accessible via RDS.

jq for JSON processing.

Grafana setup for dashboard visualisation.
