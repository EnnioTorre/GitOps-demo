curl -X POST \
  "http://el-demobakery-github-listener-bookinfo.apps.osdev.cp.cloud" \
  -H 'Content-Type: application/json' \
  -H 'X-Hub-Signature: sha1=2da37dcb9404ff17b714ee7a505c384758ddeb7b' \
  -d '{
    "ref": "refs/heads/develop",
	"repository":
	{
        "name": "vaadin-demo-bakery-app",
		"url": "https://github.com/EnnioTorre/vaadin-demo-bakery-app.git"
	},
     "head_commit": {
    "id": "3a0ee4c7b384d31ad2a706cd78c98de4b024e8c9",
    "tree_id": "27f342ec2ddac68a801a313d7396c74194f03d9c",
    "distinct": true,
    "message": "some changes",
    "timestamp": "2020-10-07T14:43:03+02:00",
    "url": "https://github.com/EnnioTorre/appbackery-cicd-demo/commit/225d59e3bb81a019d72fc802b4ed198284530a80",
    "author": {
      "name": "Ennio Torre",
      "email": "ennio.torre@cargo-partner.com"
    }}
}'