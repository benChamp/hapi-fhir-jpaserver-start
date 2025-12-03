# Deploying HAPI FHIR to Google Cloud Run

This guide explains how to deploy the HAPI FHIR JPA Server to Google Cloud Run with Cloud SQL PostgreSQL.

## Prerequisites

- Google Cloud SDK (`gcloud`) installed and authenticated
- Docker installed locally
- GCP Project: `champ-pov-app-dev`
- Sufficient permissions to create Cloud Run, Cloud SQL, and VPC resources

## Architecture

- **Cloud Run**: Hosts the HAPI FHIR server (serverless, auto-scaling)
- **Cloud SQL**: PostgreSQL 15 database with private IP
- **VPC Connector**: Enables Cloud Run to access Cloud SQL via private network
- **Artifact Registry**: Stores Docker images
- **Region**: `us-west1`

## Deployment Steps

### 1. One-Time Setup

Run the setup script to provision all GCP infrastructure:

```bash
./setup-gcp.sh
```

This script will:
- Enable required GCP APIs
- Create Artifact Registry repository
- Set up VPC peering for private IP
- Create Cloud SQL instance with PostgreSQL 15
- Create VPC Access Connector
- Store database credentials in Secret Manager

**Note**: This step takes 10-15 minutes due to Cloud SQL instance creation.

### 2. Deploy the Application

Build and deploy the HAPI FHIR server:

```bash
./deploy.sh
```

This script will:
- Build the Docker image using the existing Dockerfile
- Push the image to Artifact Registry
- Deploy to Cloud Run with environment variables
- Connect Cloud Run to Cloud SQL via VPC connector

### 3. Verify Deployment

After deployment completes, test the FHIR server:

```bash
# The deploy script will output the service URL
# Test the metadata endpoint
curl https://hapi-fhir-server-XXXXX-uw.a.run.app/fhir/metadata
```

## Configuration

### Database Settings

- **Instance**: `hapi-fhir-db` (db-f1-micro)
- **Database**: `hapi`
- **User**: `postgres`
- **Connection**: Private IP via VPC connector

### Cloud Run Settings

- **Memory**: 2 GB
- **CPU**: 2 vCPU
- **Timeout**: 300 seconds
- **Min instances**: 0 (scales to zero when idle)
- **Max instances**: 10
- **Port**: 8080

## CI/CD with Cloud Build

To set up automated deployments from GitHub:

1. Connect your GitHub repository to Cloud Build:
   ```bash
   gcloud builds triggers create github \
     --repo-name=hapi-fhir-jpaserver-start \
     --repo-owner=benChamp \
     --branch-pattern="^main$" \
     --build-config=cloudbuild.yaml
   ```

2. Push changes to the `main` branch to trigger automatic deployment

## Cost Estimation

Approximate monthly costs for minimal usage:

- Cloud SQL (db-f1-micro): ~$10-15/month
- Cloud Run: ~$0-5/month (scales to zero)
- VPC Connector: ~$10/month
- Artifact Registry: ~$0.10/GB/month

**Total**: ~$20-30/month for dev/test environment

## Updating the Application

To deploy changes:

```bash
./deploy.sh
```

## Troubleshooting

### View Cloud Run Logs

```bash
gcloud run services logs read hapi-fhir-server --region=us-west1
```

### Connect to Cloud SQL

```bash
gcloud sql connect hapi-fhir-db --user=postgres --database=hapi
```

### Check Cloud Run Service

```bash
gcloud run services describe hapi-fhir-server --region=us-west1
```

## Cleanup

To delete all resources:

```bash
# Delete Cloud Run service
gcloud run services delete hapi-fhir-server --region=us-west1

# Delete Cloud SQL instance
gcloud sql instances delete hapi-fhir-db

# Delete VPC Connector
gcloud compute networks vpc-access connectors delete hapi-fhir-connector --region=us-west1

# Delete Artifact Registry repository
gcloud artifacts repositories delete hapi-fhir --location=us-west1
```

## Security Notes

- Database uses private IP (not accessible from internet)
- Cloud Run connects via VPC connector
- Consider using Secret Manager for database password in production
- Current setup allows unauthenticated access to FHIR API (add authentication for production)
