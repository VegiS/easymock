#!/bin/bash

# This script expects:
# - the version to be deployed as the first parameter
# - jira_user / jira_password to be available environment variables
# - gpg_passphrase to be an environment variable
# - bintray_user to be an environment variable
# - bintray_api_key to be an environment variable

# to exit in case of error
set -e
# to see what's going on
set -v

function pause {
    echo
    read -p "Press [enter]  to continue"
}

# Make sure the script is launched from the project root directory
if [ "$(dirname $0)" != "." ]; then
    echo "The script should be launched from EasyMock root directory"
    exit 1
fi

# Get the version to deliver
version=$(sed -n 's/.*>\(.*\)-SNAPSHOT<.*/\1/p' pom.xml | head -1)
tag=easymock-${version}

[ -z "$version" ] && echo "Only snapshots can be delivered" && exit 1

# Get we have the environment variable we need
message="should be an environment variable"
[ -z "$gpg_passphrase" ] && echo "gpg_passphrase $message" && exit 1
[ -z "$github_user" ] && echo "github_user $message" && exit 1
[ -z "$github_password" ] && echo "github_password $message" && exit 1
#[ -z "$bintray_api_key" ] && echo "bintray_api_key $message" && exit 1
#[ -z "$bintray_user" ] && echo "bintray_user $message" && exit 1

# Update the version
echo
echo "************** Delivering version $version ****************"
echo

echo "Generate the changelog"
curl -v -u "${github_user}:${github_password}" \
    -XGET -H "Accept: application/vnd.github.v3+json" \
    "https://api.github.com/repos/easymock/easymock/issues?milestone=$version&state=all"
echo "TDB... Should stop the deploy if everything isn't closed"


echo "Start clean"
mvn clean -Pall

echo "Make sure we have a target directory"
test ! -d target && mkdir target

echo "Update the Maven version"
mvn versions:set -DnewVersion=${version} -Pall

echo "Build and deploy"
mvn -T 8.0C deploy -PfullBuild,deployBuild,all

echo "Please publish on bintray and sync with Maven central"
open "https://bintray.com/easymock/maven/easymock/$version"

pause

echo "Commit everything"
mvn versions:commit -Pall
git commit -am "Move to version ${version}"
git tag $tag
git status
git push
git push --tags

pause

# currently not working because of the description that is multiline. Probably need to replace with \n
echo "Create the github release"
description="$(cat ReleaseNotes.md)"
content="{\"tag_name\": \"$tag\", \"target_commitish\": \"master\", \"name\": \"$tag\", \"body\": \"$description\", \"draft\": false, \"prerelease\": false }"
curl -v -u "${github_user}:${github_password}" \
  -XPOST -H "Accept: application/vnd.github.v3+json" \
  -d "$content" \
  "https://api.github.com/repos/easymock/easymock/releases"

pause

echo "Deploy the bundle to Bintray"
date=$(date )
content="{ \"name\": \"$version\", \"desc\": \"$version\", \"released\": \"${date}T00:00:00.000Z\", \"github_use_tag_release_notes\": true, \"vcs_tag\": \"easymock-$version\" }"
curl -v -XPOST -H "Content-Type: application/json" -H "X-GPG-PASSPHRASE: ${gpg_passphrase}" -u${bintray_user}:${bintray_api_key} \
    -d "$content" \
    https://api.bintray.com/packages/easymock/distributions/easymock/versions
# Then set as downloadle
# Set the release notes as coming from github in the version

pause

echo "Update Javadoc"
git rm -rf website/api
cp -r core/target/apidocs website/api

pause

echo "Update the version on the website"
sed -i '' "s/latest_version: .*/latest_version: $version/" 'website/_config.yml'

echo "Commit the new website"
git add website
git commit -m "Upgrade website to version $version"

echo "Update website"
./deploy-website.sh

echo "Start new version"
nextVersion=$version+1
mvn versions:set -DnewVersion=${nextVersion} -Pall
mvn versions:commit
git commit -am "Starting to develop version ${nextVersion}"

echo
echo "Job done!"
echo
