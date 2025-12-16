#!/bin/bash
# ============================================================================
# Script: 6-get-env.sh
# Description: Updates the .env file with latest values from Azure deployment
# Usage: ./scripts/6-get-env.sh
# ============================================================================

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script directory and workspace root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_ROOT="$(dirname "$SCRIPT_DIR")"
ENV_FILE="$WORKSPACE_ROOT/.env"

echo -e "${BLUE}======================================${NC}"
echo -e "${BLUE}Environment Update Script${NC}"
echo -e "${BLUE}======================================${NC}\n"

# ============================================================================
# Step 1: Verify Azure CLI login and get subscription details
# ============================================================================
echo -e "${YELLOW}Step 1: Verifying Azure CLI authentication...${NC}"

if ! az account show &>/dev/null; then
    echo -e "${RED}Error: Not logged in to Azure CLI${NC}"
    echo -e "Please run: ${BLUE}az login${NC}"
    exit 1
fi

# Get current subscription details
if [ -z "$AZURE_SUBSCRIPTION_ID" ]; then
    echo -e "${YELLOW}AZURE_SUBSCRIPTION_ID not set, using current Azure CLI subscription${NC}"
    AZURE_SUBSCRIPTION_ID=$(az account show --query id -o tsv)
    AZURE_TENANT_ID=$(az account show --query tenantId -o tsv)
else
    # Switch to the specified subscription if different from current
    CURRENT_SUBSCRIPTION=$(az account show --query id -o tsv)
    if [ "$CURRENT_SUBSCRIPTION" != "$AZURE_SUBSCRIPTION_ID" ]; then
        echo -e "${YELLOW}Switching to subscription: $AZURE_SUBSCRIPTION_ID${NC}"
        az account set --subscription "$AZURE_SUBSCRIPTION_ID"
    fi
    AZURE_TENANT_ID=$(az account show --query tenantId -o tsv)
fi

# Prompt for resource group if not set
if [ -z "$AZURE_RESOURCE_GROUP" ]; then
    echo -e "${YELLOW}AZURE_RESOURCE_GROUP not set${NC}"
    echo -e "Fetching available resource groups...\n"
    
    # Get list of resource groups
    mapfile -t RG_LIST < <(az group list --query "[].name" -o tsv)
    
    if [ ${#RG_LIST[@]} -eq 0 ]; then
        echo -e "${RED}Error: No resource groups found in subscription${NC}"
        exit 1
    fi
    
    echo -e "${BLUE}Available Resource Groups:${NC}"
    for i in "${!RG_LIST[@]}"; do
        echo -e "  $((i+1)). ${RG_LIST[$i]}"
    done
    echo ""
    
    read -p "Select a resource group (1-${#RG_LIST[@]}): " SELECTION
    
    if [[ "$SELECTION" =~ ^[0-9]+$ ]] && [ "$SELECTION" -ge 1 ] && [ "$SELECTION" -le "${#RG_LIST[@]}" ]; then
        AZURE_RESOURCE_GROUP="${RG_LIST[$((SELECTION-1))]}"
        echo -e "${GREEN}✓ Selected: $AZURE_RESOURCE_GROUP${NC}\n"
    else
        echo -e "${RED}Error: Invalid selection${NC}"
        exit 1
    fi
fi

# Get location if not set
if [ -z "$AZURE_LOCATION" ]; then
    AZURE_LOCATION=$(az group show --name "$AZURE_RESOURCE_GROUP" --query location -o tsv 2>/dev/null || echo "")
    if [ -z "$AZURE_LOCATION" ]; then
        echo -e "${YELLOW}Could not determine location from resource group${NC}"
        AZURE_LOCATION="eastus"
    fi
fi

echo -e "${GREEN}✓ Azure CLI authenticated${NC}"
echo -e "  Subscription: $AZURE_SUBSCRIPTION_ID"
echo -e "  Resource Group: $AZURE_RESOURCE_GROUP"
echo -e "  Location: $AZURE_LOCATION\n"

# ============================================================================
# Step 2: Get Azure OpenAI endpoint and API key
# ============================================================================
echo -e "${YELLOW}Step 2: Retrieving Azure OpenAI endpoint and API key...${NC}"

# Find Azure OpenAI account in the resource group
AOAI_NAME=$(az cognitiveservices account list \
    --resource-group "$AZURE_RESOURCE_GROUP" \
    --query "[?kind=='OpenAI' || kind=='AIServices'].name" -o tsv | head -n 1)

if [ -n "$AOAI_NAME" ]; then
    # Get the endpoint
    OPENAI_ENDPOINT=$(az cognitiveservices account show \
        --name "$AOAI_NAME" \
        --resource-group "$AZURE_RESOURCE_GROUP" \
        --query "properties.endpoint" -o tsv)
    
    # Retrieve the API key
    OPENAI_API_KEY=$(az cognitiveservices account keys list \
        --name "$AOAI_NAME" \
        --resource-group "$AZURE_RESOURCE_GROUP" \
        --query "key1" -o tsv 2>/dev/null || echo "")
    
    # Get AI Project details
    AZURE_EXISTING_AIPROJECT_RESOURCE_ID="/subscriptions/$AZURE_SUBSCRIPTION_ID/resourceGroups/$AZURE_RESOURCE_GROUP/providers/Microsoft.CognitiveServices/accounts/$AOAI_NAME"
    AZURE_EXISTING_AIPROJECT_ENDPOINT="$OPENAI_ENDPOINT"
    
    # Get deployed models
    DEPLOYMENTS=$(az cognitiveservices account deployment list \
        --name "$AOAI_NAME" \
        --resource-group "$AZURE_RESOURCE_GROUP" \
        --query "[].{name:name, model:properties.model.name, version:properties.model.version, capacity:sku.capacity}" -o json 2>/dev/null || echo "[]")
    
    # Find agent model (typically gpt-4 or gpt-35-turbo)
    AZURE_AI_AGENT_DEPLOYMENT_NAME=$(echo "$DEPLOYMENTS" | jq -r '[.[] | select(.model | test("gpt-4|gpt-35-turbo"))][0].name // ""')
    AZURE_AI_AGENT_MODEL_NAME=$(echo "$DEPLOYMENTS" | jq -r '[.[] | select(.model | test("gpt-4|gpt-35-turbo"))][0].model // ""')
    AZURE_AI_AGENT_MODEL_VERSION=$(echo "$DEPLOYMENTS" | jq -r '[.[] | select(.model | test("gpt-4|gpt-35-turbo"))][0].version // ""')
    AZURE_AI_AGENT_DEPLOYMENT_CAPACITY=$(echo "$DEPLOYMENTS" | jq -r '[.[] | select(.model | test("gpt-4|gpt-35-turbo"))][0].capacity // 10')
    
    # Find embedding model
    AZURE_AI_EMBED_DEPLOYMENT_NAME=$(echo "$DEPLOYMENTS" | jq -r '[.[] | select(.model | test("embedding"))][0].name // ""')
    AZURE_AI_EMBED_MODEL_NAME=$(echo "$DEPLOYMENTS" | jq -r '[.[] | select(.model | test("embedding"))][0].model // ""')
    AZURE_AI_EMBED_MODEL_VERSION=$(echo "$DEPLOYMENTS" | jq -r '[.[] | select(.model | test("embedding"))][0].version // ""')
    AZURE_AI_EMBED_DEPLOYMENT_CAPACITY=$(echo "$DEPLOYMENTS" | jq -r '[.[] | select(.model | test("embedding"))][0].capacity // 10')
    
    # Set embedding defaults
    AZURE_AI_EMBED_DEPLOYMENT_SKU="Standard"
    AZURE_AI_EMBED_DIMENSIONS=1536
    AZURE_AI_EMBED_MODEL_FORMAT="OpenAI"
    
    if [ -n "$OPENAI_API_KEY" ]; then
        echo -e "${GREEN}✓ Found OpenAI account: $AOAI_NAME${NC}"
        echo -e "${GREEN}✓ Using OpenAI endpoint: $OPENAI_ENDPOINT${NC}"
        echo -e "${GREEN}✓ Retrieved API key${NC}"
        [ -n "$AZURE_AI_AGENT_DEPLOYMENT_NAME" ] && echo -e "${GREEN}✓ Found agent model: $AZURE_AI_AGENT_MODEL_NAME ($AZURE_AI_AGENT_DEPLOYMENT_NAME)${NC}"
        [ -n "$AZURE_AI_EMBED_DEPLOYMENT_NAME" ] && echo -e "${GREEN}✓ Found embedding model: $AZURE_AI_EMBED_MODEL_NAME ($AZURE_AI_EMBED_DEPLOYMENT_NAME)${NC}"
    else
        echo -e "${YELLOW}⚠ Could not retrieve API key${NC}"
    fi
else
    echo -e "${RED}✗ No Azure OpenAI account found in resource group${NC}"
    OPENAI_ENDPOINT=""
    OPENAI_API_KEY=""
    AZURE_EXISTING_AIPROJECT_RESOURCE_ID=""
    AZURE_EXISTING_AIPROJECT_ENDPOINT=""
    AZURE_AI_AGENT_DEPLOYMENT_NAME=""
    AZURE_AI_AGENT_MODEL_NAME=""
    AZURE_AI_AGENT_MODEL_VERSION=""
    AZURE_AI_AGENT_DEPLOYMENT_CAPACITY=""
    AZURE_AI_EMBED_DEPLOYMENT_NAME=""
    AZURE_AI_EMBED_MODEL_NAME=""
    AZURE_AI_EMBED_MODEL_VERSION=""
    AZURE_AI_EMBED_DEPLOYMENT_CAPACITY=""
    AZURE_AI_EMBED_DEPLOYMENT_SKU=""
    AZURE_AI_EMBED_DIMENSIONS=""
    AZURE_AI_EMBED_MODEL_FORMAT=""
fi

# Set agent name
AZURE_AI_AGENT_NAME="zava-agent"

echo ""

# ============================================================================
# Step 3: Get Azure AI Search API key
# ============================================================================
echo -e "${YELLOW}Step 3: Retrieving Azure AI Search API key...${NC}"

# Find Azure AI Search service in the resource group
SEARCH_NAME=$(az search service list \
    --resource-group "$AZURE_RESOURCE_GROUP" \
    --query "[0].name" -o tsv 2>/dev/null || echo "")

if [ -n "$SEARCH_NAME" ]; then
    # Get the endpoint
    AZURE_AI_SEARCH_ENDPOINT="https://${SEARCH_NAME}.search.windows.net"
    
    # Get the API key
    SEARCH_API_KEY=$(az search admin-key show \
        --service-name "$SEARCH_NAME" \
        --resource-group "$AZURE_RESOURCE_GROUP" \
        --query "primaryKey" -o tsv 2>/dev/null || echo "")
    
    # Try to find existing index
    AZURE_AI_SEARCH_INDEX_NAME=$(az search index list \
        --service-name "$SEARCH_NAME" \
        --resource-group "$AZURE_RESOURCE_GROUP" \
        --query "[0].name" -o tsv 2>/dev/null || echo "contoso-products")
    
    if [ -n "$SEARCH_API_KEY" ]; then
        echo -e "${GREEN}✓ Found Search service: $SEARCH_NAME${NC}"
        echo -e "${GREEN}✓ Retrieved Search API key${NC}"
        echo -e "${GREEN}✓ Using index: $AZURE_AI_SEARCH_INDEX_NAME${NC}"
    else
        echo -e "${YELLOW}⚠ Could not retrieve Search API key${NC}"
    fi
else
    echo -e "${YELLOW}⚠ No Azure AI Search service found in resource group${NC}"
    AZURE_AI_SEARCH_ENDPOINT=""
    SEARCH_API_KEY=""
    AZURE_AI_SEARCH_INDEX_NAME="contoso-products"
fi
echo ""

# ============================================================================
# Step 4: Get Container Registry and Container Apps details
# ============================================================================
echo -e "${YELLOW}Step 4: Retrieving Container Registry and Container Apps details...${NC}"

# Find Container Registry
ACR_NAME=$(az acr list \
    --resource-group "$AZURE_RESOURCE_GROUP" \
    --query "[0].name" -o tsv 2>/dev/null || echo "")

if [ -n "$ACR_NAME" ]; then
    AZURE_CONTAINER_REGISTRY_ENDPOINT="${ACR_NAME}.azurecr.io"
    echo -e "${GREEN}✓ Found Container Registry: $ACR_NAME${NC}"
else
    echo -e "${YELLOW}⚠ No Container Registry found${NC}"
    AZURE_CONTAINER_REGISTRY_ENDPOINT=""
fi

# Find Container Apps Environment
AZURE_CONTAINER_ENVIRONMENT_NAME=$(az containerapp env list \
    --resource-group "$AZURE_RESOURCE_GROUP" \
    --query "[0].name" -o tsv 2>/dev/null || echo "")

if [ -n "$AZURE_CONTAINER_ENVIRONMENT_NAME" ]; then
    echo -e "${GREEN}✓ Found Container Apps Environment: $AZURE_CONTAINER_ENVIRONMENT_NAME${NC}"
else
    echo -e "${YELLOW}⚠ No Container Apps Environment found${NC}"
fi

# Find Container App (API service)
SERVICE_API_NAME=$(az containerapp list \
    --resource-group "$AZURE_RESOURCE_GROUP" \
    --query "[0].name" -o tsv 2>/dev/null || echo "")

if [ -n "$SERVICE_API_NAME" ]; then
    SERVICE_API_URI=$(az containerapp show \
        --name "$SERVICE_API_NAME" \
        --resource-group "$AZURE_RESOURCE_GROUP" \
        --query "properties.configuration.ingress.fqdn" -o tsv 2>/dev/null || echo "")
    
    SERVICE_API_IDENTITY_PRINCIPAL_ID=$(az containerapp show \
        --name "$SERVICE_API_NAME" \
        --resource-group "$AZURE_RESOURCE_GROUP" \
        --query "identity.principalId" -o tsv 2>/dev/null || echo "")
    
    if [ -n "$SERVICE_API_URI" ]; then
        SERVICE_API_URI="https://$SERVICE_API_URI"
        SERVICE_API_ENDPOINTS="{\"API\":\"$SERVICE_API_URI\"}"
        echo -e "${GREEN}✓ Found Container App: $SERVICE_API_NAME${NC}"
        echo -e "${GREEN}✓ API URI: $SERVICE_API_URI${NC}"
    fi
else
    echo -e "${YELLOW}⚠ No Container App found${NC}"
    SERVICE_API_URI=""
    SERVICE_API_ENDPOINTS=""
    SERVICE_API_IDENTITY_PRINCIPAL_ID=""
fi

# Set image name default
SERVICE_API_AND_FRONTEND_IMAGE_NAME="${ACR_NAME}.azurecr.io/contoso-chat:latest"

echo ""

# ============================================================================
# Step 5: Get Application Insights connection string
# ============================================================================
echo -e "${YELLOW}Step 5: Retrieving Application Insights details...${NC}"

# Find Application Insights resource
APPINSIGHTS_RESOURCES=$(az resource list \
    --resource-group "$AZURE_RESOURCE_GROUP" \
    --resource-type "Microsoft.Insights/components" \
    --query "[].name" -o tsv)

if [ -n "$APPINSIGHTS_RESOURCES" ]; then
    APPINSIGHTS_NAME=$(echo "$APPINSIGHTS_RESOURCES" | head -n 1)
    
    APPINSIGHTS_DATA=$(az resource show \
        --ids "/subscriptions/$AZURE_SUBSCRIPTION_ID/resourceGroups/$AZURE_RESOURCE_GROUP/providers/Microsoft.Insights/components/$APPINSIGHTS_NAME" \
        --query "{connectionString: properties.ConnectionString, instrumentationKey: properties.InstrumentationKey}" \
        -o json)
    
    APPINSIGHTS_CONNECTION_STRING=$(echo "$APPINSIGHTS_DATA" | jq -r '.connectionString')
    APPINSIGHTS_INSTRUMENTATION_KEY=$(echo "$APPINSIGHTS_DATA" | jq -r '.instrumentationKey')
    
    # Set monitoring flags
    USE_APPLICATION_INSIGHTS="true"
    ENABLE_AZURE_MONITOR_TRACING="true"
    AZURE_TRACING_GEN_AI_CONTENT_RECORDING_ENABLED="true"
    
    echo -e "${GREEN}✓ Found Application Insights: $APPINSIGHTS_NAME${NC}"
else
    echo -e "${YELLOW}⚠ No Application Insights found${NC}"
    APPINSIGHTS_CONNECTION_STRING=""
    APPINSIGHTS_INSTRUMENTATION_KEY=""
    USE_APPLICATION_INSIGHTS="false"
    ENABLE_AZURE_MONITOR_TRACING="false"
    AZURE_TRACING_GEN_AI_CONTENT_RECORDING_ENABLED="false"
fi
echo ""

# ============================================================================
# Step 6: Generate the new .env file
# ============================================================================
echo -e "${YELLOW}Step 6: Generating updated .env file...${NC}"

# Generate new .env content
cat > "$ENV_FILE" << EOF
# ============================================================================
# Azure Environment Variables
# Auto-generated by scripts/6-get-env.sh on $(date)
# ============================================================================

# .... Azure Environment Variables
AZURE_LOCATION="$AZURE_LOCATION"
AZURE_RESOURCE_GROUP="$AZURE_RESOURCE_GROUP"
AZURE_SUBSCRIPTION_ID="$AZURE_SUBSCRIPTION_ID"
AZURE_TENANT_ID="$AZURE_TENANT_ID"

# .... Microsoft Foundry
AZURE_OPENAI_API_KEY="$OPENAI_API_KEY"
AZURE_OPENAI_ENDPOINT="$OPENAI_ENDPOINT"
AZURE_OPENAI_API_VERSION="2025-02-01-preview" 
AZURE_OPENAI_DEPLOYMENT="$AZURE_AI_AGENT_DEPLOYMENT_NAME"

# .... Microsoft Foundry Resources (from Azure portal)
AZURE_AI_FOUNDRY_NAME="$AOAI_NAME"
AZURE_AI_PROJECT_NAME="${AZURE_AI_PROJECT_NAME:-$AOAI_NAME}"
AZURE_EXISTING_AIPROJECT_ENDPOINT="$AZURE_EXISTING_AIPROJECT_ENDPOINT"
AZURE_EXISTING_AIPROJECT_RESOURCE_ID="$AZURE_EXISTING_AIPROJECT_RESOURCE_ID"

# .... Azure AI Search (Required for add-product-index script)
AZURE_SEARCH_ENDPOINT="$AZURE_AI_SEARCH_ENDPOINT"
AZURE_AISEARCH_ENDPOINT="$AZURE_AI_SEARCH_ENDPOINT"
AZURE_AI_SEARCH_ENDPOINT="$AZURE_AI_SEARCH_ENDPOINT"
AZURE_SEARCH_API_KEY="$SEARCH_API_KEY"
AZURE_SEARCH_INDEX_NAME="$AZURE_AI_SEARCH_INDEX_NAME"
AZURE_AISEARCH_INDEX="$AZURE_AI_SEARCH_INDEX_NAME"
AZURE_AI_SEARCH_INDEX_NAME="$AZURE_AI_SEARCH_INDEX_NAME"

# .... Agent Configuration
AZURE_AI_AGENT_DEPLOYMENT_NAME="$AZURE_AI_AGENT_DEPLOYMENT_NAME"
AZURE_AI_AGENT_MODEL_NAME="$AZURE_AI_AGENT_MODEL_NAME"
AZURE_AI_AGENT_MODEL_VERSION="$AZURE_AI_AGENT_MODEL_VERSION"
AZURE_AI_AGENT_DEPLOYMENT_CAPACITY=$AZURE_AI_AGENT_DEPLOYMENT_CAPACITY
AZURE_AI_AGENT_NAME="$AZURE_AI_AGENT_NAME"

# .... Embedding Model Configuration
AZURE_AI_EMBED_DEPLOYMENT_NAME="$AZURE_AI_EMBED_DEPLOYMENT_NAME" 
AZURE_AI_EMBED_MODEL_NAME="$AZURE_AI_EMBED_MODEL_NAME"
AZURE_AI_EMBED_MODEL_VERSION=$AZURE_AI_EMBED_MODEL_VERSION
AZURE_AI_EMBED_DEPLOYMENT_CAPACITY=$AZURE_AI_EMBED_DEPLOYMENT_CAPACITY
AZURE_AI_EMBED_DEPLOYMENT_SKU="$AZURE_AI_EMBED_DEPLOYMENT_SKU"
AZURE_AI_EMBED_DIMENSIONS=$AZURE_AI_EMBED_DIMENSIONS
AZURE_AI_EMBED_MODEL_FORMAT="$AZURE_AI_EMBED_MODEL_FORMAT"

# .... Container Apps & Registry
AZURE_CONTAINER_ENVIRONMENT_NAME="$AZURE_CONTAINER_ENVIRONMENT_NAME"
AZURE_CONTAINER_REGISTRY_ENDPOINT="$AZURE_CONTAINER_REGISTRY_ENDPOINT"
SERVICE_API_NAME="$SERVICE_API_NAME"
SERVICE_API_URI="$SERVICE_API_URI"
SERVICE_API_ENDPOINTS='$SERVICE_API_ENDPOINTS'
SERVICE_API_IDENTITY_PRINCIPAL_ID="$SERVICE_API_IDENTITY_PRINCIPAL_ID"
SERVICE_API_AND_FRONTEND_IMAGE_NAME="$SERVICE_API_AND_FRONTEND_IMAGE_NAME"

# .... Monitoring & Tracing
USE_APPLICATION_INSIGHTS="$USE_APPLICATION_INSIGHTS"
ENABLE_AZURE_MONITOR_TRACING="$ENABLE_AZURE_MONITOR_TRACING"
AZURE_TRACING_GEN_AI_CONTENT_RECORDING_ENABLED="$AZURE_TRACING_GEN_AI_CONTENT_RECORDING_ENABLED"
APPLICATIONINSIGHTS_CONNECTION_STRING="$APPINSIGHTS_CONNECTION_STRING"
APPLICATIONINSIGHTS_INSTRUMENTATION_KEY="$APPINSIGHTS_INSTRUMENTATION_KEY"
EOF

echo -e "${GREEN}✓ Generated new .env file${NC}\n"

# ============================================================================
# Step 7: Summary and Manual Actions
# ============================================================================
echo -e "${BLUE}======================================${NC}"
echo -e "${BLUE}Summary${NC}"
echo -e "${BLUE}======================================${NC}\n"

echo -e "${GREEN}✅ Successfully updated .env file!${NC}\n"

echo -e "${YELLOW}📋 Updated Variables:${NC}"
echo -e "  • Resource Group: $AZURE_RESOURCE_GROUP"
echo -e "  • Location: $AZURE_LOCATION"
echo -e "  • OpenAI Endpoint: $OPENAI_ENDPOINT"

if [ -n "$OPENAI_API_KEY" ]; then
    echo -e "  • OpenAI API Key: ${GREEN}✓ Retrieved${NC}"
else
    echo -e "  • OpenAI API Key: ${YELLOW}⚠ Not retrieved${NC}"
fi

echo -e "  • AI Search Endpoint: $AZURE_AI_SEARCH_ENDPOINT"

if [ -n "$SEARCH_API_KEY" ]; then
    echo -e "  • AI Search API Key: ${GREEN}✓ Retrieved${NC}"
else
    echo -e "  • AI Search API Key: ${YELLOW}⚠ Not retrieved${NC}"
fi

echo -e "\n${YELLOW}📋 Agent Model Configuration:${NC}"
echo -e "  • Agent Model: $AZURE_AI_AGENT_MODEL_NAME"
echo -e "  • Agent Version: $AZURE_AI_AGENT_MODEL_VERSION"
echo -e "  • Agent Deployment: $AZURE_AI_AGENT_DEPLOYMENT_NAME"
echo -e "  • Agent Capacity: $AZURE_AI_AGENT_DEPLOYMENT_CAPACITY"

echo -e "\n${YELLOW}📋 Embedding Model Configuration:${NC}"
if [ -n "$AZURE_AI_EMBED_MODEL_NAME" ]; then
    echo -e "  • Embed Model: ${GREEN}$AZURE_AI_EMBED_MODEL_NAME${NC}"
    echo -e "  • Embed Version: ${GREEN}$AZURE_AI_EMBED_MODEL_VERSION${NC}"
    echo -e "  • Embed Deployment: ${GREEN}$AZURE_AI_EMBED_DEPLOYMENT_NAME${NC}"
    echo -e "  • Embed Capacity: ${GREEN}$AZURE_AI_EMBED_DEPLOYMENT_CAPACITY${NC}"
    echo -e "  • Embed SKU: ${GREEN}$AZURE_AI_EMBED_DEPLOYMENT_SKU${NC}"
    echo -e "  • Embed Format: ${GREEN}$AZURE_AI_EMBED_MODEL_FORMAT${NC}"
else
    echo -e "  ${YELLOW}⚠ Embedding model not configured${NC}"
fi

echo -e "\n${YELLOW}📋 Container & Service:${NC}"
echo -e "  • Container Registry: $AZURE_CONTAINER_REGISTRY_ENDPOINT"
echo -e "  • Service API URI: $SERVICE_API_URI"

if [ -n "$APPINSIGHTS_CONNECTION_STRING" ]; then
    echo -e "  • Application Insights: ${GREEN}✓ Connected${NC}"
else
    echo -e "  • Application Insights: ${YELLOW}⚠ Not found${NC}"
fi

echo -e "\n${GREEN}💡 All API keys have been automatically retrieved from Azure!${NC}\n"

echo -e "${BLUE}======================================${NC}"
echo -e "${GREEN}✓ Done!${NC}"
echo -e "${BLUE}======================================${NC}\n"
