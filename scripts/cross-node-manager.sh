#!/bin/bash

# 🎩 GENTLEMAN Cross-Node Service Manager
# Manages services across multiple nodes via Nebula mesh network

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# Load environment variables
if [ -f "auth.env" ]; then
    source auth.env
fi

# Node definitions (macOS compatible)
get_node_ip() {
    case "$1" in
        "rx-node") echo "192.168.100.10" ;;
        "m1-node") echo "192.168.100.20" ;;
        "i7-node") echo "192.168.100.30" ;;
        *) echo "" ;;
    esac
}

get_service_port() {
    case "$1" in
        # RX Node services
        "lm-studio") echo "1234" ;;
        "ollama") echo "11434" ;;
        # M1 Node services
        "keycloak") echo "8085" ;;
        "auth-sync") echo "8091" ;;
        "smtp-relay") echo "2525" ;;
        "service-registry") echo "8500" ;;
        "service-bridge") echo "8093" ;;
        # I7 Node services
        "web-client") echo "8080" ;;
        *) echo "" ;;
    esac
}

get_node_services() {
    case "$1" in
        "rx-node") echo "lm-studio ollama" ;;
        "m1-node") echo "keycloak auth-sync smtp-relay service-registry service-bridge" ;;
        "i7-node") echo "web-client" ;;
        *) echo "" ;;
    esac
}

show_help() {
    echo -e "${BLUE}🎩 GENTLEMAN Cross-Node Service Manager${NC}"
    echo "=================================================="
    echo ""
    echo "Usage: $0 [COMMAND] [OPTIONS]"
    echo ""
    echo "Commands:"
    echo "  status              Show status of all nodes and services"
    echo "  discover            Discover all services across nodes"
    echo "  deploy [node]       Deploy services to specific node"
    echo "  test-mesh           Test Nebula mesh connectivity"
    echo "  proxy [service]     Test service proxy functionality"
    echo "  health              Check health of all services"
    echo "  logs [service]      Show logs for a service"
    echo ""
    echo "Examples:"
    echo "  $0 status"
    echo "  $0 discover"
    echo "  $0 deploy m1-node"
    echo "  $0 proxy lm-studio"
    echo "  $0 health"
}

check_nebula_connectivity() {
    echo -e "${BLUE}🌐 Testing Nebula Mesh Connectivity...${NC}"
    
    for node in "rx-node" "m1-node" "i7-node"; do
        ip=$(get_node_ip "$node")
        echo -n "Testing $node ($ip): "
        
        if ping -c 1 -W 2 "$ip" >/dev/null 2>&1; then
            echo -e "${GREEN}✅ CONNECTED${NC}"
        else
            echo -e "${RED}❌ UNREACHABLE${NC}"
        fi
    done
}

discover_services() {
    echo -e "${BLUE}🔍 Discovering Services Across Nodes...${NC}"
    
    m1_ip=$(get_node_ip "m1-node")
    
    # Try to get service list from Consul
    if curl -s "http://$m1_ip:8500/v1/agent/services" >/dev/null 2>&1; then
        echo -e "${GREEN}✅ Service Registry Available${NC}"
        
        services=$(curl -s "http://$m1_ip:8500/v1/agent/services" | python3 -c "import sys,json; data=json.load(sys.stdin); print('\n'.join(data.keys()))" 2>/dev/null || echo "")
        
        if [ -n "$services" ]; then
            echo -e "${YELLOW}📋 Registered Services:${NC}"
            echo "$services" | while read -r service; do
                if [ -n "$service" ]; then
                    echo "  • $service"
                fi
            done
        else
            echo -e "${YELLOW}⚠️  No services registered yet${NC}"
        fi
    else
        echo -e "${RED}❌ Service Registry not available${NC}"
        echo -e "${YELLOW}💡 Starting manual discovery...${NC}"
        manual_service_discovery
    fi
}

manual_service_discovery() {
    echo -e "${BLUE}🔍 Manual Service Discovery...${NC}"
    
    for node in "rx-node" "m1-node" "i7-node"; do
        ip=$(get_node_ip "$node")
        services=$(get_node_services "$node")
        
        echo -e "${PURPLE}$node ($ip):${NC}"
        
        for service in $services; do
            port=$(get_service_port "$service")
            check_service_health "$ip" "$port" "$service"
        done
    done
}

check_service_health() {
    local ip="$1"
    local port="$2"
    local service="$3"
    
    echo -n "  • $service ($port): "
    
    if nc -z -w2 "$ip" "$port" 2>/dev/null; then
        echo -e "${GREEN}✅ HEALTHY${NC}"
    else
        echo -e "${RED}❌ DOWN${NC}"
    fi
}

test_service_proxy() {
    local service="$1"
    
    if [ -z "$service" ]; then
        echo -e "${RED}❌ Please specify a service to test${NC}"
        return 1
    fi
    
    echo -e "${BLUE}🔄 Testing Service Proxy for: $service${NC}"
    
    m1_ip=$(get_node_ip "m1-node")
    bridge_url="http://$m1_ip:8093"
    
    echo "Testing service discovery..."
    if curl -s "$bridge_url/services/$service" | python3 -c "import sys,json; json.load(sys.stdin); print('OK')" 2>/dev/null; then
        echo -e "${GREEN}✅ Service discovered successfully${NC}"
        
        echo "Testing proxy functionality..."
        if curl -s "$bridge_url/proxy/$service/health" >/dev/null 2>&1; then
            echo -e "${GREEN}✅ Proxy working${NC}"
        else
            echo -e "${YELLOW}⚠️  Proxy test failed (service may not have /health endpoint)${NC}"
        fi
    else
        echo -e "${RED}❌ Service not found in registry${NC}"
    fi
}

deploy_to_node() {
    local node="$1"
    
    if [ -z "$node" ]; then
        echo -e "${RED}❌ Please specify a node: rx-node, m1-node, or i7-node${NC}"
        return 1
    fi
    
    if [ -z "$(get_node_ip "$node")" ]; then
        echo -e "${RED}❌ Unknown node: $node${NC}"
        return 1
    fi
    
    echo -e "${BLUE}🚀 Deploying services to $node...${NC}"
    
    case "$node" in
        "rx-node")
            echo -e "${YELLOW}📦 RX Node deployment requires manual setup of LM Studio/Ollama${NC}"
            echo "Please ensure the following services are running:"
            echo "  • LM Studio on port 1234"
            echo "  • Ollama on port 11434"
            ;;
        "m1-node")
            echo -e "${YELLOW}📦 Deploying M1 Node services...${NC}"
            docker-compose -f docker-compose.auth.yml --env-file auth.env up -d
            ;;
        "i7-node")
            echo -e "${YELLOW}📦 I7 Node deployment requires web client setup${NC}"
            echo "Please deploy the web interface on the I7 node"
            ;;
    esac
}

show_status() {
    echo -e "${BLUE}🎩 GENTLEMAN Multi-Node Status${NC}"
    echo "=================================================="
    
    check_nebula_connectivity
    echo ""
    discover_services
}

show_health() {
    echo -e "${BLUE}🏥 GENTLEMAN Health Check${NC}"
    echo "=================================================="
    
    manual_service_discovery
    
    m1_ip=$(get_node_ip "m1-node")
    
    echo ""
    echo -e "${BLUE}🔍 Service Registry Health:${NC}"
    if curl -s "http://$m1_ip:8500/v1/status/leader" >/dev/null 2>&1; then
        echo -e "${GREEN}✅ Consul Leader Available${NC}"
    else
        echo -e "${RED}❌ Consul Not Available${NC}"
    fi
    
    echo ""
    echo -e "${BLUE}🌉 Service Bridge Health:${NC}"
    if curl -s "http://$m1_ip:8093/" >/dev/null 2>&1; then
        echo -e "${GREEN}✅ Service Bridge Running${NC}"
    else
        echo -e "${RED}❌ Service Bridge Down${NC}"
    fi
}

show_logs() {
    local service="$1"
    
    if [ -z "$service" ]; then
        echo -e "${RED}❌ Please specify a service${NC}"
        return 1
    fi
    
    echo -e "${BLUE}📋 Logs for: $service${NC}"
    
    # Try to find the service container
    if docker ps --format "table {{.Names}}" | grep -q "gentleman-$service"; then
        docker logs "gentleman-$service" --tail 50 --follow
    else
        echo -e "${RED}❌ Service container not found: gentleman-$service${NC}"
        echo "Available containers:"
        docker ps --format "table {{.Names}}" | grep gentleman- || echo "No GENTLEMAN containers running"
    fi
}

# Main command handling
case "${1:-help}" in
    "status")
        show_status
        ;;
    "discover")
        discover_services
        ;;
    "deploy")
        deploy_to_node "$2"
        ;;
    "test-mesh")
        check_nebula_connectivity
        ;;
    "proxy")
        test_service_proxy "$2"
        ;;
    "health")
        show_health
        ;;
    "logs")
        show_logs "$2"
        ;;
    "help"|*)
        show_help
        ;;
esac 