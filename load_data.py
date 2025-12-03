import os
import requests
import json
import glob

# Configuration
FHIR_SERVER_URL = "http://localhost:8090/fhir"
DATA_DIR = "/Users/ben/Downloads/synthea_sample_data_fhir_latest"

def load_data():
    # Find all JSON files in the directory
    files = glob.glob(os.path.join(DATA_DIR, "*.json"))
    
    if not files:
        print(f"No JSON files found in {DATA_DIR}")
        return

    # Prioritize practitioner and hospital information files
    def get_priority(filename):
        base = os.path.basename(filename)
        if "practitionerInformation" in base:
            return 0
        if "hospitalInformation" in base:
            return 1
        return 2

    files.sort(key=get_priority)

    print(f"Found {len(files)} files to load.")
    
    success_count = 0
    error_count = 0

    for i, file_path in enumerate(files):
        try:
            with open(file_path, 'r') as f:
                data = json.load(f)
            
            # Determine the resource type (assuming Bundle or single Resource)
            resource_type = data.get('resourceType')
            
            if not resource_type:
                print(f"Skipping {os.path.basename(file_path)}: No resourceType found.")
                continue

            # Construct URL (if it's a Bundle, we usually post to root; if single resource, to /ResourceType)
            # But for transaction bundles, posting to root is correct.
            # Synthea usually produces Bundles.
            url = FHIR_SERVER_URL
            
            headers = {'Content-Type': 'application/fhir+json'}
            
            response = requests.post(url, json=data, headers=headers)
            
            if response.status_code in [200, 201]:
                success_count += 1
                print(f"[{i+1}/{len(files)}] Successfully loaded {os.path.basename(file_path)}")
            else:
                error_count += 1
                print(f"[{i+1}/{len(files)}] Failed to load {os.path.basename(file_path)}: {response.status_code} - {response.text[:100]}")
                
        except Exception as e:
            error_count += 1
            print(f"[{i+1}/{len(files)}] Error processing {os.path.basename(file_path)}: {str(e)}")

    print("-" * 30)
    print(f"Finished loading data.")
    print(f"Success: {success_count}")
    print(f"Errors: {error_count}")

if __name__ == "__main__":
    load_data()
