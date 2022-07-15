docker build -t switkowski/topic-model-with-args --progress tty .
docker tag switkowski/topic-model-with-args:latest 003358677937.dkr.ecr.us-east-1.amazonaws.com/topic-model-with-args
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin 003358677937.dkr.ecr.us-east-1.amazonaws.com
docker push 003358677937.dkr.ecr.us-east-1.amazonaws.com/topic-model-with-args:latest