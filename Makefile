SHELL := /bin/bash

.PHONY: swag-init
swag-init:
	swag init -g internal/routes/routes.go --output "cmd/api/docs"
	swag fmt

.PHONY: start-web-app 
start-web-app:
	@$(MAKE) LOG MSG_TYPE=info LOG_MESSAGE="Starting web app..."
	@$(MAKE) start-database
	@$(MAKE) LOG MSG_TYPE=success LOG_MESSAGE="Started database"
	@go run cmd/api/main.go

.PHONY: stop-web-app
stop-web-app:
	@$(MAKE) LOG MSG_TYPE=info LOG_MESSAGE="Stopping web app..."
	@$(MAKE) stop-database
	@$(MAKE) LOG MSG_TYPE=success LOG_MESSAGE="Stopped database"

.PHONY: start-database
start-database:
	@$(MAKE) LOG MSG_TYPE=info LOG_MESSAGE="Starting database..."
	@docker compose up -d

.PHONY: stop-database
stop-database:
	@$(MAKE) LOG MSG_TYPE=info LOG_MESSAGE="Stopping database..."
	@docker compose down

run-unit-test:
	go test -cover ./internal/service ./internal/config ./internal/database ./internal/routes ./cmd/api

.PHONY: check-coverage
check-coverage:
	@$(MAKE) LOG MSG_TYPE=info LOG_MESSAGE="Running unit tests and generating coverage report..."
	go test -coverprofile=coverage.out ./internal/service ./internal/config ./internal/database ./cmd/routes ./cmd/api
	go tool cover -html=coverage.out -o coverage.html
	@$(MAKE) LOG MSG_TYPE=warn LOG_MESSAGE="Link to coverage report file: file://$$(PWD)/coverage.html"

.PHONY: view-coverage
view-coverage:
	@open -a "Google Chrome" file://$$(PWD)/coverage.html

LOG:
	@if [ "$(MSG_TYPE)" = "debug" ]; then \
		echo -e "\033[0;37m$(LOG_MESSAGE)\033[0m"; \
	elif [ "$(MSG_TYPE)" = "info" ]; then \
		echo -e "\033[0;36m$(LOG_MESSAGE)\033[0m"; \
	elif [ "$(MSG_TYPE)" = "warn" ]; then \
		echo -e "\033[0;33m$(LOG_MESSAGE)\033[0m"; \
	elif [ "$(MSG_TYPE)" = "success" ]; then \
		echo -e "\033[0;32m$(LOG_MESSAGE)\033[0m✓"; \
	elif [ "$(MSG_TYPE)" = "failure" ]; then \
		echo -e "\033[0;31m$(LOG_MESSAGE)\033[0m"; \
	else \
		echo -e "\033[0;37m$(LOG_MESSAGE)\033[0m"; \
	fi