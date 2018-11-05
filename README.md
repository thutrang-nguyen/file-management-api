**File Management API**
----
  A simple CRUD File Management API. To create, retrieve, update, delete text-based files.
  Also optimized for minimal storage by reuse the content with same MD5 hash.

## Brief Architecture
The project includes Terraform script to provision resources on AWS.
The project uses AWS Fargate as computing resource, DynamoDB as Key-Value database storage and S3 bucket as content storage.

## How to build
### Docker 
```
# Set build environment variables
export DOCKER_REGISTRY=
export PROJECT_NAME=
export BRANCH_NAME=
export AWS_DEFAULT_REGION=

# Build docker image
make build

# Push docker image to repository
make push

# Run application docker container
# Note that .env file is required
make run

# Clean project
make clean
```
### AWS
The author uses Terraform as the tool to provision AWS resources.
Download Terraform : https://www.terraform.io/downloads.html
AWS Access Key and Secret Key pair with Administrator permissions is required to use the script.

```
# Initiate Terraform
terraform init ./terraform

# Plan resource updates / creations
terraform plan --var aws_access_key=$AWS_ACCESS_KEY --var aws_secret_key=$AWS_SECRET_KEY -out=tfplan ./terraform

# Run Plan
terraform apply tfplan

# Get API endpoint
/bin/bash ./scripts/get_fargate_instance_public_ip.sh $( terraform output file_management_api_fargate_cluster )
```

## API 
* **URL**
http://<endpoint>:5000/file/<file_name> 

* **Method:**
  
  `GET` : Retrieve file by name

* **Success Response:**

  * **Code:** 200 <br />
    **Content:** `bar`
 
* **Error Response:**

  * **Code:** 404 NOT FOUND <br />
    **Content:** `{ "error" : "File not found" } `

* **Sample Call:**

  ```
  curl --request GET \
  --url http://127.0.0.1:5000/file/foo
  ```

----
* **Method:**
  
  `POST` : Create new file; Only except raw string or TXT or JSON file

* **Data Params**

  ```
  -d 'raw'
  or
  -d file://foo.txt
  or 
  -d file://foo.json
  ```

* **Success Response:**

  * **Code:** 201 <br />
    **Content:** `{ "message" : "created new file" }`
 
* **Error Response:**

  * **Code:** 400 BAD REQUEST <br />
    **Content:** `{ "error" : "Bad request" }`

  OR

  * **Code:** 400 BAD REQUEST <br />
    **Content:** `{ "error" : "File exists" }`

* **Sample Call:**

  ```
  curl --request POST \
  --url http://127.0.0.1:5000/file/foo
  -d 'bar'
  ```

----
* **Method:**
  
  `PUT` : Update existing file or Upload new file; Only except raw string or TXT or JSON file

* **Data Params**

  ```
  -d 'raw'
  or
  -d file://foo.txt
  or 
  -d file://foo.json
  ```

* **Success Response:**

  * **Code:** 200 <br />
    **Content:** `{ "message" : "updated existing file" }`

  OR

  * **Code:** 201 <br />
    **Content:** `{ "message" : "created new file" }`
 
* **Error Response:**

  * **Code:** 400 BAD REQUEST <br />
    **Content:** `{ "error" : "Bad request" }`

* **Sample Call:**

  ```
  curl --request PUT \
  --url http://127.0.0.1:5000/file/foo
  -d 'bar'
  ```

----
* **Method:**
  
  `DELETE` : Delete existing file

* **Success Response:**
  
  * **Code:** 200 <br />
    **Content:** `{ "message" : "deleted file" }`
 
* **Error Response:**

  * **Code:** 404 NOT FOUND <br />
    **Content:** `{ "error" : "File not found" } `

* **Sample Call:**

  ```
  curl --request DELETE \
  --url http://127.0.0.1:5000/file/foo
  ```


* **Possible improvement:**
  The API can be deployed to a private subnet and be routed by AWS ALB. Another posibility is to refactor the API to use AWS Lambda.
  


