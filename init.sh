#!/bin/bash
read -p "Do you need to install node_exporter? (yes/no): " install_node_exporter_response
if [[ $install_node_exporter_response == "yes" ]]; then
	REPO="prometheus/node_exporter"
	LATEST_RELEASE_JSON=$(curl -s "https://api.github.com/repos/$REPO/releases/latest")
	LATEST_VERSION=$(echo $LATEST_RELEASE_JSON | jq -r '.tag_name' | cut -c 2-)
	curl -LO https://github.com/prometheus/node_exporter/releases/download/v${LATEST_VERSION}/node_exporter-${LATEST_VERSION}.linux-amd64.tar.gz
	tar xzf node_exporter-${LATEST_VERSION}.linux-amd64.tar.gz
	sudo mv node_exporter-${LATEST_VERSION}.linux-amd64/node_exporter /usr/local/bin/
	sudo rm -r node_exporter-${LATEST_VERSION}.linux-amd64*
	if id "node_exporter" &>/dev/null; then
		echo "User node_exporter already exists."
	else
		echo "Creating user node_exporter."
		sudo useradd --no-create-home --shell /bin/false node_exporter
	fi
	sudo chown node_exporter:node_exporter /usr/local/bin/node_exporter
	sudo tee /etc/systemd/system/node_exporter.service >/dev/null <<EOF
[Unit]
Description=Node Exporter
Wants=network-online.target
After=network-online.target

[Service]
User=node_exporter
Group=node_exporter
ExecStart=/usr/local/bin/node_exporter

[Install]
WantedBy=default.target
EOF
	sudo systemctl daemon-reload
	sudo systemctl start node_exporter
	sudo systemctl enable node_exporter
	echo "Node Exporter has been installed and started."
else
	echo "Skipping node_exporter installation."
fi


read -p "Do you need to install Docker Engine? (yes/no): " install_docker_response
if [[ $install_docker_response == "yes" ]]; then
	sudo apt-get update
	sudo apt-get install -y \
		ca-certificates \
		curl \
		gnupg \
		lsb-release
	curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
	echo \
		"deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
    $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list >/dev/null
	sudo apt-get update
	sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
	sudo usermod -aG docker $USER
	echo "Docker Engine has been installed and verified. Please log out and back in for group changes to take effect."
else
	echo "Skipping Docker Engine installation."
fi


echo "Configuring Prometheus settings..."
read -p "Enter the job name for the Prometheus target (default: node_exporter): " job_name
job_name=${job_name:-node_exporter}
read -p "Enter the target IP and port (default: 172.17.0.1): " target_ip
target_ip=${target_ip:-"172.17.0.1"}
cat <<EOF >etc-prometheus/prometheus.yml
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: "$job_name"
    static_configs:
      - targets: ["$target_ip:9100"]
  - job_name: story
    static_configs:
      - targets: ['$target_ip:26660']
EOF
echo "Prometheus configuration has been updated."
