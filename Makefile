CLUSTER_NAME     ?= todolist
NAMESPACE        ?= todolist
RELEASE          ?= todolist
IMAGE            ?= todolist-app:local
CHART_DIR        ?= charts/todolist
LOCAL_VALUES     ?= $(CHART_DIR)/values-local.yaml
HOST_PORT        ?= 8080
EXPECTED_CONTEXT ?= k3d-$(CLUSTER_NAME)

.DEFAULT_GOAL := help

.PHONY: help build cluster import deploy wait status logs health pf restart up down destroy clean check-context

help:
	@echo "Targets:"
	@echo "  make up        - build image, create cluster, import, deploy with Helm, wait for ready"
	@echo "  make build     - build the Docker image ($(IMAGE))"
	@echo "  make cluster   - create the k3d cluster (port $(HOST_PORT):80)"
	@echo "  make import    - import the image into the cluster"
	@echo "  make deploy    - helm upgrade --install using $(LOCAL_VALUES)"
	@echo "  make wait      - wait until postgres and app are ready"
	@echo "  make status    - show pods and ingress status"
	@echo "  make logs      - tail the application logs"
	@echo "  make health    - check the app health endpoint (fails on HTTP error)"
	@echo "  make pf        - port-forward the app to localhost:5000"
	@echo "  make restart   - restart the app deployment (pick up a rebuilt image)"
	@echo "  make down      - uninstall the release and delete the namespace (keeps the cluster)"
	@echo "  make destroy   - delete the whole cluster"
	@echo "  make clean     - undeploy and delete the cluster"

build:
	docker build -t $(IMAGE) .

check-context:
	@ctx="$$(kubectl config current-context 2>/dev/null)"; \
	if [ "$$ctx" != "$(EXPECTED_CONTEXT)" ]; then \
		echo "kubectl context is '$$ctx', expected '$(EXPECTED_CONTEXT)'."; \
		echo "Switch with: kubectl config use-context $(EXPECTED_CONTEXT)"; \
		exit 1; \
	fi

cluster:
	@if k3d cluster list $(CLUSTER_NAME) >/dev/null 2>&1; then \
		echo "Cluster '$(CLUSTER_NAME)' already exists."; \
	else \
		k3d cluster create $(CLUSTER_NAME) --agents 1 --port "$(HOST_PORT):80@loadbalancer"; \
	fi

import:
	k3d image import $(IMAGE) -c $(CLUSTER_NAME)

deploy: check-context
	helm upgrade --install $(RELEASE) $(CHART_DIR) \
		--namespace $(NAMESPACE) --create-namespace \
		-f $(LOCAL_VALUES)

wait: check-context
	kubectl -n $(NAMESPACE) rollout status deploy/$(RELEASE)-postgres --timeout=180s
	kubectl -n $(NAMESPACE) rollout status deploy/$(RELEASE) --timeout=180s
	@echo "Ready. Open http://localhost:$(HOST_PORT) in your browser."

status: check-context
	kubectl -n $(NAMESPACE) get pods -o wide
	@echo "---"
	kubectl -n $(NAMESPACE) get ingress

logs: check-context
	kubectl -n $(NAMESPACE) logs -l app.kubernetes.io/component=app -f

health: check-context
	@curl -fsS -m 5 http://localhost:$(HOST_PORT)/healthz && echo

pf: check-context
	kubectl -n $(NAMESPACE) port-forward svc/$(RELEASE) 5000:80

restart: check-context
	kubectl -n $(NAMESPACE) rollout restart deploy/$(RELEASE)

up: build cluster import deploy wait

down: check-context
	helm uninstall $(RELEASE) --namespace $(NAMESPACE) --ignore-not-found
	kubectl delete namespace $(NAMESPACE) --ignore-not-found

destroy:
	k3d cluster delete $(CLUSTER_NAME)

clean: down destroy
	@echo "Cleaned up."
