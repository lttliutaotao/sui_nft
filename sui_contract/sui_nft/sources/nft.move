module sui_nft::nft {
    use std::string::String;
    use sui::event;

    use sui_nft::collection::{Self as coll, Collection};

    /// 铸造事件
    public struct MintEvent has copy, drop, store {
        collection: ID,
        to: address,
        token: ID,
        name: String,
        uri: String,
    }

    /// 销毁事件
    public struct BurnEvent has copy, drop, store {
        collection: ID,
        owner: address,
        token: ID,
    }

    /// 简单 NFT
    public struct NFT has key,store {
        id: UID,
        collection: ID,
        name: String,
        uri: String,
    }

    const E_FORBID_MINT: u64 = 3;

    const E_SUPPLY_EXCEEDED: u64 = 5;

    /// 内部：检查供应上限（0 表示无限）
    fun assert_supply_ok(c: &Collection) {
        let max_supply = coll::get_max_supply(c);
        if (max_supply == 0) {
            return // 无上限
        };
        assert!(coll::get_total_minted(c) < max_supply, E_SUPPLY_EXCEEDED);
    }

    /// 铸造一枚 NFT
    entry fun mint_nft(
        c: &mut Collection,
        name: String,
        uri: String,
        recipient: address,
        ctx: &mut tx_context::TxContext
    ) {
        assert!(coll::can_mint(c, tx_context::sender(ctx)), E_FORBID_MINT);

        assert_supply_ok(c);
        let nft = NFT {
            id: object::new(ctx),
            collection: object::id(c),
            name,
            uri,
        };

        event::emit(MintEvent {
            collection: object::id(c),
            to: recipient,
            token: object::id(&nft),
            name: nft.name,
            uri: nft.uri,
        });

        // 使用 collection 模块的函数增加计数器
        coll::increase_minted(c);

        transfer::transfer(nft, recipient);
    }

    /// 销毁 NFT
    entry fun burn_nft(nft: NFT, ctx: & tx_context::TxContext) {
        // 先在还没解构前，拿到 token 的 ID（需要 &NFT）
        let token_id = object::id(&nft);

        // 解构：拿到 UID（必须 delete）、以及集合 ID；忽略 name/uri
        let NFT { id, collection, name: _, uri: _ } = nft;

        // 发事件（可选）
        event::emit(BurnEvent {
            collection,
            owner: tx_context::sender(ctx),
            token: token_id,
        });

        // 显式销毁 UID，完成资源的“消费”
        object::delete(id);
    }
}
