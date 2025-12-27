import "@ton/core";

contract NftItem {
    index: Int;
    owner: Address;
    collection: Address;
    content: Cell;

    init(
        index: Int,
        owner: Address,
        collection: Address,
        collection_content: Cell,
        content: Cell
    ) {
        self.index = index;
        self.owner = owner;
        self.collection = collection;
        self.content = content;
    }

    ;; Simple getter for owner and index
    get item_data(): (Int, Address, Address, Cell) {
        return (self.index, self.owner, self.collection, self.content);
    }
}
