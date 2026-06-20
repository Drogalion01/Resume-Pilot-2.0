import logging
from typing import Optional
from io import BytesIO

import aioboto3
from botocore.exceptions import ClientError

from app.config import settings

logger = logging.getLogger(__name__)

class S3Service:
    def __init__(self):
        self.bucket = settings.S3_BUCKET_NAME
        self.session = aioboto3.Session(
            aws_access_key_id=settings.AWS_ACCESS_KEY_ID,
            aws_secret_access_key=settings.AWS_SECRET_ACCESS_KEY,
            region_name=settings.AWS_REGION
        ) if settings.AWS_ACCESS_KEY_ID else None

    async def upload_file(self, file_bytes: bytes, object_name: str, content_type: str = 'application/pdf') -> Optional[str]:
        if not self.session or not self.bucket:
            logger.warning("S3 credentials not configured. Skipping S3 upload.")
            return None
            
        try:
            async with self.session.client("s3") as s3:
                await s3.put_object(
                    Bucket=self.bucket,
                    Key=object_name,
                    Body=file_bytes,
                    ContentType=content_type,
                    # ServerSideEncryption='AES256'
                )
                return f"s3://{self.bucket}/{object_name}"
        except ClientError as e:
            logger.error(f"Failed to upload to S3: {e}")
            return None

    async def generate_presigned_url(self, object_name: str, expiration: int = 3600) -> Optional[str]:
        if not self.session or not self.bucket:
            return None
            
        try:
            async with self.session.client("s3") as s3:
                response = await s3.generate_presigned_url(
                    'get_object',
                    Params={'Bucket': self.bucket, 'Key': object_name},
                    ExpiresIn=expiration
                )
                return response
        except ClientError as e:
            logger.error(f"Failed to generate presigned URL: {e}")
            return None

    async def delete_file(self, object_name: str) -> bool:
        if not self.session or not self.bucket:
            return False
            
        try:
            async with self.session.client("s3") as s3:
                await s3.delete_object(Bucket=self.bucket, Key=object_name)
                return True
        except ClientError as e:
            logger.error(f"Failed to delete from S3: {e}")
            return False

s3_service = S3Service()
