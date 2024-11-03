import {Command} from 'commander'
import figlet from 'figlet'
import prompts, { PromptObject } from 'prompts';
import { supportedChainList } from './chains';
import {isAddress} from 'ethers'
import { deployReactiveComponents } from './deploy-reactive';
import { fundReactiveAdmin, info, newBlockNumberSubscription } from './manage-reactive';

const deploy = async(chain: string) : Promise<void> => {
    const questions : PromptObject[] = [
        {
            type: 'select',
            name: "deploy_new_admin",
            message: "Deploy a new admin contract?",
            choices: [
                {
                    title: "Yes. Deploy a new admin along with the reactive event processor.",
                    value: "yes"
                },
                {
                    title: "No. I want to upgrade my current admin to use the new reactive event processor.",
                    value: "no"
                }
            ]
        }
    ]

    const responses = await prompts(questions);

    if(responses.deploy_new_admin == "no"){
        const adminResponse = await prompts([
            {
                type: 'text',
                name: 'admin_address',
                message: 'What is the address of the admin contract?',
                validate: async (prev) : Promise<boolean | string> => {
                    const isValidAddress = isAddress(prev)

                    if(!isValidAddress){
                        return "enter a valid address"
                    }

                    return true
                }
            }
        ])

        responses.admin_address = adminResponse.admin_address
    }

    await deployReactiveComponents(chain, responses.admin_address)

    return main()
}

const fund = async(chain: string): Promise<void> => {
    const response = await prompts([
        {
            type: 'text',
            name: 'address',
            message: 'What is the address of the admin contract?',
            validate: async (prev) : Promise<boolean | string> => {
                const isValidAddress = isAddress(prev)

                if(!isValidAddress){
                    return "enter a valid address"
                }

                return true
            }
        },
        {
            type: "text",
            name: "amount",
            message: "Enter an amount",
            validate: async (prev) : Promise<boolean | string> => {
                const isValidNumber = !isNaN(prev)

                if(!isValidNumber){
                    return "enter a valid amount"
                }

                return true
            }
        }
    ])

    await fundReactiveAdmin(chain, response.address, response.amount)
}

const subscribe = async(chain: string): Promise<void> => {
    const response = await prompts([
        {
            type: 'text',
            name: 'address',
            message: 'What is the address of the admin contract?',
            validate: async (prev) : Promise<boolean | string> => {
                const isValidAddress = isAddress(prev)

                if(!isValidAddress){
                    return "enter a valid address"
                }

                return true
            }
        },
        {
            type: "select",
            name: "subscription",
            message: "Choose a subscription",
            choices: [
                {
                    title: "Block Number Trigger",
                    value: "block_number"
                }
            ]
        }
    ])

    if(response.subscription == "block_number"){
        await newBlockNumberSubscription(chain, response.address, 0)
    }

    return main()
}

const main = async(showFiglet : boolean = false) : Promise<void> => {
    if(showFiglet)
        console.log(figlet.textSync("Reactive Administrator"));
    else 
        console.log("")

    const questions : PromptObject[] = [
        {
            type: 'select',
            name: 'admin_chain',
            message: `Choose a chain:`,
            choices: supportedChainList.map(chain => { 
                return {
                    title: chain,
                    value: chain
                }
            })
        },
        {
            type: "select",
            name: "action",
            message: "Choose an action",
            choices: [
                {
                    title: "New deployment",
                    value: "deploy"
                },
                {
                    title: "New subscription",
                    value: "subscribe"
                },
                {
                    title: "Fund admin contract (payer)",
                    value: "fund"
                }
            ]
        }
    ]

    const responses = await prompts(questions);

    if(responses.action == "deploy"){
        await deploy(responses.admin_chain)
    } else if(responses.action == "subscribe"){
        await subscribe(responses.admin_chain)
    } else if(responses.action == "fund") {
        await fund(responses.admin_chain)
    }
    
}


const program = new Command()

program
    .version("1.0.0")
    .description("Command line administrator for reactive feed components")
    .action(async () => { 
        await main(true) 
        //await info("sepolia", "0xeD43669429eb98A5bF83aD456558b9cdf789aB58", "0xDB847Da2f906c1E4DbDd8355d7Db4FaE2d9Cd57F")
    })

program.parse()

