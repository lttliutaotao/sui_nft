module sui_nft::collection {
    use std::string::String;

    /// 错误码：无效的铸造模式
    const E_INVALID_MODE: u64 = 1;

    /// 铸造模式
    /// 定义Collection下的NFT铸造权限规则
    /// 0=Owner, 1=Public, 2=Whitelist
    public enum MintMode has copy, drop, store {
            Owner,      // 只有集合创建者能 mint
            Public,     // 所有人都能 mint
            Whitelist   // 指定名单才能 mint
    }

    /// 将 u8 编码转换为 MintMode
    fun decode_mode(code: u8): MintMode {
        if (code == 0) {
            MintMode::Owner
        } else if (code == 1) {
            MintMode::Public
        } else if (code == 2) {
            MintMode::Whitelist
        } else {
            abort E_INVALID_MODE
        }
    }

    /// NFT 集合容器 (Collection)
    /// 表示一组 NFT 的合集，包含元数据与铸造权限控制
    public struct Collection has key {
        /// 唯一标识符（由 Sui 分配）
        id: UID,
        /// 集合名称（例如 "CryptoPunks"）
        name: String,
        /// 集合符号（例如 "PUNK"）
        symbol: String,
        /// 集合描述，用于展示和说明
        description: String,
        /// 集合创建者地址（拥有最高权限）
        creator: address,
        /// 铸造模式：Owner / Public / Whitelist
        mode: MintMode,
        /// 白名单地址列表，仅在 Whitelist 模式下生效
        whitelist: vector<address>,
        /// 已铸造数量（累计，不随销毁递减）
        total_minted: u64,
        /// 最大供应量（0 表示无限制）
        max_supply: u64,
    }

    /// 管理权限 (AdminCap)
    /// 用于标识集合的管理员（可执行特殊操作，例如增删白名单）
    public struct AdminCap has key {
        /// 唯一标识符
        id: UID,
        /// 所属集合的 ID
        collection: ID
    }


    /// 创建一个新的 NFT Collection
    ///
    /// # 参数
    /// - `name`: 集合名称
    /// - `symbol`: 集合符号
    /// - `description`: 集合描述
    /// - `mode`: 铸造模式 (Owner / Public / Whitelist)
    /// - `whitelist`: 白名单地址（在 Whitelist 模式下使用）
    /// - `ctx`: 事务上下文
    ///
    /// # 行为
    /// - 创建并返回一个 `Collection` 和一个 `AdminCap`
    /// - 转移给调用者（sender）
    entry fun create_collection(
        name: String,
        symbol: String,
        description: String,
        mode_code: u8,
        whitelist: vector<address>,
        max_supply: u64,                        // 新增：最大供应量（0=无限）
        ctx: &mut TxContext
    ) {
        let collection = Collection {
            id: object::new(ctx),
            name,
            symbol,
            description,
            creator: tx_context::sender(ctx),
            mode: decode_mode(mode_code),
            whitelist,
            total_minted: 0,
            max_supply,
        };
        let cap = AdminCap { id: object::new(ctx), collection: object::id(&collection) };

        // 转移 Collection 和 AdminCap 给集合创建者
        transfer::transfer(collection, tx_context::sender(ctx));
        transfer::transfer(cap, tx_context::sender(ctx));
    }

    /// 判断指定地址是否有权 mint
    ///
    /// # 参数
    /// - `c`: Collection 对象引用
    /// - `addr`: 待检查的地址
    ///
    /// # 返回值
    /// - `true`: 地址有权 mint
    /// - `false`: 地址无权 mint
    public fun can_mint(c: &Collection, addr: address): bool {
        match (c.mode) {
            MintMode::Owner => addr == c.creator,
            MintMode::Public => true,
            MintMode::Whitelist => vector::contains(&c.whitelist, &addr)
        }
    }

    /// 错误码：无权限（cap与collection不匹配或非创建者）
    const E_NOT_AUTH: u64 = 2;

    /// 切换铸造模式（0=Owner,1=Public,2=Whitelist）
    entry fun set_mode(
        c: &mut Collection,
        cap: &AdminCap,
        new_mode_code: u8,
        ctx: & TxContext
    ) {
        // 验证 cap 归属正确 & 调用者必须是创建者
        assert!(object::id(c) == cap.collection, E_NOT_AUTH);
        assert!(tx_context::sender(ctx) == c.creator, E_NOT_AUTH);

        // 直接修改字段
        c.mode = decode_mode(new_mode_code);
    }

    /// 批量替换白名单（仅 Whitelist 模式下有意义）
    entry fun set_whitelist(
        c: &mut Collection,
        cap: &AdminCap,
        new_list: vector<address>,
        ctx: & TxContext
    ) {
        assert!(object::id(c) == cap.collection, E_NOT_AUTH);
        assert!(tx_context::sender(ctx) == c.creator, E_NOT_AUTH);

        c.whitelist = new_list
    }

    /// 设置最大供应量（仅创建者）
    entry fun set_max_supply(
        c: &mut Collection,
        cap: &AdminCap,
        new_max: u64,
        ctx: &tx_context::TxContext
    ) {
        assert!(object::id(c) == cap.collection, E_NOT_AUTH);
        assert!(tx_context::sender(ctx) == c.creator, E_NOT_AUTH);
        c.max_supply = new_max;
    }

    /// 获取已铸造数量
    public fun get_total_minted(c: &Collection): u64 {
        c.total_minted
    }

    /// 获取最大供应量
    public fun get_max_supply(c: &Collection): u64 {
        c.max_supply
    }

    /// 自增已铸造数量（只能内部调用或由 NFT 模块调用）
    public fun increase_minted(c: &mut Collection) {
        c.total_minted = c.total_minted + 1;
    }

    /// 读取 AdminCap 绑定的 Collection ID
    public fun get_cap_collection_id(cap: &AdminCap): ID {
        cap.collection
    }

    /// 读取 Collection 的创建者地址
    public fun get_creator(c: &Collection): address {
        c.creator
    }
}