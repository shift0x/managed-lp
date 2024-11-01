import {ethers as hardhat} from 'hardhat'
import {ethers} from 'ethers'
import { getRPCEndpointForChain } from './chains'
import { vars } from "hardhat/config";

const getProviderForChain = async (chain: string, varsKey: string = "SMART_CONTRACT_DEPLOYER"): Promise<ethers.Wallet> => {
    const provider = new ethers.JsonRpcProvider(getRPCEndpointForChain(chain))
    
    if(!vars.has(varsKey)){
        throw `Contract deployer not set. Run "npx hardhat vars set ${varsKey}" to set the private key for the deployer`
    }

    const deployerPrivateKey = vars.get(varsKey)
    const deployer = new hardhat.Wallet(deployerPrivateKey, provider)

    return deployer;
}
 
const deployReactiveContract = async(chain: string, admin: string) : Promise<string> => {
    const reactiveChain = "kopli"
    const deployer = await getProviderForChain(reactiveChain)
    const factory = await hardhat.getContractFactory("EventProcessorReactive", deployer)

    const adminChain = await getProviderForChain(chain)

    if(!adminChain.provider)
        throw "provider is undefined"

    const adminChainId = (await adminChain.provider?.getNetwork()).chainId;

    const reactive = await factory.deploy(adminChainId, admin)

    await reactive.waitForDeployment()

    const address = await reactive.getAddress()

    console.log(`deployed reactive contract [${reactiveChain}]: ${address}`)

    return address
}

const deployAdministrator = async(chain: string) : Promise<string> => {
    const deployer = await getProviderForChain(chain)
    const factory = await hardhat.getContractFactory("EventAdministratorL1", deployer)

    const contract = await factory.deploy()
    
    //await contract.waitForDeployment()

    const address = await contract.getAddress()

    return address
}

const setReactiveEventProcessor = async(chain: string, admin: string, reactive: string) : Promise<void> => {
    const adminChainProvider = await getProviderForChain(chain)
    const reactiveChainProvider = await getProviderForChain("kopli")

    const adminContract = await hardhat.getContractAt("EventAdministratorL1", admin, adminChainProvider)
    const reactiveContract = await hardhat.getContractAt("EventProcessorReactive", reactive, reactiveChainProvider)

    const id = await reactiveContract.ID()

    await adminContract.setReactiveFeedProcessor(id)

    console.log(`updated event processor [${chain}]: ${id}`)
}

export const deployReactiveComponents = async (chain: string, admin: string | undefined) => {
    if(!admin){
        admin = await deployAdministrator(chain)

        console.info(`deployed administrator [${chain}]: ${admin}`)
    }

    const reactive = await deployReactiveContract(chain, admin)

    await setReactiveEventProcessor(chain, admin, reactive)

    return {
        chain,
        admin,
        reactive
    }
}
