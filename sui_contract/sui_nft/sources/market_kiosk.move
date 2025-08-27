module sui_nft::market_kiosk {
    use std::string::String;
    use sui::event;

    // 你自己的模块
    use sui_nft::collection::Collection;
    use sui_nft::policy::{Self as policy, TransferPolicy};
    use sui_nft::kiosk_model::{Self as kiosk_model, KioskBinding};
    use sui_nft::nft::NFT;

    /// 事件：准备上架（通过 Kiosk）
    /// - 这里只做“发生学”的记录，用于前端或索引器追踪。真正的上架由同一 PTB 中的官方 kiosk 调用完成。
    public struct KioskListPrepared has copy, drop, store {
        collection: ID,
        kiosk_id: ID,
        nft: ID,
        seller: address,
        price: u64,
        note: String,
    }

    /// 事件：准备购买（通过 Kiosk）
    public struct KioskBuyPrepared has copy, drop, store {
        collection: ID,
        kiosk_id: ID,
        nft: ID,
        buyer: address,
        price: u64,
    }

    /// 事件：建议：成交记录（可在官方 purchase 成功后发；本模块提供一个辅助入口）
    public struct KioskSold has copy, drop, store {
        collection: ID,
        kiosk_id: ID,
        nft: ID,
        seller: address,
        buyer: address,
        price: u64,
    }

    /// 错误码
    const E_MARKET_FORBIDDEN: u64 = 2;
    const E_KIOSK_BIND_MISMATCH: u64 = 3;

    /// 在同一 PTB 的“上架流程”中优先调用本函数：
    /// - 校验 TransferPolicy（是否必须通过 Kiosk、是否允许当前地址作为市场）
    /// - 校验卖家对该 Collection 的 Kiosk 绑定是否存在
    /// - 发出 KioskListPrepared 事件（便于索引/前端串流）
    ///
    /// 之后，在同一 PTB 中调用官方 kiosk 的 place/list 等 API 实际完成上架。
    ///
    /// 参数：
    /// - `c`: 合集
    /// - `tp`: 转移策略（你项目自己的 TransferPolicy 对象）
    /// - `kb`: 卖家的 Kiosk 绑定（由 kiosk_model.bind 或 create_share_and_bind 生成）
    /// - `nft`: 将要上架的 NFT（这里只读引用，真正 “place” 给 Kiosk 在后续官方调用中完成）
    /// - `price`: 售价（单位自定，这里与官方调用保持一致建议用 MIST）
    /// - `note`: 备注/标题
    entry fun prepare_list_via_kiosk(
        c: &Collection,
        tp: &TransferPolicy,
        kb: &KioskBinding,
        nft: &NFT,
        price: u64,
        note: String,
        ctx: &TxContext
    ) {
        // 1) 若策略要求必须 Kiosk，则必须具有绑定记录（这里默认 kb 就是卖家的绑定）
        if (policy::is_require_kiosk(tp)) {
            // 仅做存在性与合集匹配的校验，防止把别的合集绑定拿来凑
            assert!(object::id(c) == kiosk_model::get_collection_id(kb), E_KIOSK_BIND_MISMATCH);
        };

        // 2) 如果策略启用白名单市场：只允许白名单市场账号/运营合约地址来走这条通路
        //    这里以“当前 sender 是否被策略允许”为检查（适配“市场合约发起”的模式）
        if (!policy::is_market_allowed(tp, tx_context::sender(ctx))) {
            assert!(false, E_MARKET_FORBIDDEN)
        };

        // 3) 记录一个“准备上架”的事件（索引器可据此配合官方 kiosk 的事件，拼出完整成交链路）
        event::emit(KioskListPrepared {
            collection: object::id(c),
            kiosk_id: kiosk_model::get_kiosk_id(kb),
            nft: object::id(nft),
            seller: tx_context::sender(ctx),
            price,
            note,
        });

        // 4) 注意：真正的 place/list 调用请在同一 PTB 中调用官方 kiosk API 完成。
    }

    /// 在同一 PTB 的“购买流程”中优先调用本函数：
    /// - 校验市场白名单（若策略不允许公共市场）
    /// - 记录 “准备购买” 事件，随后调用官方 kiosk 的购买 API
    entry fun prepare_buy_via_kiosk(
        c: &Collection,
        tp: &TransferPolicy,
        kb: &KioskBinding,
        nft_id: ID,
        price: u64,
        ctx: &TxContext
    ) {
        // 1) 若策略启用白名单市场，校验当前发起方
        if (!policy::is_market_allowed(tp, tx_context::sender(ctx))) {
            assert!(false, E_MARKET_FORBIDDEN)
        };

        // 2) 记录“准备购买”
        event::emit(KioskBuyPrepared {
            collection: object::id(c),
            kiosk_id: kiosk_model::get_kiosk_id(kb),
            nft: nft_id,
            buyer: tx_context::sender(ctx),
            price,
        });

        // 3) 注意：真正的购买（kiosk::purchase / take）在同一 PTB 里完成。
    }

    /// （可选）在官方购买成功后，补发一条“成交”事件，形成统一的业务事件面。
    /// 你可以把它和官方 kiosk 的 purchase 调用放到同一 PTB 的最后。
    entry fun emit_sold(
        c: &Collection,
        kb: &KioskBinding,
        seller: address,
        buyer: address,
        nft_id: ID,
        price: u64
    ) {
        event::emit(KioskSold {
            collection: object::id(c),
            kiosk_id: kiosk_model::get_kiosk_id(kb),
            nft: nft_id,
            seller,
            buyer,
            price,
        });
    }

    /// 便捷只读：是否需要 Kiosk/是否允许直转（可供前端直连）
    public fun require_kiosk(tp: &TransferPolicy): bool { policy::is_require_kiosk(tp) }
    public fun allow_direct(tp: &TransferPolicy): bool { policy::is_allow_direct_transfer(tp) }
}
