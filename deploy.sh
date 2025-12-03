#!/bin/bash
set -e

# Configuration
PROJECT_ID="champ-pov-app-dev"
REGION="us-west1"
SERVICE_NAME="hapi-fhir-server"
DB_INSTANCE_NAME="hapi-fhir-db"
DB_NAME="hapi"
DB_USER="postgres"
ARTIFACT_REGISTRY_REPO="hapi-fhir"
IMAGE_NAME="${REGION}-docker.pkg.dev/${PROJECT_ID}/${ARTIFACT_REGISTRY_REPO}/${SERVICE_NAME}"
VPC_CONNECTOR="hapi-fhir-connector"

echo "========================================="
echo "HAPI FHIR Cloud Run Deployment"
echo "========================================="
echo "Project: $PROJECT_ID"
echo "Region: $REGION"
echo "Service: $SERVICE_NAME"
echo "========================================="

# Get Cloud SQL connection name
CLOUD_SQL_CONNECTION=$(gcloud sql instances describe $DB_INSTANCE_NAME --format="value(connectionName)")
echo "Cloud SQL Connection: $CLOUD_SQL_CONNECTION"

# Build and tag the Docker image
echo "Building Docker image..."
docker build --target default -t ${IMAGE_NAME}:latest .

# Push to Artifact Registry
echo "Pushing image to Artifact Registry..."
docker push ${IMAGE_NAME}:latest

# Deploy to Cloud Run
echo "Deploying to Cloud Run..."
gcloud run deploy $SERVICE_NAME \
  --image=${IMAGE_NAME}:latest \
  --platform=managed \
  --region=$REGION \
  --allow-unauthenticated \
  --port=8080 \
  --memory=2Gi \
  --cpu=2 \
  --timeout=300 \
  --min-instances=0 \
  --max-instances=10 \
  --vpc-connector=$VPC_CONNECTOR \
  --set-env-vars="SPRING_DATASOURCE_URL=jdbc:postgresql:///${DB_NAME}?cloudSqlInstance=${CLOUD_SQL_CONNECTION}&socketFactory=com.google.cloud.sql.postgres.SocketFactory&user=${DB_USER}&password=1@mChampHealth" \
  --set-env-vars="SPRING_DATASOURCE_USERNAME=${DB_USER}" \
  --set-env-vars="SPRING_DATASOURCE_PASSWORD=1@mChampHealth" \
  --set-env-vars="SPRING_DATASOURCE_DRIVERCLASSNAME=org.postgresql.Driver" \
  --set-env-vars="SPRING_JPA_PROPERTIES_HIBERNATE_DIALECT=ca.uhn.fhir.jpa.model.dialect.HapiFhirPostgresDialect" \
  --add-cloudsql-instances=$CLOUD_SQL_CONNECTION

# Get the service URL
SERVICE_URL=$(gcloud run services describe $SERVICE_NAME --region=$REGION --format="value(status.url)")

echo ""
echo "========================================="
echo "Deployment Complete!"
echo "========================================="
echo "Service URL: $SERVICE_URL"
echo "FHIR Endpoint: ${SERVICE_URL}/fhir"
echo "Metadata: ${SERVICE_URL}/fhir/metadata"
echo "========================================="
echo ""
echo "Test the deployment with:"
echo "curl ${SERVICE_URL}/fhir/metadata"
