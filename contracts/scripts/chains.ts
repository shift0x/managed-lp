type Lookup = {
    [key: string]: string;
};

const chains : Lookup = {
    "sepolia": "https://rpc.sepolia.org",
    "ethereum": "https://ethereum-rpc.publicnode.com",
    "avalanche": "https://api.avax.network/ext/bc/C/rpc",
    "arbitrum": "https://arb1.arbitrum.io/rpc",
    "manta": "https://pacific-rpc.manta.network/http",
    "bsc": "https://bsc.drpc.org",
    "polygon": "https://polygon.drpc.org/",
    "kopli": "https://kopli-rpc.rkt.ink"
}

export const getRPCEndpointForChain = (chain: string) : string => {
    return chains[chain.toLowerCase()]
}

export const supportedChainList = Object.keys(chains)