Sui NFT项目
1、新建NFT容器
sources/collection.move：只管合集（Collection）与权限（AdminCap、MintMode、白名单、管理函数）
2、通过集合铸造NFT
3、先完成一个简单的NFT挂单、卖单、下架功能 market.move


更贴近实战：把 Listing 设计成 shared object，或直接接入 Kiosk + TransferPolicy；
多币种支付：把 Coin<SUI> 泛型化为 Coin<T>，并在 Listing 里保存 phantom T 或 type_name；
手续费/版税：在 buy_nft 里拆分付款（平台费、开发者费等）；
防刷/安全：加入超时、最小报价变更、签名挂单等机制；
撮合体验：结合你已有的 collection 与 nft，在后端记录 Listing ID，前端轮询事件或索引器展示。


sui_nft/
 ├── Move.toml
 └── sources/
      ├── collection.move   # Collection & AdminCap & 权限控制
      └── nft.move          # Token & mint 逻辑
      └── market.move       # 简单的挂单，下架，卖单功能
