module sui_nft::market_oline {

    use std::string::String;
    use sui::event;

    // 官方 Kiosk & TransferPolicy
    use sui::kiosk::{Self as kiosk, Kiosk, KioskOwnerCap};
    use sui::transfer_policy::{Self as tpol, TransferPolicy, TransferRequest};

    // 提现收益需要的 SUI Coin 类型
    use sui::coin::{Self as coin, Coin};
    use sui::sui::SUI;

    // 你的 NFT 类型
    use sui_nft::nft::NFT;

    /// 事件：通过 Kiosk 发起上架
    public struct ListedViaKiosk has copy, drop, store {
        kiosk_id: ID,
        item_id: ID,
        price: u64,       // 单位：MIST
        seller: address,
        note: String,
    }


    /// 事件：成交（在完成 confirm 之后触发）
    public struct Purchased has copy, drop, store {
        kiosk_id: ID,
        item_id: ID,
        price: u64,
        buyer: address,
    }

    /// 事件：卖家提取收益
    public struct ProceedsWithdrawn has copy, drop, store {
        kiosk_id: ID,
        to: address,
        amount: u64,      // 实际提取的 MIST 数量
    }

    /// 便捷：将一枚 NFT 放入 Kiosk 并立刻上架
    entry fun place_and_list_nft(
        k: &mut Kiosk,
        cap: &KioskOwnerCap,
        nft: NFT,
        price: u64,
        note: String,
        ctx: &TxContext
    ) {
        let item_id: ID = object::id(&nft);
        kiosk::place(k, cap, nft);
        kiosk::list<NFT>(k, cap, item_id, price);

        event::emit(ListedViaKiosk {
            kiosk_id: object::id(k),
            item_id,
            price,
            seller: tx_context::sender(ctx),
            note,
        });
    }

    /// 只对已在 Kiosk 中的 NFT 进行上架
    entry fun list_existing(
        k: &mut Kiosk,
        cap: &KioskOwnerCap,
        item_id: ID,
        price: u64,
        note: String,
        ctx: &TxContext
    ) {
        kiosk::list<NFT>(k, cap, item_id, price);

        event::emit(ListedViaKiosk {
            kiosk_id: object::id(k),
            item_id,
            price,
            seller: tx_context::sender(ctx),
            note,
        });
    }

    /// 撤单（从已上架回到可取出的状态）
    entry fun delist(
        k: &mut Kiosk,
        cap: &KioskOwnerCap,
        item_id: ID,
        _ctx: &TxContext
    ) {
        kiosk::delist<NFT>(k, cap, item_id);
    }

    /// 购买（含 TransferPolicy 确认 + 转给买家）
    entry fun purchase_nft(
        k: &mut Kiosk,
        item_id: ID,
        payment: Coin<SUI>,
        policy: &TransferPolicy<NFT>,
        ctx: & TxContext
    ) {
        // 先记录支付金额（单位 MIST），再把 coin move 给 purchase
        let paid: u64 = coin::value(&payment);

        // 购买会消耗 Coin，并返回 (物品, TransferRequest<T>)
        let (nft, req): (NFT, TransferRequest<NFT>) =
            kiosk::purchase<NFT>(k, item_id, payment);

        // 按策略确认（如果你没有额外规则，这步也要做）
        let (_item_id, _paid, _payer) = tpol::confirm_request<NFT>(policy, req);

        // 把 NFT 转给买家
        transfer::public_transfer(nft, tx_context::sender(ctx));

        // 记录事件
        event::emit(Purchased {
            kiosk_id: object::id(k),
            item_id,
            price: paid,
            buyer: tx_context::sender(ctx),
        });
    }

    /// 卖家提取收益（SUI）
    entry fun withdraw_proceeds(
        k: &mut Kiosk,
        cap: &KioskOwnerCap,
        amount: Option<u64>,
        _ctx: &mut tx_context::TxContext
    ) {
        let c: Coin<SUI> = kiosk::withdraw(k, cap, amount,_ctx);
        let to = tx_context::sender(_ctx);
        let v = coin::value(&c);

        transfer::public_transfer(c, to);

        event::emit(ProceedsWithdrawn {
            kiosk_id: object::id(k),
            to,
            amount: v,
        });
    }

    /// 从 Kiosk 取回未上架的 NFT
    entry fun take_back(
        k: &mut Kiosk,
        cap: &KioskOwnerCap,
        item_id: ID,
        ctx: &TxContext
    ) {
        let nft: NFT = kiosk::take<NFT>(k, cap, item_id);
        transfer::public_transfer(nft, tx_context::sender(ctx));
    }
}
