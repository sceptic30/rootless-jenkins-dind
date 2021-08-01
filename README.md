# Rootless Jenkins With Docker-In-Docker Support

## Building The Image
To build your image you will only have to pass an argument to a bash script. The script will take care of the technical stuff.
```sh
git clone https://github.com/sceptic30/rootless-jenkins-dind
cd rootless-jenkins-dind
chmod +x install.sh
source ./install.sh your_image_tag
```
## Run the image Locally
```sh
docker run -d --rm --name jenkins -p 8080:8080 $IMAGE_TAG
```
> Current Image running in non-priviledged mode, under the user 'jenkins'