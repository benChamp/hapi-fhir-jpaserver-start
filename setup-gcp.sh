#!/bin/bash
set -e

# Configuration
PROJECT_ID="champ-pov-app-dev"
REGION="us-west1"
DB_INSTANCE_NAME="hapi-fhir-db"
DB_NAME="hapi"
DB_USER="postgres"
ARTIFACT_REGISTRY_REPO="hapi-fhir"
SECRET_NAME="hapi-db-password"

echo "========================================="
echo "HAPI FHIR Cloud Run Setup"
echo "========================================="
echo "Project: $PROJECT_ID"
echo "Region: $REGION"
echo "========================================="

# Set the project
echo "Setting GCP project..."
gcloud config set project $PROJECT_ID

# Enable required APIs
echo "Enabling required GCP APIs..."
gcloud services enable \
  run.googleapis.com \
  sqladmin.googleapis.com \
  artifactregistry.googleapis.com \
  secretmanager.googleapis.com \
  cloudbuild.googleapis.com \
  vpcaccess.googleapis.com \
  servicenetworking.googleapis.com \
  compute.googleapis.com

echo "APIs enabled successfully!"

# Create Artifact Registry repository
echo "Creating Artifact Registry repository..."
if gcloud artifacts repositories describe $ARTIFACT_REGISTRY_REPO --location=$REGION &>/dev/null; then
  echo "Artifact Registry repository already exists."
else
  gcloud artifacts repositories create $ARTIFACT_REGISTRY_REPO \
    --repository-format=docker \
    --location=$REGION \
    --description="HAPI FHIR Docker images"
  echo "Artifact Registry repository created!"
fi

# Configure Docker authentication
echo "Configuring Docker authentication..."
gcloud auth configure-docker ${REGION}-docker.pkg.dev

# Create database password secret
echo "Creating database password secret..."
if gcloud secrets describe $SECRET_NAME &>/dev/null; then
  echo "Secret already exists."
else
  echo -n "1@mChampHealth" | gcloud secrets create $SECRET_NAME \
    --data-file=- \
    --replication-policy="automatic"
  echo "Secret created!"
fi

# Allocate IP range for VPC peering (required for private IP)
echo "Setting up VPC for private IP..."
if gcloud compute addresses describe google-managed-services-default --global &>/dev/null; then
  echo "VPC peering IP range already allocated."
else
  gcloud compute addresses create google-managed-services-default \
    --global \
    --purpose=VPC_PEERING \
    --prefix-length=16 \
    --network=default
  echo "VPC peering IP range allocated!"
fi

# Create VPC peering connection
echo "Creating VPC peering connection..."
if gcloud services vpc-peerings list --network=default | grep -q "servicenetworking.googleapis.com"; then
  echo "VPC peering connection already exists."
else
  gcloud services vpc-peerings connect \
    --service=servicenetworking.googleapis.com \
    --ranges=google-managed-services-default \
    --network=default
  echo "VPC peering connection created!"
fi

# Create Cloud SQL instance
echo "Creating Cloud SQL instance (this may take several minutes)..."
if gcloud sql instances describe $DB_INSTANCE_NAME &>/dev/null; then
  echo "Cloud SQL instance already exists."
else
  gcloud sql instances create $DB_INSTANCE_NAME \
    --database-version=POSTGRES_15 \
    --tier=db-f1-micro \
    --region=$REGION \
    --network=projects/$PROJECT_ID/global/networks/default \
    --no-assign-ip \
    --database-flags=max_connections=100
  echo "Cloud SQL instance created!"
fi

# Set database password
echo "Setting database password..."
gcloud sql users set-password $DB_USER \
  --instance=$DB_INSTANCE_NAME \
  --password="1@mChampHealth"

# Create database
echo "Creating database..."
if gcloud sql databases describe $DB_NAME --instance=$DB_INSTANCE_NAME &>/dev/null; then
  echo "Database already exists."
else
  gcloud sql databases create $DB_NAME \
    --instance=$DB_INSTANCE_NAME
  echo "Database created!"
fi

# Create VPC Access Connector (required for Cloud Run to access private Cloud SQL)
echo "Creating VPC Access Connector..."
CONNECTOR_NAME="hapi-fhir-connector"
if gcloud compute networks vpc-access connectors describe $CONNECTOR_NAME --region=$REGION &>/dev/null; then
  echo "VPC Access Connector already exists."
else
  gcloud compute networks vpc-access connectors create $CONNECTOR_NAME \
    --region=$REGION \
    --network=default \
    --range=10.8.0.0/28 \
    --min-instances=2 \
    --max-instances=3 \
    --machine-type=f1-micro
  echo "VPC Access Connector created!"
fi

echo ""
echo "========================================="
echo "Setup Complete!"
echo "========================================="
echo "Next steps:"
echo "1. Run ./deploy.sh to build and deploy the application"
echo "========================================="
echo ""
echo "Cloud SQL Connection Name:"
gcloud sql instances describe $DB_INSTANCE_NAME --format="value(connectionName)"
