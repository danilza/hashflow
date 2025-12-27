contract NftCollection {

    owner: Address;
    next_item_index: Int;
    collection_content: Cell;
    nft_item_code: Cell;

    init(owner: Address, next_item_index: Int, collection_content: Cell, nft_item_code: Cell) {
        self.owner = owner;
        self.next_item_index = next_item_index;
        self.collection_content = collection_content;
        self.nft_item_code = nft_item_code;
    }

    fun owner(): Address {
        return self.owner;
    }

    fun next_item_index(): Int {
        return self.next_item_index;
    }

    fun collection_content(): Cell {
        return self.collection_content;
    }

    fun nft_item_code(): Cell {
        return self.nft_item_code;
    }
}
