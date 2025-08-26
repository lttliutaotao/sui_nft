module sui_nft::policy {
    use std::string::String;
    use sui_nft::collection;

    use sui_nft::collection::{Collection, AdminCap};

    /// 错误码
    const E_NOT_AUTH: u64 = 1;

    /// 转移策略（项目内“模型层”）
    ///
    /// - require_kiosk: 是否要求 NFT 只能通过 Kiosk 托管出售/转移
    /// - allow_direct_transfer: 是否允许点对点直接转移（不走市场）
    /// - allow_public_sale: 是否允许任何人购买（否则仅白名单市场地址）
    /// - whitelist_markets: 市场（或运营）地址白名单
    public struct TransferPolicy has key, store  {
        id: UID,
        collection: ID,
        creator: address,

        name: String,
        require_kiosk: bool,
        allow_direct_transfer: bool,
        allow_public_sale: bool,
        whitelist_markets: vector<address>,

        /// 绑定到官方 TransferPolicy 对象（仅存 ID，不直接操作）
        official_policy_id: Option<ID>,
    }

    /// 创建策略（仅集合创建者，需携带 AdminCap）
    entry fun create_policy(
        c: &Collection,
        cap: &AdminCap,
        name: String,
        require_kiosk: bool,
        allow_direct_transfer: bool,
        allow_public_sale: bool,
        whitelist_markets: vector<address>,
        ctx: &mut TxContext
    ) {
        // 基本归属校验
        assert!(object::id(c) == collection::get_cap_collection_id(cap), E_NOT_AUTH);
        assert!(tx_context::sender(ctx) == collection::get_creator(c), E_NOT_AUTH);

        let policy = TransferPolicy {
            id: object::new(ctx),
            collection: object::id(c),
            creator: collection::get_creator(c),
            name,
            require_kiosk,
            allow_direct_transfer,
            allow_public_sale,
            whitelist_markets,
            official_policy_id: option::none<ID>(),
        };
        transfer::public_transfer(policy, tx_context::sender(ctx));
    }

    /// —— Getters（供其他模块使用）——

    public fun get_collection_id(p: &TransferPolicy): ID { p.collection }
    public fun get_name(p: &TransferPolicy): &String { &p.name }
    public fun is_require_kiosk(p: &TransferPolicy): bool { p.require_kiosk }
    public fun is_allow_direct_transfer(p: &TransferPolicy): bool { p.allow_direct_transfer }
    public fun is_allow_public_sale(p: &TransferPolicy): bool { p.allow_public_sale }

    /// 是否是白名单市场地址
    public fun is_market_allowed(p: &TransferPolicy, addr: address): bool {
        if (p.allow_public_sale) { return true };
        vector::contains(&p.whitelist_markets, &addr)
    }

    ///  绑定官方策略 ID（仅集合创建者）
    entry fun link_official_policy(
        p: &mut TransferPolicy,
        c: &Collection,
        cap: &AdminCap,
        official_id: ID,
        ctx: &tx_context::TxContext
    ) {
        assert!(object::id(c) == collection::get_cap_collection_id(cap), E_NOT_AUTH);
        assert!(p.collection == object::id(c), E_NOT_AUTH);
        assert!(tx_context::sender(ctx) == collection::get_creator(c), E_NOT_AUTH);

        p.official_policy_id = option::some<ID>(official_id);
    }

    /// 解绑官方策略（仅集合创建者）
    entry fun unlink_official_policy(
        p: &mut TransferPolicy,
        c: &Collection,
        cap: &AdminCap,
        ctx: &tx_context::TxContext
    ) {
        assert!(object::id(c) == collection::get_cap_collection_id(cap), E_NOT_AUTH);
        assert!(p.collection == object::id(c), E_NOT_AUTH);
        assert!(tx_context::sender(ctx) == collection::get_creator(c), E_NOT_AUTH);

        p.official_policy_id = option::none<ID>();
    }

    /// 读取绑定的官方策略 ID（若未绑定则返回 none）
    public fun get_official_policy_id(p: &TransferPolicy): Option<ID> {
        p.official_policy_id
    }

    /// —— 管理接口（仅创建者 + AdminCap）——
    entry fun set_flags(
        p: &mut TransferPolicy,
        c: &Collection,
        cap: &AdminCap,
        require_kiosk: bool,
        allow_direct_transfer: bool,
        allow_public_sale: bool,
        ctx: &tx_context::TxContext
    ) {
        assert!(object::id(c) == collection::get_cap_collection_id(cap), E_NOT_AUTH);
        assert!(p.collection == object::id(c), E_NOT_AUTH);
        assert!(tx_context::sender(ctx) == collection::get_creator(c), E_NOT_AUTH);

        p.require_kiosk = require_kiosk;
        p.allow_direct_transfer = allow_direct_transfer;
        p.allow_public_sale = allow_public_sale;
    }

    entry fun set_market_whitelist(
        p: &mut TransferPolicy,
        c: &Collection,
        cap: &AdminCap,
        new_list: vector<address>,
        ctx: &tx_context::TxContext
    ) {
        assert!(object::id(c) == collection::get_cap_collection_id(cap), E_NOT_AUTH);
        assert!(p.collection == object::id(c), E_NOT_AUTH);
        assert!(tx_context::sender(ctx) == collection::get_creator(c), E_NOT_AUTH);

        p.whitelist_markets = new_list;
    }
}
