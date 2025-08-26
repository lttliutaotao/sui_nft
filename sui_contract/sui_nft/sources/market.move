module sui_nft::market {
    use std::string::String;

    // 支付用 SUI Coin
    use sui::coin::{Self as coin, Coin};
    use sui::sui::SUI;

    use sui::event;

    // 复用你定义的 NFT
    use sui_nft::nft::NFT;

    /// 事件：上架
    public struct ListedEvent has copy, drop, store {
        listing: ID,
        nft: ID,
        seller: address,
        price: u64,            // 单位：MIST（1 SUI = 10^9 MIST）
        note: String,
    }

    /// 事件：成交
    public struct SoldEvent has copy, drop, store {
        listing: ID,
        nft: ID,
        seller: address,
        buyer: address,
        price: u64,
    }

    /// 事件：下架
    public struct CanceledEvent has copy, drop, store {
        listing: ID,
        nft: ID,
        seller: address,
    }

    /// 简单的上架对象（卖家拥有）
    public struct Listing has key {
        id: UID,
        nft: NFT,            // 被托管的 NFT（作为子对象）
        price: u64,          // MIST
        seller: address,     // 卖家地址（权限校验）
    }

    const E_NOT_SELLER: u64 = 1;
    const E_NOT_ENOUGH: u64 = 2;

    /// 上架：把 NFT 托管进 Listing，并返回 Listing（仍归卖家持有）
    ///
    /// - `nft`: 要出售的 NFT（会被放入 Listing）
    /// - `price`: 售价（MIST）
    /// - `note`: 备注/标题（可空字符串），仅发事件用
    entry fun list_nft(
        nft: NFT,
        price: u64,
        note: String,
        ctx: &mut tx_context::TxContext
    ) {
        let seller = tx_context::sender(ctx);

        let listing = Listing {
            id: object::new(ctx),
            nft,
            price,
            seller,
        };

        // 事件：上架
        event::emit(ListedEvent {
            listing: object::id(&listing),
            nft: object::id(&listing.nft),
            seller,
            price,
            note,
        });

        // 把 Listing 交还给卖家（Owned；本地自测方便）
        transfer::transfer(listing, seller);
    }

    /// 购买：买家用 SUI 支付，获得 NFT；多余的 SUI 作为找零返还给买家
    ///
    /// - `listing`: 卖家拥有的上架对象（撮合后传入）
    /// - `payment`: 买家提供的 SUI Coin（余额需 >= price）
    entry fun buy_nft(
        listing: Listing,
        mut payment: Coin<SUI>,
        ctx: &mut tx_context::TxContext
    ) {
        let buyer = tx_context::sender(ctx);

        // 记录 ID（事件要用）
        let listing_id: ID = object::id(&listing);
        // 拿出字段（move 出 Listing 内容）
        let Listing { id, nft, price, seller } = listing;

        let nft_id: ID = object::id(&nft);
        // 校验余额
        let pay_amount = coin::value(&payment);
        assert!(pay_amount >= price, E_NOT_ENOUGH);

        // 拆分支付：price 给卖家，剩余找零还给买家
        let pay_to_seller = coin::split(&mut payment, price, ctx);

        // transfer::transfer(pay_to_seller, seller);
        // transfer::transfer(payment, buyer);
        //给卖家转账
        // coin::transfer(pay_to_seller, seller);
        // // 剩余 payment 作为找零 给买家
        // coin::transfer(payment, buyer);
        //
        // // 转移 NFT 给买家
        // transfer::transfer(nft, buyer);


        transfer::public_transfer(pay_to_seller, seller);
        transfer::public_transfer(payment, buyer);

        // 转 NFT 也统一用 public_transfer（更通用）
        transfer::public_transfer(nft, buyer);

        // 删除 Listing 的 UID（listing 已被完全移动/消费）
        object::delete(id);

        // 事件：成交
        event::emit(SoldEvent {
            listing: listing_id,
            nft: nft_id,
            seller,
            buyer,
            price,
        });
    }

    /// 下架：只有卖家才能取消并取回 NFT
    entry fun cancel_listing(
        listing: Listing,
        ctx: &tx_context::TxContext
    ) {
        let caller = tx_context::sender(ctx);

        let listing_id: ID = object::id(&listing);
        // 取出字段
        let Listing { id, nft, price: _, seller } = listing;

        // 权限校验：只有卖家可下架
        assert!(caller == seller, E_NOT_SELLER);

        // 先发事件
        event::emit(CanceledEvent {
            listing: listing_id, // 同上说明
            nft: object::id(&nft),
            seller,
        });

        // NFT 取回卖家
        transfer::public_transfer(nft, seller);

        // 删除 Listing
        object::delete(id);
    }
}
