import fs from "fs";
import { mnemonicToPrivateKey } from "@ton/crypto";
import { TonClient, Address, beginCell, internal, WalletContractV4 } from "@ton/ton";
import { Cell } from "@ton/core";
import { NftCollection } from "../contracts/nft-collection.js";

async function main() {
    const mnemonic = process.env.TON_MNEMONIC;
    const rpc = process.env.TON_RPC;
    const apiKey = process.env.TON_API_KEY;
    const ownerAddress = process.env.OWNER_ADDRESS;
    if (!mnemonic || !rpc || !apiKey || !ownerAddress) {
        throw new Error("TON_MNEMONIC, TON_RPC, TON_API_KEY, OWNER_ADDRESS must be set");
    }

    const { publicKey, secretKey } = await mnemonicToPrivateKey(mnemonic.split(" "));
    const client = new TonClient({ endpoint: rpc, apiKey });

    const owner = Address.parse(ownerAddress);
    const wallet = WalletContractV4.create({ workchain: owner.workChain, publicKey });
    const walletContract = client.open(wallet);

    if (wallet.address.toString() !== owner.toString()) {
        throw new Error("OWNER_ADDRESS не соответствует TON_MNEMONIC");
    }

    const codeCollection = Cell.fromBoc(fs.readFileSync("contracts/collection.boc"))[0];
    const codeNftItem = Cell.fromBoc(fs.readFileSync("contracts/item.boc"))[0];
    const content = beginCell().storeStringTail("https://example.com/nft/").endCell();

    const collection = NftCollection.createFromConfig(
        {
            owner,
            nextItemIndex: 0,
            collectionContent: content,
            nftItemCode: codeNftItem
        },
        codeCollection
    );

    const seqno = await walletContract.getSeqno();
    await walletContract.sendTransfer({
        seqno,
        secretKey,
        messages: [
            internal({
                to: collection.address,
                value: "0.05",
                body: collection.init?.data ?? beginCell().endCell()
            })
        ],
        sendMode: 3
    });

    console.log("Collection deployed at:", collection.address.toString());
}

main().catch(err => {
    console.error(err);
    process.exit(1);
});
