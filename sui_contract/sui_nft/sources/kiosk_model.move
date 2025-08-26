module sui_nft::kiosk_model {

    use sui_nft::collection::{Collection};

    // 官方 Kiosk 类型与 API
    use sui::kiosk::{Self as kiosk, Kiosk, KioskOwnerCap};

    /// 错误码
    const E_NOT_OWNER: u64 = 1;

    /// Kiosk 绑定记录（项目内“模型层”）
    ///
    /// 说明：这里只记录用户的 Kiosk 对象 ID，并不直接操作官方 kiosk 合约。
    /// 后续接入官方 Kiosk 时，只需在调用前后校验/更新此记录即可。
    public struct KioskBinding has key,store
    {
        id: UID,
        /// 归属合集（便于多合集管理）
        collection: ID,
        /// 用户的钱包地址（谁绑定的）
        owner: address,
        /// 外部 Kiosk 对象的 ID（shared 对象的 ID）
        kiosk_id: ID,
    }

    /// 绑定（或登记）一个 Kiosk ID 到当前调用者
    entry fun bind(
        c: &Collection,
        kiosk_id: ID,
        ctx: &mut TxContext
    ) {
        let kb = KioskBinding {
            id: object::new(ctx),
            collection: object::id(c),
            owner: tx_context::sender(ctx),
            kiosk_id,
        };
        transfer::public_transfer(kb, tx_context::sender(ctx));
    }

    /// 变更绑定（同一 owner 才能修改）
    entry fun rebind(
        mut kb: KioskBinding,
        new_kiosk_id: ID,
        ctx: &tx_context::TxContext
    ) {
        assert!(kb.owner == tx_context::sender(ctx), E_NOT_OWNER);

        kb.kiosk_id = new_kiosk_id;

        // 关键：通过引用复制出 address（address 具备 copy 能力）
        let owner: address = *&kb.owner;

        transfer::public_transfer(kb, owner);
    }

    /// 只读查询
    public fun get_kiosk_id(kb: &KioskBinding): ID { kb.kiosk_id }
    public fun get_owner(kb: &KioskBinding): address { kb.owner }
    public fun get_collection_id(kb: &KioskBinding): ID { kb.collection }


    /// 一步到位：创建官方 Kiosk + 共享 + 绑定
    entry fun create_share_and_bind(
        c: &Collection,
        ctx: &mut TxContext
    ) {
        let sender = tx_context::sender(ctx);

        // 1) 创建官方 Kiosk 与 OwnerCap
        let (k, cap): (Kiosk, KioskOwnerCap) = kiosk::new(ctx);

        // 2) 记录 Kiosk 的 ID（共享前就先拿到）
        let kid: ID = object::id(&k);

        // 3) 共享 Kiosk（变成 shared object）
        transfer::public_share_object(k);

        // 4) OwnerCap 交给用户（用于后续上架/管理）
        transfer::public_transfer(cap, sender);

        // 5) 写入你的绑定记录
        let kb = KioskBinding {
            id: object::new(ctx),
            collection: object::id(c),
            owner: sender,
            kiosk_id: kid,
        };
        transfer::public_transfer(kb, sender);
    }
}
