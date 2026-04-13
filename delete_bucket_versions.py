import boto3

BUCKET = "security-monitoring-lab-app-268527429806"
REGION = "us-east-2"

s3 = boto3.client("s3", region_name=REGION)

def delete_all_versions():
    paginator = s3.get_paginator("list_object_versions")
    total_deleted = 0

    for page in paginator.paginate(Bucket=BUCKET):
        objects_to_delete = []

        for v in page.get("Versions", []):
            objects_to_delete.append({"Key": v["Key"], "VersionId": v["VersionId"]})

        for dm in page.get("DeleteMarkers", []):
            objects_to_delete.append({"Key": dm["Key"], "VersionId": dm["VersionId"]})

        if not objects_to_delete:
            continue

        # S3 delete_objects supports up to 1000 per request
        for i in range(0, len(objects_to_delete), 1000):
            batch = objects_to_delete[i:i+1000]
            response = s3.delete_objects(
                Bucket=BUCKET,
                Delete={"Objects": batch, "Quiet": False}
            )
            deleted = response.get("Deleted", [])
            errors = response.get("Errors", [])
            total_deleted += len(deleted)
            if errors:
                for e in errors:
                    print(f"ERROR: {e['Key']} ({e['VersionId']}): {e['Code']} - {e['Message']}")
            print(f"Deleted {len(deleted)} objects (running total: {total_deleted})")

    print(f"\nDone. Total deleted: {total_deleted}")

if __name__ == "__main__":
    delete_all_versions()
