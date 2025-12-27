import { Contract, ContractProvider, Sender, Address, Cell } from "@ton/core";

export class NftItem implements Contract {
    constructor(readonly address: Address, readonly init?: { code: Cell; data: Cell }) {}

    async sendTransfer(provider: ContractProvider, via: Sender, value: bigint, body: Cell) {
        await provider.internal(via, {
            value,
            body,
        });
    }
}
