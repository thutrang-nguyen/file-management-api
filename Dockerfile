FROM python:2.7.15-alpine3.7
LABEL maintainer="thutrang111793@gmail.com"

COPY . /usr/src/file-management
WORKDIR /usr/src/file-management

RUN pip install -r requirements.txt

ENV FLASK_APP file_api
EXPOSE 5000
CMD ["flask", "run", "--host=0.0.0.0"]
