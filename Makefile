CLUSTER_NAME ?= todolist
NAMESPACE    ?= todolist
IMAGE        ?= todolist-app:local
K8S_DIR      ?= k8s
HOST_PORT    ?= 8080

.DEFAULT_GOAL := help

.PHONY: help build cluster import deploy wait status logs health pf up down destroy clean

help:
	@echo "Targets:"
	@echo "  make up        - build image, create cluster, import, deploy, wait for ready"
	@echo "  make build     - build the Docker image ($(IMAGE))"
	@echo "  make cluster   - create the k3d cluster (port $(HOST_PORT):80)"
	@echo "  make import    - import the image into the cluster"
	@echo "  make deploy    - apply all manifests from $(K8S_DIR)/"
	@echo "  make wait      - wait until postgres and app are ready"
	@echo "  make status    - show pods and ingress status"
	@echo "  make logs      - tail the application logs"
	@echo "  make health    - check the app health endpoint"
	@echo "  make pf        - port-forward the app to localhost:5000"
	@echo "  make down      - undeploy everything (keeps the cluster)"
	@echo "  make destroy   - delete the whole cluster"
	@echo "  make clean     - undeploy and delete the cluster"

build:
	docker build -t $(IMAGE) .

cluster:
	@if k3d cluster list $(CLUSTER_NAME) >/dev/null 2>&1; then \
		echo "Cluster '$(CLUSTER_NAME)' already exists."; \
	else \
		k3d cluster create $(CLUSTER_NAME) --agents 1 --port "$(HOST_PORT):80@loadbalancer"; \
	fi

import:
	k3d image import $(IMAGE) -c $(CLUSTER_NAME)

deploy:
	kubectl apply -f $(K8S_DIR)/namespace.yaml
	kubectl apply -f $(K8S_DIR)/configmap.yaml
	kubectl apply -f $(K8S_DIR)/secret.yaml
	kubectl apply -f $(K8S_DIR)/postgres.yaml
	kubectl apply -f $(K8S_DIR)/rbac.yaml
	kubectl apply -f $(K8S_DIR)/deployment.yaml
	kubectl apply -f $(K8S_DIR)/service.yaml
	kubectl apply -f $(K8S_DIR)/ingress.yaml
	kubectl apply -f $(K8S_DIR)/cronjob.yaml
	kubectl apply -f $(K8S_DIR)/hpa.yaml

wait:
	kubectl -n $(NAMESPACE) rollout status deploy/postgres --timeout=180s
	kubectl -n $(NAMESPACE) rollout status deploy/todolist-app --timeout=180s
	@echo "Ready. Open http://localhost:$(HOST_PORT) in your browser."

status:
	kubectl -n $(NAMESPACE) get pods -o wide
	@echo "---"
	kubectl -n $(NAMESPACE) get ingress

logs:
	kubectl -n $(NAMESPACE) logs -l app=todolist-app -f

health:
	@curl -sS -m 5 http://localhost:$(HOST_PORT)/healthz -H "Host: todolist.localhost"; echo

pf:
	kubectl -n $(NAMESPACE) port-forward svc/todolist-app 5000:80

up: build cluster import deploy wait

down:
	kubectl delete -f $(K8S_DIR)/namespace.yaml --ignore-not-found

destroy:
	k3d cluster delete $(CLUSTER_NAME)

clean: down destroy
	@echo "Cleaned up."