if(-e "testcompose") {
	`cd testcompose && docker compose down`;
}
`sudo rm -rf testartifacts testcompose testdata testkeys testspecs`;
