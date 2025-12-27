import { Contract, ContractProvider, Sender, Address, beginCell, Dictionary } from "@ton/core";

export class NftCollection implements Contract {
    constructor(readonly address: Address, readonly init?: { code: any; data: any }) {}

    static createFromConfig(config: {
        owner: Address,
        nextItemIndex: number,
        collectionContent: any,
        nftItemCode: any
    }, code: any) {
        const data = beginCell()
            .storeAddress(config.owner)
            .storeUint(config.nextItemIndex, 64)
            .storeRef(config.collectionContent)
            .storeRef(config.nftItemCode)
            .endCell();

        return new NftCollection(undefined as any, {
            code,
            data
        });
    }
}
