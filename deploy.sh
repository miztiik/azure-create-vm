set -ex

# Set Global Variables
location="westeurope"
global_uniqueness="01"
main_bicep_temp_name="main.bicep"
rg_bicep_templ_name="create_rg.bicep"
vnet_bicep_temp_name="create_vnet.bicep"
vm_bicep_temp_name="create_vm.bicep"



# # Generate and SSH key pair to pass the public key as parameter
# ssh-keygen -m PEM -t rsa -b 4096 -C '' -f ./miztiik.pem

# pubkeydata=$(cat miztiik.pem.pub)

function deploy_everything()
{
az bicep build --file $1
az deployment sub create \
    --name ${global_uniqueness}"-Rg-Deployment" \
    --location $location \
    --template-file $1
}



function old_create_rg()
{
az bicep build --file $2
# Create ResourceGroup
az deployment sub create \
    --name ${global_uniqueness}"_Rg_Deployment" \
    --location $1 \
    --template-file $2
}


# Check of deployments at subcription scope
# https://learn.microsoft.com/en-us/rest/api/resources/deployments/list-at-subscription-scope
# az deployment show --name Miztiikon_Enterprises_VMSwarm --query properties.outputResources[0].id --output tsv

function create_vnet()
{
az bicep build --file $2
# Create ResourceGroup
az deployment group create \
    --name ${global_uniqueness}"_Vnet_Deployment" \
    --mode Incremental \
    --resource-group $1 \
    --template-file $2 
}


function create_vm()
{
az bicep build --file $2
# Create ResourceGroup
az deployment group create \
    --name ${global_uniqueness}"_VmSwarm_Deployment" \
    --mode Incremental \
    --resource-group $1 \
    --template-file $2 
}


deploy_everything $main_bicep_temp_name
# old_create_rg  $location_name $rg_bicep_templ_name
# create_vnet $rg_name $vnet_bicep_temp_name
# create_vm $rg_name $vm_bicep_temp_name
