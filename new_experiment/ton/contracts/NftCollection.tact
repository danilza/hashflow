import "@ton/core";
import "./NftItem.tact";

message NFTDeploy {
    query_id: Int as uint64;
    index: Int as uint64;
    amount: Int as coins;
    content: Cell;
}

contract NftCollection {
    owner: Address;
    next_item_index: Int;
    collection_content: Cell;
    nft_item_code: Cell;

    init(
        owner: Address,
        next_item_index: Int,
        collection_content: Cell,
        nft_item_code: Cell
    ) {
        self.owner = owner;
        self.next_item_index = next_item_index;
        self.collection_content = collection_content;
        self.nft_item_code = nft_item_code;
    }

    ;; Receive NFTDeploy message (mint)
    receive(msg: NFTDeploy) {
        require(sender() == self.owner, "not-owner");
        require(msg.index == self.next_item_index, "index-mismatch");

        let item_init = initOf NftItem(
            msg.index,
            self.owner,
            myAddress(),
            self.collection_content,
            msg.content
        );

        send(SendParameters{
            to: contractAddress(item_init),
            value: msg.amount,
            mode: SendRemainingValue,
            body: emptyCell()
        });

        self.next_item_index = msg.index + 1;
    }

    get owner(): Address {
        return self.owner;
    }

    get next_index(): Int {
        return self.next_item_index;
    }

    get collection_data(): (Address, Int, Cell, Cell) {
        return (self.owner, self.next_item_index, self.collection_content, self.nft_item_code);
    }

    get nft_address_by_index(idx: Int): Address {
        let item_init = initOf NftItem(
            idx,
            self.owner,
            myAddress(),
            self.collection_content,
            emptyCell()
        );
        return contractAddress(item_init);
    }
}
