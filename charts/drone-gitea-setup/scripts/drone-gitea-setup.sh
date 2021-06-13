#!/bin/sh
DOMAIN=$DRONE_DOMAIN
GITEA_SERVER=https://gitea.$DOMAIN
GITEA_API_URL=$GITEA_SERVER/api/v1
GITEA_ADMIN_CREDS=gitea_admin:r8sA8CPHD9!bt6d

DRONE_USER=drone
DRONE_PASS=drone
DRONE_SERVER=https://drone.$DOMAIN
DRONE_CREDS=$DRONE_USER:$DRONE_PASS
DRONE_REDIRECT_URL=$DRONE_SERVER/login

echo Checking for drone user...
curl -s -u $GITEA_ADMIN_CREDS $GITEA_API_URL/admin/users \
    | jq -e ".[] | select(.username == \"$DRONE_USER\")"

if [ ! $? -eq 0 ]; then
    echo Creating drone user...
    curl -s -u $GITEA_ADMIN_CREDS -X POST $GITEA_API_URL/admin/users \
    -H "Content-Type: application/json" \
    -d "{ \
      \"email\": \"$DRONE_USER@$(echo $DRONE_SERVER | awk -F[/:] '{print $4}')\", \
      \"username\": \"$DRONE_USER\", \
      \"full_name\": \"$DRONE_USER\", \
      \"login_name\": \"$DRONE_USER\", \
      \"password\": \"$DRONE_PASS\", \
      \"must_change_password\": false, \
      \"send_notify\": false, \
      \"source_id\": 0 \
    }" | jq '.'
fi

echo Checking $DRONE_USER oauth apps...
curl -s -u $DRONE_CREDS $GITEA_API_URL/user/applications/oauth2 \
    | jq -e -c '.[] | select(.name == "drone")' | while read app; do
    echo Deleting old application with id $(echo $app | jq '.id')
    curl -s -u $DRONE_CREDS -X DELETE $GITEA_API_URL/user/applications/oauth2/$(echo $app | jq '.id')
done

echo Creating drone oauth app
pair=`curl -s -u $DRONE_CREDS -X POST $GITEA_API_URL/user/applications/oauth2 \
    -H "Content-Type: application/json" \
    -d "{ \
      \"name\": \"drone\", \
      \"redirect_uris\": [ \"$DRONE_REDIRECT_URL\" ] \
    }" | jq -r '[.client_id, .client_secret] | join(" ")'`
cid=`echo $pair | awk '{print $1}'`
csr=`echo $pair | awk '{print $2}'`

echo client_id $cid
echo client_secret $csr

export DRONE_GITEA_SERVER=$GITEA_SERVER
export DRONE_GITEA_CLIENT_ID=$cid
export DRONE_GITEA_CLIENT_SECRET=$csr
