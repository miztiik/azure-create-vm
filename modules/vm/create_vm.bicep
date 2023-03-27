param rgName string

param global_uniqueness string
param location string = resourceGroup().location


var saName = uniqueString(resourceGroup().id)

// VM Related Params
param isLinux bool = true
param isWindows bool = false

param vnetName string 
param vmSubnetName string

param vmNamePrefix string
param vmName string = '${vmNamePrefix}-${global_uniqueness}'

param dnsLabelPrefix string = toLower('${vmNamePrefix}-${global_uniqueness}-${uniqueString(resourceGroup().id, vmName)}')
param publicIpName string = '${vmNamePrefix}-${global_uniqueness}PublicIp'
param publicIPAllocationMethod string = 'Dynamic'
param publicIpSku string = 'Basic'


param vmSize string = 'Standard_D2s_v3'

param adminUsername string
@secure()
param adminPassword string

var customScriptData = base64(loadTextContent('./bootstrap_scripts/deploy_app.sh'))


@description('VM auth')
@allowed([
  'sshPublicKey'
  'password'
])
param authType string = 'password'


param winOSVersion string = '2022-datacenter-azure-edition'
param ubuntuOSVersion string = 'Ubuntu-2204'

var ubuntuImgRef = {
  'Ubuntu-2204': {
    publisher: 'Canonical'
    offer: '0001-com-ubuntu-server-jammy'
    sku: '22_04-lts-gen2'
    version: 'latest'
  }
}
var centosImgRef =  {
  publisher: 'OpenLogic'
  offer: 'CentOS'
  sku: '7.5'
  version: 'latest'
}

var redhatImgRef= {
  publisher: 'RedHat'
  offer: 'RHEL'
  sku: '7.4'
  version: 'latest'
}

var LinuxConfiguration = {
  disablePasswordAuthentication: true 
  ssh: {
    publickeys: [
      {
        path: '/home/${adminUsername}/.ssh/authorized_keys'
        keyData: adminPassword
      }
    ]
  }
}



var commonTags = resourceGroup().tags

resource r_sa 'Microsoft.Storage/storageAccounts@2022-05-01' = {
  name: saName
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
}


resource r_vnet 'Microsoft.Network/virtualNetworks@2021-02-01' existing = {
  name: vnetName
  scope: resourceGroup(rgName)
}


resource r_publicIp 'Microsoft.Network/publicIPAddresses@2022-05-01' = {
  name: publicIpName
  location: location
  tags: commonTags
  sku: {
    name: publicIpSku
  }
  properties: {
    publicIPAllocationMethod: publicIPAllocationMethod
    publicIPAddressVersion:'IPv4'
    deleteOption:'Delete'
    dnsSettings: {
      domainNameLabel: dnsLabelPrefix
    }
  }
}

resource r_webSg 'Microsoft.Network/networkSecurityGroups@2021-05-01' = {
  name: 'webSg'
  location: location
  tags: commonTags
  properties: {
    securityRules: [
      {
        name: 'AllowInboundSsh'
        properties: {
          priority: 250
          protocol: 'Tcp'
          access: 'Allow'
          direction: 'Inbound'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '22'
        }
      }
      {
        name: 'HTTP'
        properties: {
          priority: 200
          protocol: 'Tcp'
          access: 'Allow'
          direction: 'Inbound'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '80'
        }
      }
      {
        name: 'Outbound_Allow_All'
        properties: {
          priority: 300
          protocol: '*'
          access: 'Allow'
          direction: 'Outbound'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '*'
        }
      }
      {
        name: 'AzureResourceManager'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '443'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: 'AzureResourceManager'
          access: 'Allow'
          priority: 160
          direction: 'Outbound'
        }
      }
      {
        name: 'AzureStorageAccount'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '443'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: 'Storage.${location}'
          access: 'Allow'
          priority: 170
          direction: 'Outbound'
        }
      }
      {
        name: 'AzureFrontDoor'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '443'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: 'AzureFrontDoor.FrontEnd'
          access: 'Allow'
          priority: 180
          direction: 'Outbound'
        }
      }
    ]
  }
}


resource r_vm01Nic_01 'Microsoft.Network/networkInterfaces@2022-05-01' = {
  name: 'vm01Nic01'
  location: location
  tags: commonTags
  properties: {
    ipConfigurations: [
      { 
        name: 'ipconfig1'
        properties: {
          subnet: {
            id: resourceId('Microsoft.Network/virtualNetworks/subnets', vnetName, vmSubnetName)
          }
          privateIPAllocationMethod: 'Dynamic'
          publicIPAddress: {
            id: r_publicIp.id
          }
        }
      }
    ]
    networkSecurityGroup: {
      id: r_webSg.id
    }
  }
  dependsOn: [
    r_vnet
  ]
}


resource r_vm 'Microsoft.Compute/virtualMachines@2022-03-01' = {
  name: vmName
  location: location
  tags: commonTags
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    osProfile: {
      computerName: vmName
      adminUsername: adminUsername
      adminPassword: adminPassword
      linuxConfiguration: ((authType == 'password') ?null : LinuxConfiguration)
      customData: customScriptData
    }
    storageProfile: {
      imageReference: {
        publisher: 'RedHat'
        offer: 'RHEL'
        sku: '91-gen2'
        version: 'latest'
      }
      osDisk: {
        createOption: 'FromImage'
        name: 'osDiskFor_${vmName}'
        caching: 'ReadWrite'
        deleteOption: 'Delete'
        diskSizeGB:128
        managedDisk: {
          storageAccountType: 'StandardSSD_LRS'
        }
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: r_vm01Nic_01.id
        }
      ]
    }
    diagnosticsProfile: {
      bootDiagnostics: {
        enabled: true
        storageUri: r_sa.properties.primaryEndpoints.blob
      }
    }
  }
}

// INSTALL Azure Monitor Agent
resource AzureMonitorLinuxAgent 'Microsoft.Compute/virtualMachines/extensions@2021-07-01' = if(isLinux) {
  parent: r_vm
  name: 'AzureMonitorLinuxAgent'
  location: location
  properties: {
    publisher: 'Microsoft.Azure.Monitor'
    type: 'AzureMonitorLinuxAgent'
    enableAutomaticUpgrade: true
    autoUpgradeMinorVersion: true
    typeHandlerVersion: '1.25'
    settings:{
      'identifier-name': 'mi_res_id'
      'identifier-value': r_vm.identity.principalId
    }
  }
}



resource windowsAgent 'Microsoft.Compute/virtualMachines/extensions@2021-11-01' = if(isWindows) {
  name: 'AzureMonitorWindowsAgent'
  parent: r_vm
  location: location
  properties: {
    publisher: 'Microsoft.Azure.Monitor'
    type: 'AzureMonitorWindowsAgent'
    typeHandlerVersion: '1.0'
    autoUpgradeMinorVersion: true
    enableAutomaticUpgrade: true
  }
}


// resource dataCollectionRuleAssociation 'Microsoft.Insights/dataCollectionRuleAssociations@2021-04-01' = {
// name: 'dcrassociation'
// scope: r_vm
// properties: {
//   dataCollectionRuleId: vmDataCollectionRuleId
// }
// }




// resource ng 'Microsoft.Network/natGateways@2021-03-01' = if (natGateway) {
//   name: 'ng-${name}'
//   location: location
//   tags: tags
//   sku: {
//     name: 'Standard'
//   }
//   properties: {
//     idleTimeoutInMinutes: 4
//     publicIpAddresses: [
//       {
//         id: pip.id
//       }
//     ]
//   }
// }

// resource pip 'Microsoft.Network/publicIPAddresses@2021-03-01' = if (natGateway) {
//   name: 'pip-ng-${name}'
//   location: location
//   tags: tags
//   sku: {
//     name: 'Standard'
//   }
//   properties: {
//     publicIPAllocationMethod: 'Static'
//   }
// }


output webGenHostName string = r_publicIp.properties.dnsSettings.fqdn
output adminUsername string = adminUsername
output sshCommand string = 'ssh ${adminUsername}@${r_publicIp.properties.dnsSettings.fqdn}'
output webGenHostId string = r_vm.id
output webGenHostPrivateIP string = r_vm01Nic_01.properties.ipConfigurations[0].properties.privateIPAddress
