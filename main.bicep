targetScope = 'subscription'

// Parameters

//Set Global Variables
param global_uniqueness string='001'
param enterprise_name string ='Miztiik_Enterprises'

param rgNamePrefix string = enterprise_name

param location string = deployment().location
param vnetNamePrefix string = 'dataGenSwarm'

param vmNamePrefix string = 'm-web-srv'
param vmSubnetName string = 'webSubnet01'

param adminUsername string = 'miztiik'
param ubuntuOSVersion string = 'Ubuntu-2204'


// param dateNow string = utcNow('d')
param dateNow string = utcNow('yyyy-MM-dd-hh-mm')

var commonTags={
  owner: 'Mysqitue'
  github_profile: 'https://github.com/miztiik/about-me'
  LastDeployed: dateNow
}


module r_rg 'modules/resource_group/create_rg.bicep' = {
  name: '${rgNamePrefix}_${global_uniqueness}'
  params: {
    rgNamePrefix: rgNamePrefix
    global_uniqueness:global_uniqueness
    location: location
    commonTags:commonTags
  }
}


module r_vnet 'modules/vnet/create_vnet.bicep' = {
  scope: resourceGroup(r_rg.name)
  name: '${vnetNamePrefix}_${global_uniqueness}_Vnet'
  params: {
    global_uniqueness:global_uniqueness
    location:location
    vnetNamePrefix:vnetNamePrefix
    natGateway:false
  }
  dependsOn: [
    r_rg
  ]
}


module r_vm 'modules/vm/create_vm.bicep' = {
  scope: resourceGroup(r_rg.name)
  name: '${vmNamePrefix}_${global_uniqueness}_Vm'
  params: {
    global_uniqueness: global_uniqueness
    rgName: r_rg.name
    vnetName: r_vnet.outputs.vnetName
    location: location
    isLinux: true
    vmNamePrefix: vmNamePrefix
    vmSubnetName: vmSubnetName
    adminUsername: adminUsername
    adminPassword:'YOUR-ADMIN-PASSWORD-GOES-HERE-INSTEAD-OF-THIS-TEXT'
    ubuntuOSVersion:ubuntuOSVersion
    // publicKey: pubkeydata
    // script64: script64
  }
}
