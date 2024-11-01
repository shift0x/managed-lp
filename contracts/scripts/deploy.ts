import {Command} from 'commander'
import figlet from 'figlet'
import prompts, { PromptObject } from 'prompts';
import { supportedChainList } from './chains';
import {isAddress} from 'ethers'
import { deployReactiveComponents } from './deploy-reactive';


const deploy = async() : Promise<void> => {
    console.log(figlet.textSync("Reactive Deployer"));

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

    await deployReactiveComponents(responses.admin_chain, responses.admin_address)
}


const program = new Command()

program
  .version("1.0.0")
  .description("Command line deployer for reactive feed components")
  .action(deploy)

program.parse()

