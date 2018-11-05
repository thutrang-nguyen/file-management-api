from flask import (
    Flask, Blueprint, request, make_response, jsonify, send_file, after_this_request
)
import os, boto3, hashlib
from boto3.dynamodb.conditions import Key, Attr
from botocore.exceptions import ClientError

bp = Blueprint('api', __name__, url_prefix='/file')

# Create temporary AWS session 
session = boto3.session.Session()

# Initiate DynamoDB Table resouce
dynamodb = session.resource('dynamodb')
file_table = dynamodb.Table(os.environ.get("FILE_API_DYNAMODB_TABLE"))

# Initiate S3 client
s3_client = session.client('s3')
s3_bucket = os.environ.get("FILE_API_S3_BUCKET")

# Create temporary directories if not found
if not os.path.exists('./dl_tmp'):
    os.makedirs('./dl_tmp')
if not os.path.exists('./ul_tmp'):
    os.makedirs('./ul_tmp')

ALLOWED_FILE_EXTENSIONS = set(['json', 'txt'])


@bp.route('/<name>', methods=['GET'])
def get_file(name):
    # Find metadata in DynamoDB
    result = file_table.get_item(
        Key={
            'Name': name,
        },
        )
    # Check if file exists
    if 'Item' not in result:
        return make_response(jsonify( { 'error': 'File not found' } ), 404)
    # Found file
    file_location = os.path.join("./dl_tmp/", name)
    s3_client.download_file(s3_bucket, result['Item']['Hash'], file_location)
    # Remove file after request completes
    @after_this_request
    def remove_file(response):
        os.remove(file_location)
        return response
    return send_file(os.path.join("../dl_tmp/", name))

@bp.route("/<name>", methods=['POST', 'PUT'])
def create_file(name):
    # Download file to temporary directory
    # Check if user sends raw string as upload file in request
    if request.data :
        # Write data in temporary file
        file_extension = 'txt' or request.content_encoding
        file_name = "{0}.{1}".format(name , file_extension)
        file_location = os.path.join("./ul_tmp/", file_name)
        with open( file_location, "w") as file:
            file.write("{0}".format(request.data))
    # Check if user sends data as file
    elif 'file' in request.files :
        file = request.files['file']
        # Check if browser submit an empty file when user does not select file
        if file.filename == '':
            return make_response(jsonify( { 'error': 'Bad request' } ), 400)
        # Save file from request to temporary file
        if file and allowed_file(file.filename):
            file_extension = file_name.rsplit('.', 1)[1].lower()
            file_name = "{0}.{1}".format(name , file_extension)
            file_location = os.path.join("./ul_tmp/", file_name)
            file.save(file_location)
        else :
            return make_response(jsonify( { 'error': 'Bad request' } ), 400)
    # No file is sent with request
    else:
        return make_response(jsonify( { 'error': 'Bad request' } ), 400)
    
    file_hash = hashlib.md5(open(file_location,'rb').read()).hexdigest()

    if request.method == 'POST':
        # Save metadata of file to DynamoDB
        try:
            result = file_table.put_item(
                Item={
                    'Name': name,
                    'Hash': file_hash,
                    'Ext': file_extension,
                },
                ConditionExpression='attribute_not_exists(#N)',
                ExpressionAttributeNames={'#N': 'Name'}
                )
        except ClientError as e:
            # Check if file with same name, different hash
            # Return 400 to prevent overwrite
            if e.response['Error']['Code'] == 'ConditionalCheckFailedException':
                return make_response(jsonify( { 'error': 'File exists' } ), 400)

    elif request.method == 'PUT':
        # Save metadata of file to DynamoDB
        result = file_table.put_item(
            Item={
                'Name': name,
                'Hash': file_hash,
                'Ext': file_extension,
            },
            ReturnValues='ALL_OLD',
            )
        
        # Updated file
        if 'Attributes' in result :
            if result['Attributes']['Hash'] != file_hash:
                # Upload file to S3
                upload_file_with_hash(file_location, file_hash)
                # Remove file with old hash
                delete_file_with_hash(result['Attributes']['Hash'])
            # Remove temporary file
            os.remove(file_location)
            return make_response(jsonify({'message':'updated existing file'}), 200)
        pass

    # Upload new file to S3
    upload_file_with_hash(file_location, file_hash)
    # Remove temporary file
    os.remove(file_location)
    return make_response(jsonify({'message':'created new file'}), 201)

@bp.route("/<name>", methods=['DELETE'])
def delete_file(name):
    # Find metadata in DynamoDB
    hash_result = file_table.get_item(
        Key={
            'Name': name,
        },
        )
    # Check if file exists
    if 'Item' not in hash_result:
        return make_response(jsonify( { 'error': 'File not found' } ), 404)

    # Remove file
    file_hash = hash_result['Item']['Hash']
    # Delete file record in DynamoDB
    file_table.delete_item(
        Key={
            'Name': name,
        },
        )
    # Remove file content in S3 if no other file refers to same content
    delete_file_with_hash(file_hash)
    return make_response(jsonify({'message':'deleted file'}), 200)

# Minimal file extension check
def allowed_file(file_name):
    return '.' in file_name and file_name.rsplit('.', 1)[1].lower() in ALLOWED_FILE_EXTENSIONS

# Upload file to S3 bucket if file with hash has not been uploaded
def upload_file_with_hash(file_location, file_hash):
    # Check if file with same hash has been uploaded
    file_content_exists = s3_client.list_objects_v2(
        Bucket=s3_bucket,
        Prefix=file_hash,
        MaxKeys=1)
    # Upload if file hash does not exist
    if file_content_exists['KeyCount'] == 0 :
        s3_client.upload_file(file_location, s3_bucket, file_hash)

# Remove file if no other file reference to that hash
def delete_file_with_hash(file_hash):
    # Find hash count
    result = file_table.scan(
        FilterExpression=Attr('Hash').eq(file_hash),
        )

    # Check if no file with the hash value
    if result['Count'] == 0:
        s3_client.delete_object(Bucket=s3_bucket, Key=file_hash)
    pass