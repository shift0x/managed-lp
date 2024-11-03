import {parseEther} from 'ethers';
import {ethers as hardhat} from 'hardhat'
import { getProviderForChain } from './deploy-reactive';

export const info = async(chain: string, admin: string, reactive: string) : Promise<void> => {
    const adminProvider = await getProviderForChain(chain);
    const reactiveProvider = await getProviderForChain("kopli");

    const adminContract = await hardhat.getContractAt("EventAdministratorL1", admin, adminProvider);
    const reactiveContract = await hardhat.getContractAt("EventProcessorReactive", reactive, reactiveProvider);
    const vendorContract = await hardhat.getContractAt("IPayable", "0x0000000000000000000000000000000000FFFFFF", reactiveProvider);
    
    const adminId = await adminContract.processorId();
    const reactiveId = await reactiveContract.ID();
    const debt = await vendorContract.debt(reactive);

    if(debt > 0){
        await reactiveContract.coverDebt();

        console.log(`payed debt: ${reactive}`)
    }

    console.log({
        adminId,
        reactiveId,
        debt
    })
}

export const newBlockNumberSubscription = async(chain : string, admin: string, block: number) : Promise<void> => {
    const wallet = await getProviderForChain(chain);

    if(!wallet || !wallet.provider)
        return;

    const contract = await hardhat.getContractAt("EventAdministratorL1", admin, wallet);
    const chainId = (await wallet.provider?.getNetwork()).chainId;

    await contract.newBlockNumberTrigger(chainId, block, admin, "0x", 350000)
}

export const fundReactiveAdmin = async(chain: string, admin: string, amount: string) : Promise<void> => {
    const wallet = await getProviderForChain(chain);

    if(!wallet || !wallet.provider)
        return;

    const tx = await wallet.sendTransaction({
        to: admin,
        value: parseEther(amount)
    })

    await tx.wait()

    console.log(`sent transaction: ${tx.hash}`)
}