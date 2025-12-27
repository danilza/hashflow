import { Contract, ContractProvider, Sender, Address, beginCell, Cell, contractAddress } from "@ton/core";

export class NftCollection implements Contract {
    constructor(readonly address: Address, readonly init?: { code: Cell; data: Cell }) {}

    static createFromConfig(config: {
        owner: Address;
        nextItemIndex: number;
        collectionContent: Cell;
        nftItemCode: Cell;
    }, code: Cell) {
        const data = beginCell()
            .storeAddress(config.owner)
            .storeUint(config.nextItemIndex, 64)
            .storeRef(config.collectionContent)
            .storeRef(config.nftItemCode)
            .endCell();

        const init = { code, data };
        const address = contractAddress(0, init);
        return new NftCollection(address, init);
    }

    async sendDeploy(provider: ContractProvider, via: Sender, value: bigint) {
        await provider.internal(via, {
            value,
            body: this.init?.data ?? beginCell().endCell()
        });
    }
}
