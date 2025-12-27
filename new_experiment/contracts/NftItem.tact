message Transfer {
    to: Address;
}

contract NftItem {

    owner: Address;
    index: Int;
    pipeline_hash: Int;
    pipeline_raw: Slice;
    collection: Address;

    init(index: Int, owner: Address, pipeline_hash: Int, pipeline_raw: Slice, collection: Address) {
        self.index = index;
        self.owner = owner;
        self.pipeline_hash = pipeline_hash;
        self.pipeline_raw = pipeline_raw;
        self.collection = collection;
    }

    receive(msg: Transfer) {
        require(sender() == self.owner, "not-owner");
        self.owner = msg.to;
    }

    fun owner(): Address {
        return self.owner;
    }

    fun index(): Int {
        return self.index;
    }
}
