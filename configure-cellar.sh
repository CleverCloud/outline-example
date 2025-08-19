# Creating the S3 bucket
pip install s3cmd
cat > .s3cfg << EOF
[default]
access_key = $CELLAR_ADDON_KEY_ID
secret_key = $CELLAR_ADDON_KEY_SECRET
host_base = $CELLAR_ADDON_HOST
host_bucket = $CELLAR_ADDON_HOST
use_https = True
EOF
# Create the bucket
s3cmd mb s3://$BUCKET_NAME -c .s3cfg

# Set CORS 
cat > .s3cors << 'EOF'
<CORSConfiguration>
  <CORSRule>
    <AllowedOrigin>*</AllowedOrigin>
    <AllowedMethod>GET</AllowedMethod>
    <AllowedMethod>PUT</AllowedMethod>
    <AllowedMethod>POST</AllowedMethod>
    <AllowedMethod>DELETE</AllowedMethod>
    <AllowedHeader>*</AllowedHeader>
    <ExposeHeader>ETag</ExposeHeader>
    <MaxAgeSeconds>3000</MaxAgeSeconds>
  </CORSRule>
</CORSConfiguration>
EOF
s3cmd setcors .s3cors s3://$BUCKET_NAME -c .s3cfg

cat > .s3policy << EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "PublicReadForGetBucketObjects",
      "Effect": "Allow",
      "Principal": "*",
      "Action": ["s3:GetObject"],
      "Resource": ["arn:aws:s3:::$BUCKET/*"]
    }
  ]
}
EOF
s3cmd setpolicy .s3policy s3://$BUCKET_NAME -c .s3cfg

