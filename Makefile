.PHONY: cleanup generate up down ps logsf addressbook

cleanup: down
	perl cleanup.pl
generate:
	perl generate_node_keys.pl
up:
	cd testcompose && docker compose up -d || true
down:
	cd testcompose && docker compose down || true
ps:
	cd testcompose && docker compose ps || true
logsf:
	cd testcompose && docker compose logs -f || true
addressbook:
	perl addressbook.pl
