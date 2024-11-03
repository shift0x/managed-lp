type Lookup = {
    [key: string]: any;
};

const chains : Lookup = {
    "sepolia": {
        rpc: "https://rpc.sepolia.org",
        proxy: "0x33Bbb7D0a2F1029550B0e91f653c4055DC9F4Dd8"
    },
    "ethereum": {
        rpc: "https://ethereum-rpc.publicnode.com"
    },
    "avalanche": {
        rpc: "https://api.avax.network/ext/bc/C/rpc",
        proxy: "0x76DdEc79A96e5bf05565dA4016C6B027a87Dd8F0"
    },
    "arbitrum": {
        rpc: "https://arb1.arbitrum.io/rpc"
    },
    "manta": {
        rpc: "https://pacific-rpc.manta.network/http",
        proxy: "0x9299472A6399Fd1027ebF067571Eb3e3D7837FC4"
    },
    "bsc": {
        rpc: "https://bsc.drpc.org"
    },  
    "polygon": {
        rpc: "https://polygon.drpc.org/"
    },
    "kopli": {
        rpc: "https://kopli-rpc.rkt.ink",
        proxy: "0x0000000000000000000000000000000000FFFFFF"
    }
}



export const getRPCEndpointForChain = (chain: string) : string => {
    return chains[chain.toLowerCase()].rpc
}

export const getProxyAddressForChain = (chain: string): string => {
    return chains[chain.toLowerCase()].proxy
}

export const supportedChainList = Object.keys(chains).filter(key => {
    return chains[key].proxy != null
})